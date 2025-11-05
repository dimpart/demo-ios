// license: https://mit-license.org
//
//  SeChat : Secure/secret Chat Application
//
//                               Written in 2020 by Moky <albert.moky@gmail.com>
//
// =============================================================================
// The MIT License (MIT)
//
// Copyright (c) 2020 Albert Moky
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// =============================================================================
//
//  DIMSharedFacebook.m
//  DIMP
//
//  Created by Albert Moky on 2020/12/13.
//  Copyright © 2020 DIM Group. All rights reserved.
//

#import "DIMConstants.h"
#import "DIMFileTransfer.h"

#import "DIMAddressNameTable.h"
#import "DIMUserTable.h"

#import "DIMGlobalVariable.h"

#import "DIMSharedFacebook.h"

typedef NSMutableArray<id<MKMID>> UserList;

@interface DIMSharedFacebook () {
    
    NSMutableArray<id<MKMUser>> *_allUsers;  // local users
    NSMutableDictionary<id<MKMID>, UserList *> *_userContacts;
}

@end

@implementation DIMSharedFacebook

- (instancetype)init {
    if (self = [super init]) {
        _allUsers          = nil;
        _userContacts      = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id<DIMArchivist>)archivist {
    DIMGlobalVariable *shared = [DIMGlobalVariable sharedInstance];
    return [shared archivist];
}

// Override
- (NSArray<id<MKMUser>> *)localUsers {
    if (!_allUsers) {
        NSArray<id<MKMID>> *users = [self.archivist localUsers];
        if (users) {
            _allUsers = (NSMutableArray<id<MKMUser>> *)users;
        } else {
            _allUsers = [[NSMutableArray alloc] init];
        }
    }
    return _allUsers;
}

// Override
- (void)setCurrentUser:(id<MKMUser>)currentUser {
    id<DIMUserTable> table = (id<DIMUserTable>)[self.archivist database];
    [table setCurrentUser:currentUser.identifier];
    // clear cache for reload
    [_allUsers removeAllObjects];
    [super setCurrentUser:currentUser];
}

// Override
- (NSArray<id<MKMID>> *)contactsOfUser:(id<MKMID>)user {
    UserList *contacts = [_userContacts objectForKey:user];
    if (!contacts) {
        contacts = (UserList *)[self.archivist contactsOfUser:user];
        if (!contacts) {
            // placeholder
            contacts = [[NSMutableArray alloc] init];
        }
        [_userContacts setObject:contacts forKey:user];
    }
    return contacts;
}

@end

@implementation DIMSharedFacebook (User)

- (OKPair<NSString *, NSString *> *)avatarForUser:(id<MKMID>)user {
    id<MKPortableNetworkFile> avatar;
    id<MKMDocument> doc = [self document:user forType:@"*"];
    if (doc) {
        if ([doc conformsToProtocol:@protocol(MKMVisa)]) {
            avatar = [(id<MKMVisa>)doc avatar];
        } else {
            avatar = MKPortableNetworkFileParse([doc propertyForKey:@"avatar"]);
        }
    }
    // TODO: encode data? encrypted file?
    NSString *urlString = [avatar string];
    NSString *path = nil;
    NSURL *url = nil;
    if ([urlString length] > 0) {
        url = NSURLFromString(urlString);
        DIMFileTransfer *ftp = [DIMFileTransfer sharedInstance];
        // TODO: observe notification: 'FileUploadSuccess'
        path = [ftp downloadAvatar:url];
    }
    return [[OKPair alloc] initWithFirst:path second:url];
}

- (BOOL)savePrivateKey:(id<MKPrivateKey>)SK
              withType:(NSString *)type
               forUser:(id<MKMID>)user {
    id<DIMAccountDBI> db = [self.archivist database];
    return [db savePrivateKey:SK withType:type forUser:user];
}

- (BOOL)addUser:(id<MKMID>)user {
    id<DIMAccountDBI> db = [self.archivist database];
    UserList *allUsers = (UserList *)[db localUsers];
    NSAssert(allUsers, @"allUsers would not be nil here");
    NSInteger pos = [allUsers indexOfObject:user];
    if (pos != NSNotFound) {
        // already exists
        return NO;
    }
    [allUsers addObject:user];
    if ([db saveLocalUsers:allUsers]) {
        // clear cache for reload
        [_allUsers removeAllObjects];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)removeUser:(id<MKMID>)user {
    id<DIMAccountDBI> db = [self.archivist database];
    UserList *allUsers = (UserList *)[db localUsers];
    NSAssert(allUsers, @"allUsers would not be nil here");
    NSInteger pos = [allUsers indexOfObject:user];
    if (pos == NSNotFound) {
        // not exists
        return NO;
    }
    [allUsers removeObjectAtIndex:pos];
    if ([db saveLocalUsers:allUsers]) {
        // clear cache for reload
        [_allUsers removeAllObjects];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)saveContacts:(NSArray<id<MKMID>> *)contacts user:(id<MKMID>)user {
    id<DIMAccountDBI> db = [self.archivist database];
    if ([db saveContacts:contacts user:user]) {
        // erase cache for reload
        [_userContacts removeObjectForKey:user];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)addContact:(id<MKMID>)contact user:(id<MKMID>)user {
    UserList *allContacts = (UserList *)[self contactsOfUser:user];
    NSAssert(allContacts, @"allContacts would not be nil here: %@", user);
    NSInteger pos = [allContacts indexOfObject:contact];
    if (pos != NSNotFound) {
        // already exists
        return NO;
    }
    [allContacts addObject:contact];
    return [self saveContacts:allContacts user:user];
}

- (BOOL)removeContact:(id<MKMID>)contact user:(id<MKMID>)user {
    UserList *allContacts = (UserList *)[self contactsOfUser:user];
    NSAssert(allContacts, @"allContacts would not be nil here: %@", user);
    NSInteger pos = [allContacts indexOfObject:contact];
    if (pos == NSNotFound) {
        // not exists
        return NO;
    }
    [allContacts removeObjectAtIndex:pos];
    return [self saveContacts:allContacts user:user];
}

@end

#pragma mark - ANS

static id<DIMAddressNameTable> _ansTable = nil;

@interface ANS : DIMAddressNameServer

@end

@implementation ANS

// Override
- (nullable id<MKMID>)getID:(NSString *)name {
    id<MKMID> ID = [super getID:name];
    if (ID) {
        return ID;
    }
    ID = [_ansTable recordForName:name];
    if (ID) {
        // FIXME: is reserved name?
        [self cacheID:ID withName:name];
    }
    return ID;
}

- (BOOL)saveID:(id<MKMID>)ID withName:(NSString *)alias {
    if (![self cacheID:ID withName:alias]) {
        // username is reserved
        return NO;
    }
    if (alias) {
        return [_ansTable addRecord:ID forName:alias];
    } else {
        return [_ansTable removeRecordForName:alias];
    }
}

@end

@implementation DIMSharedFacebook (ANS)

+ (id<DIMAddressNameTable>)ansTable {
    return _ansTable;
}

+ (void)setANSTable:(id<DIMAddressNameTable>)ansTable {
    _ansTable = ansTable;
}

+ (void)prepare {
    [super prepare];
    ANS *ans = [[ANS alloc] init];
    [DIMClientFacebook setANS:ans];
}

@end
