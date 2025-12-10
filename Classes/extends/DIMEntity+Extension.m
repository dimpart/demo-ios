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
//  DIMEntity+Extension.m
//  DIMP
//
//  Created by Albert Moky on 2019/8/12.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "DIMGlobalVariable.h"

#import "DIMEntity+Extension.h"

@implementation DIMUser (LocalUser)

+ (nullable instancetype)userWithConfigFile:(NSString *)config {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:config];
    
    if (!dict) {
        NSLog(@"failed to load: %@", config);
        return nil;
    }
    
    id<MKMID> ID = MKMIDParse([dict objectForKey:@"did"]);
    id<MKMMeta> meta = MKMMetaParse([dict objectForKey:@"meta"]);
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    [facebook.archivist saveMeta:meta forID:ID];
    
    // save private key paired to meta.key
    id<MKPrivateKey> SK = MKPrivateKeyParse([dict objectForKey:@"privateKey"]);
    [facebook savePrivateKey:SK withType:DIMPrivateKeyType_Meta forUser:ID];
    
    DIMUser *user = (DIMUser *)DIMUserWithID(ID);
    
    // profile
    id profile = [dict objectForKey:@"profile"];
    if (profile) {
        // copy profile from config to local storage
        if (![profile objectForKey:@"did"]) {
            NSMutableDictionary *mDict;
            if ([profile isKindOfClass:[NSMutableDictionary class]]) {
                mDict = (NSMutableDictionary *) profile;
            } else {
                mDict = [profile mutableCopy];
                profile = mDict;
            }
            [mDict setObject:ID forKey:@"did"];
        }
        profile = MKMDocumentParse(profile);
        [facebook.archivist saveDocument:profile];
    }
    
    return user;
}

@end
