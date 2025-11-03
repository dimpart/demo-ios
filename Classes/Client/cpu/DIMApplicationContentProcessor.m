// license: https://mit-license.org
//
//  DIM-SDK : Decentralized Instant Messaging Software Development Kit
//
//                               Written in 2022 by Moky <albert.moky@gmail.com>
//
// =============================================================================
// The MIT License (MIT)
//
// Copyright (c) 2022 Albert Moky
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
//  DIMApplicationContentProcessor.m
//  DIMP
//
//  Created by Albert Moky on 2022/8/23.
//  Copyright © 2022 DIM Group. All rights reserved.
//

#import "DIMApplicationContentProcessor.h"

@interface DIMAppContentProcessor () {
    
    // module(s) for customized contents
    id<DIMCustomizedContentHandler> _driftBottle;
}

@end

@implementation DIMAppContentProcessor

/* designated initializer */
- (instancetype)initWithFacebook:(DIMFacebook *)barrack
                       messenger:(DIMMessenger *)transceiver {
    if (self = [super initWithFacebook:barrack messenger:transceiver]) {
        // modules
        _driftBottle = [[DIMDriftBottleHandler alloc] initWithFacebook:barrack
                                                             messenger:transceiver];
    }
    return self;
}

// override for your application
- (id<DIMCustomizedContentHandler>)filterApplication:(NSString *)app
                                          withModule:(NSString *)mod
                                             content:(id<DKDCustomizedContent>)body
                                            messasge:(id<DKDReliableMessage>)rMsg {
    if ([app isEqualToString:@"chat.dim.sechat"] &&
        [mod isEqualToString:@"drift_bottle"]) {
        // App ID match
        // customized module: "drift_bottle"
        return _driftBottle;
    }
    // TODO: define your modules here
    // ...
    return [super filterApplication:app withModule:mod content:body messasge:rMsg];
}

@end

id<DKDCustomizedContent> DIMAppContentCreate(NSString *app, NSString *mod, NSString *act) {
    return [[DIMCustomizedContent alloc] initWithType:DKDContentType_Application
                                          application:app
                                           moduleName:mod
                                           actionName:act];
}

#pragma mark - Application Customized Content Handler

/**
 *  Drift Bottle Game
 *  ~~~~~~~~~~~~~~~~~
 *
 *  Handler for customized content
 */
@implementation DIMDriftBottleHandler

- (NSArray<id<DKDContent>> *)handleAction:(NSString *)act
                                   sender:(id<MKMID>)uid
                                  content:(id<DKDCustomizedContent>)customized
                                  message:(id<DKDReliableMessage>)rMsg {
    NSAssert([act length] > 0, @"action name empty: %@", customized);
    if ([act isEqualToString:@"throw"]) {
        // action "throw"
        return [self doThrow:uid content:customized message:rMsg];
    } else if ([act isEqualToString:@"catch"]) {
        // action "catch"
        return [self doCatch:uid content:customized message:rMsg];
    }
    // TODO: define your actions here
    // ...

    return [super handleAction:act sender:uid content:customized message:rMsg];
}

- (NSArray<id<DKDContent>> *)doThrow:(id<MKMID>)sender
                             content:(id<DKDCustomizedContent>)customized
                             message:(id<DKDReliableMessage>)rMsg {
    // TODO: handle customized action with message content
    return nil;
}

- (NSArray<id<DKDContent>> *)doCatch:(id<MKMID>)sender
                             content:(id<DKDCustomizedContent>)customized
                             message:(id<DKDReliableMessage>)rMsg {
    // TODO: handle customized action with message content
    return nil;
}

@end
