// license: https://mit-license.org
//
//  DIM-SDK : Decentralized Instant Messaging Software Development Kit
//
//                               Written in 2018 by Moky <albert.moky@gmail.com>
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
//  DIMAmanuensis.m
//  DIMCore
//
//  Created by Albert Moky on 2018/10/21.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <DIMClient/DIMClient.h>

#import "DKDInstantMessage+Extension.h"
#import "DIMGlobalVariable.h"

#import "DIMConversation.h"

#import "DIMAmanuensis.h"

@interface DIMAmanuensis () {
    
    OKWeakMap<id<MKMAddress>, DIMConversation *> *_conversations;
}

@end

@implementation DIMAmanuensis

OKSingletonImplementations(DIMAmanuensis, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        _conversations = [[OKWeakMap alloc] init];
    }
    return self;
}

- (void)setConversationDataSource:(id<DIMConversationDataSource>)dataSource {
    if (dataSource) {
        // update exists chat boxes
        [_conversations enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                                usingBlock:^(id<MKMAddress> key, DIMConversation *chatBox, BOOL *stop) {
            if (chatBox.dataSource == nil) {
                chatBox.dataSource = dataSource;
            }
        }];
    }
    _conversationDataSource = dataSource;
}

- (void)setConversationDelegate:(id<DIMConversationDelegate>)delegate {
    if (delegate) {
        // update exists chat boxes
        [_conversations enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                                usingBlock:^(id<MKMAddress> key, DIMConversation *chatBox, BOOL *stop) {
            if (chatBox.delegate == nil) {
                chatBox.delegate = delegate;
            }
        }];
    }
    _conversationDelegate = delegate;
}

- (DIMConversation *)conversationWithID:(id<MKMID>)ID {
    DIMConversation *chatBox = [_conversations objectForKey:ID.address];
    if (!chatBox) {
        // create directly if we can find the entity
        id<MKMEntity> entity = nil;
        if (MKMIDIsUser(ID)) {
            entity = DIMUserWithID(ID);
        } else if (MKMIDIsGroup(ID)) {
            entity = DIMGroupWithID(ID);
        }
        //NSAssert(entity, @"ID error: %@", ID);
        if (entity) {
            // create new conversation with entity(User/Group)
            chatBox = [[DIMConversation alloc] initWithEntity:entity];
            chatBox.dataSource = _conversationDataSource;
            chatBox.delegate = _conversationDelegate;
            // mapping
            [_conversations setObject:chatBox forKey:ID.address];
        } else {
            NSLog(@"failed to create conversation: %@", ID);
        }
    }
    return chatBox;
}

@end

@implementation DIMAmanuensis (Message)

- (BOOL)saveInstantMessage:(id<DKDInstantMessage>)iMsg {
    id<DKDContent> content = iMsg.content;
    if ([content isKindOfClass:[DIMReceiptCommand class]]) {
        // it's a receipt
        NSLog(@"update target msg.state with receipt: %@", content);
        return [self saveReceipt:iMsg];
    }
    DIMConversation *chatBox = [self getConversation:iMsg.envelope];
    //NSAssert(chatBox, @"chat box not found for message: %@", iMsg);
    return [chatBox insertMessage:iMsg];
}

- (BOOL)saveReceipt:(id<DKDInstantMessage>)iMsg {
    id<DKDReceiptCommand> receipt = (id<DKDReceiptCommand>)[iMsg content];
    id<DKDEnvelope> env = [receipt originalEnvelope];
    if (!env) {
        env = [iMsg envelope];
    }
    DIMConversation *chatBox = [self getConversation:env];
    NSAssert(chatBox, @"chat box not found for receipt: %@", receipt);
    id<DKDInstantMessage> targetMessage;
    targetMessage = [self conversation:chatBox messageMatchReceipt:receipt];
    if (targetMessage) {
        DIMContent *targetContent = (DIMContent *)[targetMessage content];
        NSString *text = [receipt text];
        if ([text containsString:@"delivering"]) {
            // delivering to receiver (station said)
            targetContent.state = DIMMessageState_Delivering;
        } else if ([text containsString:@"delivered"]) {
            // delivered to receiver (station said)
            targetContent.state = DIMMessageState_Delivered;
        } else if ([text containsString:@"read"]) {
            // the receiver's client feedback
            targetContent.state = DIMMessageState_Read;
        } else {
            // TODO: other state?
            targetContent.state = DIMMessageState_Arrived;
        }
        return YES;
    } else {
        NSLog(@"target message not found for receipt from %@", iMsg.sender);
    }
    return [chatBox saveReceipt:iMsg];
}

// private
- (DIMConversation *)getConversation:(id<DKDEnvelope>)env {
    // check receiver
    id<MKMID> receiver = [env receiver];
    if (MKMIDIsGroup(receiver)) {
        // group chat, get chatbox with group ID
        return [self conversationWithID:receiver];
    }
    // check group
    id<MKMID> group = [env group];
    if (group) {
        // group chat, get chatbox with group ID
        return [self conversationWithID:group];
    }
    // personal chat, get chatbox with contact ID
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    id<MKMUser> user = [facebook currentUser];
    id<MKMID> sender = [env sender];
    if ([user.identifier isEqual:sender]) {
        return [self conversationWithID:receiver];
    } else {
        return [self conversationWithID:sender];
    }
}

// private
- (nullable id<DKDInstantMessage>)conversation:(DIMConversation *)chatBox
                           messageMatchReceipt:(id<DKDReceiptCommand>)receipt {
    id<DKDInstantMessage> iMsg = nil;
    NSInteger count = [chatBox numberOfMessage];
    for (NSInteger index = count - 1; index >= 0; --index) {
        iMsg = [chatBox messageAtIndex:index];
        if (receipt_match_message(receipt, iMsg)) {
            return iMsg;
        }
    }
    return nil;
}

static inline bool receipt_match_message(id<DKDReceiptCommand> receipt,
                                         id<DKDInstantMessage> iMsg) {
    // check envelope
    id<DKDEnvelope> env1 = [receipt originalEnvelope];
    id<DKDEnvelope> env2 = [iMsg envelope];
    if (env1) {
        if (![env1.sender isEqual:env2.sender]) {
            return NO;
        }
        // TODO: check receiver?
    }
    id<DKDContent> content = [iMsg content];
    // check sn
    DKDSerialNumber sn1 = [receipt originalSerialNumber];
    DKDSerialNumber sn2 = [content sn];
    if (sn1 > 0) {
        return sn1 == sn2;
    }
    
    NSString *sig1 = [receipt originalSignature];
    NSString *sig2 = [iMsg stringForKey:@"signature" defaultValue:nil];
    if ([sig1 length] > 8) {
        sig1 = [sig1 substringFromIndex:(sig1.length - 8)];
    }
    if ([sig2 length] > 8) {
        sig2 = [sig2 substringFromIndex:(sig2.length - 8)];
    }
    return [sig1 isEqualToString:sig2];
}

@end
