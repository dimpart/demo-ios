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
//  DIMDocumentTable.m
//  DIMP
//
//  Created by Albert Moky on 2019/9/6.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import <DIMSDK/DIMSDK.h>

#import "DIMGlobalVariable.h"

#import "DIMConstants.h"
#import "DIMDocumentTable.h"

@interface DIMDocumentTable () {
    
    NSMutableDictionary<id<MKMID>, id<MKMDocument>> *_caches;
    
    id<MKMDocument> _empty;
}

@end

@implementation DIMDocumentTable

- (instancetype)init {
    if (self = [super init]) {
        _caches = [[NSMutableDictionary alloc] init];
        
        _empty = [[DIMDocument alloc] initWithID:MKMAnyone type:MKMDocumentType_Profile];
    }
    return self;
}

/**
 *  Get profile filepath in Documents Directory
 *
 * @param ID - entity ID
 * @return "Documents/.mkm/{address}/profile.plist"
 */
- (NSString *)_filePathWithID:(id<MKMID>)ID {
    NSString *dir = [DIMStorage documentDirectory];
    dir = [dir stringByAppendingPathComponent:@".mkm"];
    dir = [dir stringByAppendingPathComponent:ID.address.string];
    return [dir stringByAppendingPathComponent:@"profile.plist"];
}

- (nullable id<MKMDocument>)documentForID:(id<MKMID>)ID withType:(nullable NSString *)type {
    // 1. try from memory cache
    id<MKMDocument> doc = [_caches objectForKey:ID];
    if (!doc) {
        // 2. try from database
        NSString *path = [self _filePathWithID:ID];
        NSDictionary *dict = [DIMStorage dictionaryWithContentsOfFile:path];
        if (dict) {
            NSLog(@"document from: %@", path);
            if ([type length] == 0 || [type isEqualToString:@"*"]) {
                type = [dict objectForKey:@"type"];
                if ([type length] == 0) {
                    type = @"*";
                }
            }
            NSString *data = [dict objectForKey:@"data"];
            NSString *signature = [dict objectForKey:@"signature"];
            id<MKTransportableData> ted = MKTransportableDataParse(signature);
            doc = MKMDocumentCreate(type, ID, data, ted);
        }
        if (!doc) {
            // 2.1. place an empty meta for cache
            doc = _empty;
        }
        // 3. store into memory cache
        [_caches setObject:doc forKey:ID];
    }
    if (doc == _empty) {
        NSLog(@"document not found: %@", ID);
        return nil;
    }
    return doc;
}

- (NSArray<id<MKMDocument>> *)documentsForID:(id<MKMID>)entity {
    id<MKMDocument> doc = [self documentForID:entity withType:nil];
    if (doc) {
        return @[doc];
    } else {
        return nil;
    }
}

- (BOOL)saveDocument:(id<MKMDocument>)doc {
    if (!doc.isValid) {
        NSLog(@"document not valid: %@", doc);
        return NO;
    }
    id<MKMID> ID = doc.identifier;
    // 1. store into memory cache
    [_caches setObject:doc forKey:ID];
    // 2. save into database
    NSString *path = [self _filePathWithID:ID];
    NSLog(@"saving document into: %@ -> %@", ID, path);
    BOOL ok = [DIMStorage dictionary:doc.dictionary writeToBinaryFile:path];
    if (ok) {
        NSDictionary *info = [doc dictionary];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:kNotificationName_DocumentUpdated
                          object:self
                        userInfo:info];
    }
    return ok;
}

@end
