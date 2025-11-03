//
//  Facebook+Register.m
//  DIMP
//
//  Created by Albert Moky on 2019/1/28.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "Client.h"

#import "DIMGlobalVariable.h"

#import "Facebook+Register.h"

@implementation DIMFacebook (Register)

- (BOOL)saveMeta:(id<MKMMeta>)meta
      privateKey:(id<MKPrivateKey>)SK
           forID:(id<MKMID>)ID {
    
    id<DIMArchivist> archivist = [self archivist];
    NSArray<id<MKMID>> *array = [archivist localUsers];
    for (id<MKMUser> item in array) {
        if ([item.identifier isEqual:ID]) {
            NSLog(@"User ID already exists: %@", ID);
            return NO;
        }
    }
    
    // 1. check & save meta
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    if ([archivist saveMeta:meta withIdentifier:ID]) {
        NSLog(@"meta saved: %@", meta);
    } else {
        NSAssert(false, @"save meta failed: %@, %@", ID, meta);
        return NO;
    }
    
    // 2. check & save private key
    id<MKVerifyKey> PK = [meta publicKey];
    if ([PK matchSignKey:SK]) {
        if ([facebook savePrivateKey:SK
                            withType:DIMPrivateKeyType_Meta
                             forUser:ID]) {
            NSLog(@"private key saved: %@", SK);
        } else {
            NSAssert(false, @"save private key failed: %@", ID);
            return NO;
        }
    } else {
        NSAssert(false, @"asymmetric keys not match: %@, %@", PK, SK);
        return NO;
    }
    
    // 3. save user ID to local file
    
    // add current user ID to exists users
    NSMutableArray *users = [[NSMutableArray alloc] initWithCapacity:(array.count + 1)];
    [users addObject:ID];
    [users addObjectsFromArray:array];
    
//    return [self saveUsers:users];
    return NO;
}

- (BOOL)saveUserList:(NSArray<id<MKMUser>> *)users
     withCurrentUser:(id<MKMUser>)curr {
    NSMutableArray *list = [[NSMutableArray alloc] initWithCapacity:users.count];
    [list addObject:curr.identifier];
    for (id<MKMUser> user in users) {
        if ([list containsObject:user.identifier]) {
            // ignore
        } else {
            [list addObject:user.identifier];
        }
    }
//    return [self saveUsers:list];
    return NO;
}

@end
