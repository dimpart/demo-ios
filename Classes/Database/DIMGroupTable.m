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
//  DIMGroupTable.m
//  DIMP
//
//  Created by Albert Moky on 2019/9/6.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import <DIMSDK/DIMSDK.h>

#import "DIMGlobalVariable.h"

#import "DIMConstants.h"
#import "DIMGroupTable.h"

@interface DIMGroupTable () {
    
    // gid => List<mid>
    NSMutableDictionary<id<MKMID>, NSMutableArray<id<MKMID>> *> *_caches;
}

@end

@implementation DIMGroupTable

- (instancetype)init {
    if (self = [super init]) {
        _caches = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/**
 *  Get group members filepath in Documents Directory
 *
 * @param ID - group ID
 * @return "Documents/.mkm/{address}/members.plist"
 */
- (NSString *)_filePathWithID:(id<MKMID>)ID {
    NSString *dir = [DIMStorage documentDirectory];
    dir = [dir stringByAppendingPathComponent:@".mkm"];
    dir = [dir stringByAppendingPathComponent:ID.address.string];
    return [dir stringByAppendingPathComponent:@"members.plist"];
}

- (NSMutableArray<id<MKMID>> *)_loadMembers:(id<MKMID>)group {
    NSMutableArray<id<MKMID>> *members = [_caches objectForKey:group];
    if (!members) {
        NSString *path = [self _filePathWithID:group];
        NSArray *array = [DIMStorage arrayWithContentsOfFile:path];
        members = (NSMutableArray *)MKMIDConvert(array);
        NSLog(@"loaded %lu member(s) from %@", members.count, path);
        // cache it
        [_caches setObject:members forKey:group];
    }
    return members;
}

- (BOOL)_saveMembers:(NSMutableArray *)members group:(id<MKMID>)group {
    // update cache
    [_caches setObject:members forKey:group];
    
    NSString *path = [self _filePathWithID:group];
    NSLog(@"saving %lu member(s) into: %@", members.count, path);
    BOOL result = [DIMStorage array:MKMIDRevert(members) writeToFile:path];
    if (result) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:kNotificationName_GroupMembersUpdated
                          object:self
                        userInfo:@{@"group":group}];
    }
    return result;
}

#pragma mark Group DBI

// Override
- (nullable id<MKMID>)founderOfGroup:(id<MKMID>)group {
    NSLog(@"implement for founder");
    return nil;
}

// Override
- (nullable id<MKMID>)ownerOfGroup:(id<MKMID>)group {
    NSLog(@"implement for owner");
    return nil;
}

// Override
- (NSArray<id<MKMID>> *)membersOfGroup:(id<MKMID>)group {
    NSMutableArray<id<MKMID>> *members = [self _loadMembers:group];
    // ensure that founder is at the front
    if (members.count > 1) {
        id<MKMID> ID;
        id<MKMMeta> gMeta = DIMMetaForID(group);
        id<MKMMeta> uMeta;
        id<MKVerifyKey> PK;
        for (NSUInteger index = 0; index < members.count; ++index) {
            ID = [members objectAtIndex:index];
            uMeta = DIMMetaForID(ID);
            PK = [uMeta publicKey];
            if ([DIMMetaUtils meta:gMeta matchPublicKey:PK]) {
                if (index > 0) {
                    // move to front
                    [members removeObjectAtIndex:index];
                    [members insertObject:ID atIndex:0];
                }
                break;
            }
        }
    }
    return members;
}

// Override
- (BOOL)saveMembers:(NSArray *)members group:(id<MKMID>)group {
    NSMutableArray *mArray;
    if ([members isKindOfClass:[NSMutableArray class]]) {
        mArray = (NSMutableArray *)members;
    } else {
        mArray = [members mutableCopy];
    }
    return [self _saveMembers:mArray group:group];
}

// Override
- (NSArray<id<MKMID>> *)assistantsOfGroup:(id<MKMID>)group {
    NSLog(@"implement for assistants");
    return nil;
}

// Override
- (BOOL)saveAssistants:(NSArray<id<MKMID>> *)bots group:(id<MKMID>)gid {
    NSLog(@"implement for save assistants");
    return NO;
}

// Override
- (NSArray<id<MKMID>> *)administratorsOfGroup:(id<MKMID>)group {
    NSLog(@"implement for administrators");
    return nil;
}

// Override
- (BOOL)saveAdministrators:(NSArray<id<MKMID>> *)admins group:(id<MKMID>)gid {
    NSLog(@"implement for save administrators");
    return NO;
}

#pragma mark -

- (BOOL)addMember:(id<MKMID>)member group:(id<MKMID>)group {
    NSMutableArray<id<MKMID>> *allMembers = [self _loadMembers:group];
    NSInteger pos = [allMembers indexOfObject:member];
    if (pos != NSNotFound) {
        // already exists
        return NO;
    }
    [allMembers addObject:member];
    return [self _saveMembers:allMembers group:group];
}

- (BOOL)removeMember:(id<MKMID>)member group:(id<MKMID>)group {
    NSMutableArray<id<MKMID>> *allMembers = [self _loadMembers:group];
    NSInteger pos = [allMembers indexOfObject:member];
    if (pos == NSNotFound) {
        // not exists
        return NO;
    }
    [allMembers removeObject:member];
    return [self _saveMembers:allMembers group:group];
}

- (BOOL)removeGroup:(id<MKMID>)group {
    NSString *path = [self _filePathWithID:group];
    NSLog(@"removing group: %@", group);
    return [DIMStorage removeItemAtPath:path];
}

@end
