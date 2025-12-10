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
//  Client+Creation.m
//  Sechat
//
//  Created by Albert Moky on 2023/3/14.
//  Copyright © 2023 DIM Group. All rights reserved.
//

#import "DIMGlobalVariable.h"
#import "DIMSharedPacker.h"
#import "DIMSharedProcessor.h"
#import "DIMSharedMessenger.h"
#import "DIMSharedSession.h"

#import "Client.h"

@implementation Client (Creation)

- (DIMClientSession *)createSessionWithStation:(id<MKMStation>)server {
    DIMSharedSession *session;
    session = [[DIMSharedSession alloc] initWithDatabase:self.database
                                                 station:server];
    // set current user for handshaking
    id<MKMUser> user = [self.facebook currentUser];
    if (user) {
        [session setIdentifier:user.identifier];
    }
    [session startWithStateDelegate:self];
    return session;
}

- (id<DIMPacker>)createPackerWithFacebook:(DIMCommonFacebook *)barrack
                                messenger:(DIMClientMessenger *)transceiver {
    return [[DIMSharedPacker alloc] initWithFacebook:barrack
                                           messenger:transceiver];
}

- (id<DIMProcessor>)createProcessorWithFacebook:(DIMCommonFacebook *)barrack
                                      messenger:(DIMClientMessenger *)transceiver {
    return [[DIMSharedProcessor alloc] initWithFacebook:barrack
                                              messenger:transceiver];
}

- (DIMClientMessenger *)createMessengerWithFacebook:(DIMCommonFacebook *)barrack
                                            session:(DIMClientSession *)session {
    id<DIMMessageDBI> mdb = [DIMGlobal mdb];
    DIMSharedMessenger *messenger;
    messenger = [[DIMSharedMessenger alloc] initWithFacebook:barrack
                                                     session:session
                                                    database:mdb];
    [DIMGlobal setMessenger:messenger];
    return messenger;
}

@end
