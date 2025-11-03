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
//  DIMSharedFacebook.h
//  DIMP
//
//  Created by Albert Moky on 2020/12/13.
//  Copyright © 2020 DIM Group. All rights reserved.
//

#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface DIMSharedFacebook : DIMClientFacebook

@end

@interface DIMSharedFacebook (User)

/**
 *  Get avatar for user
 *
 * @param user - user ID
 * @return cache path & remote URL
 */
- (OKPair<NSString *, NSString *> *)avatarForUser:(id<MKMID>)user;

- (BOOL)savePrivateKey:(id<MKPrivateKey>)SK withType:(NSString *)type forUser:(id<MKMID>)user;

- (BOOL)addUser:(id<MKMID>)user;

- (BOOL)removeUser:(id<MKMID>)user;

- (BOOL)saveContacts:(NSArray<id<MKMID>> *)contacts user:(id<MKMID>)user;

- (BOOL)addContact:(id<MKMID>)contact user:(id<MKMID>)user;

- (BOOL)removeContact:(id<MKMID>)contact user:(id<MKMID>)user;

@end

@protocol DIMAddressNameTable;

@interface DIMSharedFacebook (ANS)

+ (id<DIMAddressNameTable>)ansTable;

+ (void)setANSTable:(id<DIMAddressNameTable>)ansTable;

+ (void)prepare;

@end

NS_ASSUME_NONNULL_END
