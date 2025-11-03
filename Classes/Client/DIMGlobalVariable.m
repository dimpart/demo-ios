// license: https://mit-license.org
//
//  SeChat : Secure/secret Chat Application
//
//                               Written in 2023 by Moky <albert.moky@gmail.com>
//
// =============================================================================
// The MIT License (MIT)
//
// Copyright (c) 2023 Albert Moky
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
//  DIMGlobalVariable.m
//  Sechat
//
//  Created by Albert Moky on 2023/3/13.
//  Copyright © 2023 DIM Group. All rights reserved.
//

#import "Client.h"

#import "DIMGlobalVariable.h"

@interface EntityChecker : DIMEntityChecker

@end

@implementation EntityChecker

- (DIMCommonMessenger *)messenger {
    DIMGlobalVariable *shared = [DIMGlobalVariable sharedInstance];
    return [shared messenger];
}

// Override
- (BOOL)queryMetaForID:(id<MKMID>)ID {
    DIMCommonMessenger *transmitter = [self messenger];
    if (!transmitter) {
        NSLog(@"messenger not ready yet");
        return NO;
    }
    if ([self isMetaQueryExpired:ID]) {
        NSLog(@"querying meta for: %@", ID);
    } else {
        NSLog(@"meta query not expired yet: %@", ID);
        return NO;
    }
//    id<DKDContent> content = DIMMetaCommandQuery(ID);
//    [transmitter sendContent:content sender:nil receiver:MKMAnyStation priority:1];
    return YES;
}

// Override
- (BOOL)queryDocuments:(NSArray<id<MKMDocument>> *)docs forID:(id<MKMID>)ID {
    DIMCommonMessenger *transmitter = [self messenger];
    if (!transmitter) {
        NSLog(@"messenger not ready yet");
        return NO;
    }
    if ([self isDocumentsQueryExpired:ID]) {
        NSLog(@"querying documents for: %@", ID);
    } else {
        NSLog(@"document query not expired yet: %@", ID);
        return NO;
    }
//    NSDate *lastTime = [self lastTimeOfDocuments:docs forID:ID];
//    id<DKDContent> content = DIMDocumentCommandQuery(ID, lastTime);
//    [transmitter sendContent:content sender:nil receiver:MKMAnyStation priority:1];
    return YES;
}

// Override
- (BOOL)queryMembers:(NSArray<id<MKMID>> *)members forID:(id<MKMID>)group {
    DIMCommonMessenger *transmitter = [self messenger];
    if (!transmitter) {
        NSLog(@"messenger not ready yet");
        return NO;
    }
    if ([self isMembersQueryExpired:group]) {
        NSLog(@"queryying members for group: %@", group);
    } else {
        NSLog(@"members query not expired yet: %@", group);
        return NO;
    }
    // TODO: ...
    return YES;
}

// Override
- (NSDate *)lastTimeOfHistoryForID:(id<MKMID>)group {
    // TODO:
    return nil;
}

@end


@interface SharedArchivist : DIMClientArchivist

@end

@implementation SharedArchivist

- (DIMCommonFacebook *)facebook {
    DIMGlobalVariable *shared = [DIMGlobalVariable sharedInstance];
    return [shared facebook];
}

- (DIMCommonMessenger *)messenger {
    DIMGlobalVariable *shared = [DIMGlobalVariable sharedInstance];
    return [shared messenger];
}

@end

@implementation DIMGlobalVariable

OKSingletonImplementations(DIMGlobalVariable, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        DIMSharedDatabase *db = [[DIMSharedDatabase alloc] init];
        DIMSharedFacebook *facebook = [[DIMSharedFacebook alloc] initWithDatabase:db];
        facebook.entityChecker = [[EntityChecker alloc] initWithDatabase:db];
        DIMClientArchivist *archivist;
        archivist = [[SharedArchivist alloc] initWithFacebook:facebook
                                                     database:db];
        [facebook setArchivist:archivist];
        self.adb = db;
        self.mdb = db;
        self.sdb = db;
        self.database = db;
        self.archivist = archivist;
        self.facebook = facebook;
        self.emitter = [[DIMEmitter alloc] init];
        self.terminal = [[Client alloc] initWithFacebook:facebook database:db];
        // load plugins
        [DIMSharedFacebook prepare];
        [DIMSharedMessenger prepare];
    }
    return self;
}

@end
