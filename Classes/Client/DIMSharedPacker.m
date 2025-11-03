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
//  DIMSharedPacker.m
//  DIMP
//
//  Created by Albert Moky on 2020/12/19.
//  Copyright © 2020 DIM Group. All rights reserved.
//

#import "DKDInstantMessage+Extension.h"
#import "DIMMessageDataSource.h"
#import "DIMGlobalVariable.h"

#import "DIMSharedPacker.h"

@implementation DIMSharedPacker

//// Override
//- (id<DKDSecureMessage>)verifyMessage:(id<DKDReliableMessage>)rMsg {
//    id<MKMID> sender = rMsg.sender;
//    // [Meta Protocol]
//    id<MKMMeta> meta = rMsg.meta;
//    if (!meta) {
//        // get from local storage
//        meta = [self.facebook metaForID:sender];
//    } else if (!MKMMetaMatchID(sender, meta)) {
//        meta = nil;
//    }
//    if (!meta) {
//        // NOTICE: the application will query meta automatically
//        // save this message in a queue waiting sender's meta response
//        DIMMessageDataSource *mds = [DIMMessageDataSource sharedInstance];
//        [mds suspendReliableMessage:rMsg];
//        return nil;
//    }
//    
//    // make sure meta exists before verifying message
//    return [super verifyMessage:rMsg];
//}

// Override
- (nullable id<DKDSecureMessage>)encryptMessage:(id<DKDInstantMessage>)iMsg {
    id<MKSymmetricKey> key;
    // make sure visa.key exists before encrypting message
    id<DKDContent> content = [iMsg content];
    if ([content conformsToProtocol:@protocol(DKDFileContent)]) {
        if ([content objectForKey:@"data"] != nil/* &&
            [content objectForKey:@"URL"] == nil*/) {
            id<MKMID> sender = [iMsg sender];
            id<MKMID> receiver = [iMsg receiver];
            key = [self.messenger cipherKeyWithSender:sender receiver:receiver generate:YES];
            NSAssert(key, @"failed to get msg key: %@ -> %@", sender, receiver);
            // call emitter to encrypt & upload file data before send out
            DIMEmitter *emitter = [DIMGlobal emitter];
            [emitter sendFileContentMessage:iMsg password:key];
            return nil;
        }
    }
    
    id<DKDSecureMessage> sMsg = [super encryptMessage:iMsg];
    id<MKMID> receiver = [iMsg receiver];
    if (MKMIDIsGroup(receiver)) {
        // reuse group message keys
        id<MKMID> sender = iMsg.sender;
        key = [self.messenger cipherKeyWithSender:sender receiver:receiver generate:NO];
        [key setObject:@(YES) forKey:@"reused"];
    }
    // TODO: reuse personal message key?
    
    return sMsg;
}

- (nullable id<DKDInstantMessage>)decryptMessage:(id<DKDSecureMessage>)sMsg {
    id<DKDInstantMessage> iMsg = [super decryptMessage:sMsg];
    id<DKDContent> content = [iMsg content];
    if ([content conformsToProtocol:@protocol(DKDFileContent)]) {
        id<MKSymmetricKey> key;
        if ([content objectForKey:@"data"] == nil &&
            [content objectForKey:@"URL"] != nil) {
            id<MKMID> sender = [iMsg sender];
            id<MKMID> receiver = [iMsg receiver];
            key = [self.messenger cipherKeyWithSender:sender receiver:receiver generate:NO];
            NSAssert(key, @"failed to get password: %@ -> %@", sender, receiver);
            // keep password to decrypt data after downloaded
            [(id<DKDFileContent>)content setPassword:key];
        }
    }
    return iMsg;
}

@end
