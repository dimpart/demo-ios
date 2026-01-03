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
//  DIMSharedMessenger.m
//  DIMP
//
//  Created by Albert Moky on 2020/12/13.
//  Copyright © 2020 DIM Group. All rights reserved.
//

#import "DIMGlobalVariable.h"

#import "DIMSearchCommand.h"
#import "DIMStorageCommand.h"

#import "DIMMessageDataSource.h"

#import "DKDInstantMessage+Extension.h"

#import "DIMSharedMessenger.h"

@implementation DIMSharedMessenger

- (id<MKMUser>)currentUser {
    return [self.facebook currentUser];
}

- (id<MKMStation>)currentStation {
    DIMClientSession *session = [self session];
    return [session station];
}

//// Override
//- (BOOL)queryDocumentForID:(id<MKMID>)ID {
//    BOOL ok = [super queryDocumentForID:ID];
//    if (ok) {
//        NSLog(@"querying document: %@", ID);
//    } else {
//        NSLog(@"querying document not expired: %@", ID);
//    }
//    return ok;
//}

// Override
- (void)suspendReliableMessage:(id<DKDReliableMessage>)rMsg
                     errorInfo:(NSDictionary<NSString *,id> *)info {
    [rMsg setObject:info forKey:@"error"];
    DIMMessageDataSource *mds = [DIMMessageDataSource sharedInstance];
    [mds suspendReliableMessage:rMsg];
}

// Override
- (void)suspendInstantMessage:(id<DKDInstantMessage>)iMsg
                    errorInfo:(NSDictionary<NSString *,id> *)info {
    [iMsg setObject:info forKey:@"error"];
    DIMMessageDataSource *mds = [DIMMessageDataSource sharedInstance];
    [mds suspendInstantMessage:iMsg];
}

// Override
- (void)handshakeSuccess {
    [super handshakeSuccess];
    // query bot ID
    NSArray<NSString *> *array = @[
        @"archivist",
        @"assistant",
    ];
    NSString *names = [array componentsJoinedByString:@" "];
    id<DKDCommand> cmd = [[DIMAnsCommand alloc] initWithNames:names];
    [self sendCommand:cmd priority:STDeparturePrioritySlower];
}

// Override
- (id<DKDReliableMessage>)sendInstantMessage:(id<DKDInstantMessage>)iMsg
                                    priority:(NSInteger)prior {
    DIMContent *content = (DIMContent *)[iMsg content];
    if ([content conformsToProtocol:@protocol(DKDCommand)]) {
        id<DKDCommand> command = (id<DKDCommand>)content;
        if ([command.cmd isEqualToString:DKDCommand_Handshake]) {
            // NOTICE: only handshake message can go out
            [iMsg setObject:@"handshaking" forKey:@"pass"];
        }
    }
    // send message (secured + certified) to target station
    id<DKDSecureMessage> sMsg = [self encryptMessage:iMsg];
    if (!sMsg) {
        // FIXME: public key not found?
        return nil;
    }
    id<DKDReliableMessage> rMsg = [self signMessage:sMsg];
    if (!rMsg) {
        NSAssert(false, @"failed to sign message: %@", sMsg);
        content.state = DIMMessageState_Error;
        return nil;
    }
    BOOL ok = [self sendReliableMessage:rMsg priority:prior];
    if (ok) {
        content.state = DIMMessageState_Sending;
    } else {
        NSLog(@"cannot send message now, put in waiting queue: %@", iMsg);
        content.state = DIMMessageState_Waiting;
    }
    DIMMessageDataSource *mds = [DIMMessageDataSource sharedInstance];
    if (![mds saveInstantMessage:iMsg]) {
        return nil;
    }
    return rMsg;
}

@end

@implementation DIMSharedMessenger (Send)

- (BOOL)sendCommand:(id<DKDCommand>)content priority:(NSInteger)prior {
    id<MKMStation> station = [self currentStation];
    return [self sendContent:content receiver:station.identifier priority:prior];
}

// private
- (BOOL)sendContent:(id<DKDContent>)content
           receiver:(id<MKMID>)receiver
           priority:(NSUInteger)prior {
    DIMClientSession *session = [self session];
    if (![session isActive]) {
        return NO;
    }
    OKPair<id<DKDInstantMessage>, id<DKDReliableMessage>> *result;
    result = [self sendContent:content
                        sender:nil
                      receiver:receiver
                      priority:prior];
    return result.second != nil;
}

- (BOOL)broadcastContent:(id<DKDContent>)content {
    id<MKMID> group = [content group];
    if (!MKMIDIsBroadcast(group)) {
        group = MKMEveryone;
        [content setGroup:group];
    }
    return [self sendContent:content
                    receiver:group
                    priority:STDeparturePrioritySlower];
}

