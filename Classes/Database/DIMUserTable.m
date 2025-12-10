// license: https://mit-license.org
//
//  DIM-SDK : Decentralized Instant Messaging Software Development Kit
//
//                               Written in 2019 by Moky <albert.moky@gmail.com>
//
// =============================================================================
// The MIT License (MIT)
//
// Copyright (c) 2019 Albert Moky
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
//  DIMUserTable.m
//  DIMP
//
//  Created by Albert Moky on 2019/9/6.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import <DIMSDK/DIMSDK.h>

#import "DIMGlobalVariable.h"

#import "DIMConstants.h"
#import "DIMUserTable.h"

@interface DIMUserTable () {
    
    NSMutableArray<id<MKMID>> *_users;
}

@end

@implementation DIMUserTable

- (instancetype)init {
    if (self = [super init]) {
        _users = nil;
    }
    return self;
}

/**
 *  Get users filepath in Documents Directory
 *
 * @return "Documents/.dim/users.plist"
 */
- (NSString *)_usersFilePath {
    NSString *dir = [DIMStorage documentDirectory];
    dir = [dir stringByAppendingPathComponent:@".dim"];
    return [dir stringByAppendingPathComponent:@"users.plist"];
}

- (NSMutableArray<id<MKMID>> *)_loadUsers {
    if (!_users) {
        NSString *path = [self _usersFilePath];
        NSArray *array = [DIMStorage arrayWithContentsOfFile:path];
        _users = (NSMutableArray *)MKMIDConvert(array);
        NSLog(@"loaded %lu user(s) from %@", _users.count, path);
    }
    return _users;
}

- (BOOL)_saveUsers:(NSMutableArray<id<MKMID>> *)list {
    // update cache
    _users = list;
    // save into storage
    NSString *path = [self _usersFilePath];
    NSLog(@"saving %ld user(s) into %@", list.count, path);
    return [DIMStorage array:MKMIDRevert(list) writeToFile:path];
}

#pragma mark User DBI

// Override
- (NSArray<id<MKMID>> *)localUsers {
    return [self _loadUsers];
}

// Override
- (BOOL)saveLocalUsers:(NSArray<id<MKMID>> *)list {
    NSMutableArray *mArray;
    if ([list isKindOfClass:[NSMutableArray class]]) {
        mArray = (NSMutableArray *)list;
    } else {
        mArray = [list mutableCopy];
    }
    return [self _saveUsers:mArray];
}

#pragma mark User Table

- (id<MKMID>)currentUser {
    NSMutableArray<id<MKMID>> *allUsers = [self _loadUsers];
    if ([allUsers count] > 0) {
        return [allUsers objectAtIndex:0];
    } else {
        return nil;
    }
}

- (void)setCurrentUser:(id<MKMID>)currentUser {
    NSMutableArray<id<MKMID>> *allUsers = [self _loadUsers];
    NSInteger pos = [allUsers indexOfObject:currentUser];
    if (pos == 0) {
        return;
    } else if (pos != NSNotFound) {
        // move to the front
        [allUsers removeObjectAtIndex:pos];
    }
    [allUsers addObject:currentUser];
    [self _saveUsers:allUsers];
}

- (BOOL)addUser:(id<MKMID>)user {
    NSMutableArray<id<MKMID>> *allUsers = [self _loadUsers];
    NSInteger pos = [allUsers indexOfObject:user];
    if (pos != NSNotFound) {
        // already exists
        return NO;
    }
    [allUsers addObject:user];
    return [self _saveUsers:allUsers];
}

- (BOOL)removeUser:(id<MKMID>)user {
    NSMutableArray<id<MKMID>> *allUsers = [self _loadUsers];
    NSInteger pos = [allUsers indexOfObject:user];
    if (pos == NSNotFound) {
        // not exists
        return NO;
    }
    [allUsers removeObjectAtIndex:pos];
    return [self _saveUsers:allUsers];
}

@end

#pragma mark -

@interface DIMContactTable () {
    
    // uid => List<cid>
    NSMutableDictionary<id<MKMID>, NSMutableArray<id<MKMID>> *> *_caches;
}

@end

@implementation DIMContactTable

- (instancetype)init {
    if (self = [super init]) {
        _caches = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/**
 *  Get contacts filepath in Documents Directory
 *
 * @param ID - user ID
 * @return "Documents/.mkm/{address}/contacts.plist"
 */
- (NSString *)_filePathWithID:(id<MKMID>)ID {
    NSString *dir = [DIMStorage documentDirectory];
    dir = [dir stringByAppendingPathComponent:@".mkm"];
    dir = [dir stringByAppendingPathComponent:[ID.address string]];
    return [dir stringByAppendingPathComponent:@"contacts.plist"];
}

- (NSMutableArray<id<MKMID>> *)_loadContacts:(id<MKMID>)user {
    NSMutableArray<id<MKMID>> *contacts = [_caches objectForKey:user];
    if (!contacts) {
        NSString *path = [self _filePathWithID:user];
        NSArray *array = [DIMStorage arrayWithContentsOfFile:path];
        contacts = (NSMutableArray *)MKMIDConvert(array);
        NSLog(@"loaded %lu contact(s) from %@", contacts.count, path);
        // cache it
        [_caches setObject:contacts forKey:user];
    }
    return contacts;
}

- (BOOL)_saveContacts:(NSMutableArray<id<MKMID>> *)contacts forUser:(id<MKMID>)user {
    // update cache
    [_caches setObject:contacts forKey:user];
    
    NSString *path = [self _filePathWithID:user];
    NSLog(@"saving %lu contact(s) into %@", contacts.count, path);
    BOOL ok = [DIMStorage array:MKMIDRevert(contacts) writeToFile:path];
    if (ok) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:kNotificationName_ContactsUpdated
                          object:self
                        userInfo:@{@"user":user}];
    }
    return ok;
}

#pragma mark Contact DBI

// Override
- (NSArray<id<MKMID>> *)contactsOfUser:(id<MKMID>)user {
    return [self _loadContacts:user];
}

// Override
- (BOOL)saveContacts:(NSArray<id<MKMID>> *)contacts forUser:(id<MKMID>)user {
    NSMutableArray *mArray;
    if ([contacts isKindOfClass:[NSMutableArray class]]) {
        mArray = (NSMutableArray *)contacts;
    } else {
        mArray = [contacts mutableCopy];
    }
    return [self _saveContacts:mArray forUser:user];
}

#pragma mark Contact Table

- (BOOL)addContact:(id<MKMID>)contact forUser:(id<MKMID>)user {
    NSMutableArray<id<MKMID>> *allContacts = [self _loadContacts:user];
    NSInteger pos = [allContacts indexOfObject:contact];
    if (pos != NSNotFound) {
        //already exists
        return NO;
    }
    [allContacts addObject:contact];
    return [self _saveContacts:allContacts forUser:user];
}

- (BOOL)removeContact:(id<MKMID>)contact forUser:(id<MKMID>)user {
    NSMutableArray<id<MKMID>> *allContacts = [self _loadContacts:user];
    NSInteger pos = [allContacts indexOfObject:contact];
    if (pos == NSNotFound) {
        // not exists
        return NO;
    }
    [allContacts removeObjectAtIndex:pos];
    return [self _saveContacts:allContacts forUser:user];
}

@end
