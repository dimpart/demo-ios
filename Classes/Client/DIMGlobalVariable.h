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
//  DIMGlobalVariable.h
//  Sechat
//
//  Created by Albert Moky on 2023/3/13.
//  Copyright © 2023 DIM Group. All rights reserved.
//

#import "DIMSharedDatabase.h"
#import "DIMSharedFacebook.h"
#import "DIMSharedMessenger.h"
#import "DIMEmitter.h"

NS_ASSUME_NONNULL_BEGIN

#define MKMIDIsUser(ID)          [(ID) isUser]
#define MKMIDIsGroup(ID)         [(ID) isGroup]
#define MKMIDIsBroadcast(ID)     [(ID) isBroadcast]

#define DIMGlobal                [DIMGlobalVariable sharedInstance]

#define DIMNameForID(ID)         [[DIMGlobal facebook] getName:(ID)]
#define DIMMetaForID(ID)         [[DIMGlobal facebook] getMeta:(ID)]
#define DIMDocumentForID(ID, DT) [[DIMGlobal facebook] getDocument:(ID) withType:(DT)]
#define DIMVisaForID(ID)         DIMDocumentForID(ID, MKMDocumentType_Visa)

#define DIMUserWithID(ID)        [[DIMGlobal facebook] getUser:(ID)]
#define DIMGroupWithID(ID)       [[DIMGlobal facebook] getGroup:(ID)]

@interface DIMGlobalVariable : NSObject

@property(nonatomic, strong) id<DIMAccountDBI> adb;
@property(nonatomic, strong) id<DIMMessageDBI> mdb;
@property(nonatomic, strong) id<DIMSessionDBI> sdb;
@property(nonatomic, strong) DIMSharedDatabase *database;

@property(nonatomic, strong) DIMClientArchivist *archivist;
@property(nonatomic, strong) DIMSharedFacebook *facebook;
@property(nonatomic, strong) DIMSharedMessenger *messenger;

@property(nonatomic, strong) __kindof DIMTerminal *terminal;

@property(nonatomic, strong) DIMEmitter *emitter;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