- (BOOL)broadcastVisa:(id<MKMVisa>)doc {
    id<MKMUser> user = [self currentUser];
    if (!user) {
        NSAssert(false, @"login first");
        return NO;
    }
    id<MKMID> ID = MKMIDParse([doc objectForKey:@"did"]);
    if (![user.identifier isEqual:ID]) {
        NSAssert(false, @"visa document error: %@", doc);
        return NO;
    }
    // pack and send user document to every contact
    NSArray<id<MKMID>> *contacts = [user contacts];
    if ([contacts count] == 0) {
        NSLog(@"no contacts now");
        return NO;
    }
    id<DKDCommand> cmd = DIMDocumentCommandResponse(ID, nil, @[doc]);
    for (id<MKMID> item in contacts) {
        [self sendContent:cmd receiver:item priority:STDeparturePrioritySlower];
    }
    return YES;
}

- (BOOL)postDocument:(id<MKMDocument>)doc withMeta:(id<MKMMeta>)meta {
    id<MKMID> ID = MKMIDParse([doc objectForKey:@"did"]);
    id<DKDCommand> cmd = [[DIMDocumentCommand alloc] initWithID:ID
                                                           meta:meta
                                                      documents:@[doc]];
    return [self sendCommand:cmd priority:STDeparturePrioritySlower];
}

- (BOOL)postContacts:(NSArray<id<MKMID>> *)contacts {
    id<MKMUser> user = [self.facebook currentUser];
    NSAssert(user, @"current user empty");
    id<DKDStorageCommand> cmd;
    cmd = [[DIMStorageCommand alloc] initWithTitle:DIMCommand_Contacts];
    // 1. generate password
    id<MKSymmetricKey> password = MKSymmetricKeyGenerate(MKSymmetricAlgorithm_AES);
    // 2. encrypt contacts list
    NSData *data = MKUTF8Encode(MKJsonEncode(MKMIDRevert(contacts)));
    data = [password encrypt:data extra:cmd.dictionary];
    // 3. encrypt key
    NSData *key = MKUTF8Encode(MKJsonEncode(password.dictionary));
    id<DIMEncryptedBundle> bundle = [user encryptBundle:key];
    // FIXME: for each key data in results
    key = [bundle.values anyObject];
    // 4. pack 'storage' command
    [cmd setIdentifier:user.identifier];
    [cmd setData:data];
    [cmd setKey:key];
    // 5. send to current station
    return [self sendCommand:cmd priority:STDeparturePrioritySlower];
}

@end

@implementation DIMSharedMessenger (Query)

- (BOOL)queryContacts {
    id<MKMUser> user = [self currentUser];
    NSAssert(user, @"current user empty");
    // pack 'contacts' command
    id<DKDStorageCommand> cmd;
    cmd = [[DIMStorageCommand alloc] initWithTitle:DIMCommand_Contacts];
    [cmd setIdentifier:user.identifier];
    // send to current station
    return [self sendCommand:cmd priority:STDeparturePrioritySlower];
}

- (BOOL)queryMuteList {
    id<DKDCommand> cmd = [[DIMMuteCommand alloc] initWithList:nil];
    return [self sendCommand:cmd priority:STDeparturePrioritySlower];
}

- (BOOL)queryBlockList {
    id<DKDCommand> cmd = [[DIMBlockCommand alloc] initWithList:nil];
    return [self sendCommand:cmd priority:STDeparturePrioritySlower];
}

- (BOOL)queryGroupForID:(id<MKMID>)group fromMember:(id<MKMID>)member {
    NSAssert(false, @"implement me!");
    return NO;
}

- (BOOL)queryGroupForID:(id<MKMID>)group fromMembers:(NSArray<id<MKMID>> *)members {
    NSAssert(false, @"implement me!");
    return NO;
}

@end

@implementation DIMSharedMessenger (Factories)

+ (void)prepare {
    
    //
    //  Register command parsers
    //

    // Report (online, offline)
    DIMCommandRegisterClass(@"broadcast", DIMReportCommand);
    DIMCommandRegisterClass(DIMCommand_Online, DIMReportCommand);
    DIMCommandRegisterClass(DIMCommand_Offline, DIMReportCommand);
    
    // Storage (contacts, private_key)
    DIMCommandRegisterClass(DIMCommand_Storage, DIMStorageCommand);
    DIMCommandRegisterClass(DIMCommand_Contacts, DIMStorageCommand);
    DIMCommandRegisterClass(DIMCommand_PrivateKey, DIMStorageCommand);
    
    // Search (users)
    DIMCommandRegisterClass(DIMCommand_Search, DIMSearchCommand);
    DIMCommandRegisterClass(DIMCommand_OnlineUsers, DIMSearchCommand);
}

@end
