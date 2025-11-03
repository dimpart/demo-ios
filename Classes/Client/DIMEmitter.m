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
//  DIMEmitter.m
//  Sechat
//
//  Created by Albert Moky on 2023/3/13.
//  Copyright © 2023 DIM Group. All rights reserved.
//

#import "DIMConstants.h"
#import "DIMGlobalVariable.h"
#import "DIMFileTransfer.h"
#import "DIMMessageDataSource.h"

#import "DIMEmitter.h"

static inline void save_instant_message(id<DKDInstantMessage> iMsg) {
    DIMMessageDataSource *mds = [DIMMessageDataSource sharedInstance];
    BOOL ok = [mds saveInstantMessage:iMsg];
    assert(ok);
}

static inline void send_instant_message(id<DKDInstantMessage> iMsg) {
    NSLog(@"send insetant message (type: %@): %@ -> %@", iMsg.content.type, iMsg.sender, iMsg.receiver);
    // send by shared messenger
    DIMSharedMessenger *messenger = [DIMGlobal messenger];
    [messenger sendInstantMessage:iMsg priority:STDeparturePriorityNormal];
}

@interface DIMEmitter () {
    
    // filename => task
    NSMutableDictionary<NSString *, id<DKDInstantMessage>> *_map;
}

@end

@implementation DIMEmitter

- (instancetype)init {
    if (self = [super init]) {
        _map = [[NSMutableDictionary alloc] init];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(onFileUploadSuccess:) name:kNotificationName_FileUploaded object:nil];
        [nc addObserver:self selector:@selector(onFileUploadFailed:) name:kNotificationName_FileUploadFailed object:nil];
    }
    return self;
}

// private
- (DIMFileTransfer *)fileTransfer {
    // TODO: get 'api' & 'secret' from comfiguration
    return [DIMFileTransfer sharedInstance];
}

// private
- (void)addTask:(id<DKDInstantMessage>)iMsg filename:(NSString *)filename {
    @synchronized (_map) {
        [_map setObject:iMsg forKey:filename];
    }
}

// private
- (nullable id<DKDInstantMessage>)popTask:(NSString *)filename {
    @synchronized (_map) {
        id<DKDInstantMessage> iMsg = [_map objectForKey:filename];
        if (iMsg) {
            [_map removeObjectForKey:filename];
        }
        return iMsg;
    }
}

- (void)purge {
    // TODO: remove expired messages in the map
}

- (void)onFileUploadSuccess:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    DIMUploadRequest *req = [info objectForKey:@"request"];
    NSDictionary *response = [info objectForKey:@"response"];
    NSURL *url = [response objectForKey:@"url"];
    NSLog(@"onFileUploadSuccess: %@, url: %@", req, url);

    NSString *filename = [DIMFileTransfer filenameForRequest:req];
    id<DKDInstantMessage> iMsg = [self popTask:filename];
    if (!iMsg) {
        NSLog(@"failed to get task: %@, url: %@", filename, url);
        return;
    }
    NSLog(@"get task for file: %@, url: %@", filename, url);
    // file data uploaded to FTP server, replace it with download URL
    // and send the content to station
    id<DKDFileContent> content = (id<DKDFileContent>)[iMsg content];
    //content.fileData = nil;
    [content setURL:url];
    // try to send out
    send_instant_message(iMsg);
}

- (void)onFileUploadFailed:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    DIMUploadRequest *req = [info objectForKey:@"request"];
    id error = [info objectForKey:@"error"];
    NSLog(@"onFileUploadFailed: %@, error: %@", req, error);
    
    NSString *filename = [DIMFileTransfer filenameForRequest:req];
    id<DKDInstantMessage> iMsg = [self popTask:filename];
    if (!iMsg) {
        NSLog(@"failed to get task: %@", filename);
        return;
    }
    NSLog(@"get task for file: %@", filename);
    // file data failed to upload, mark it error
    info = @{
        @"message": @"failed to upload file"
    };
    [iMsg setObject:info forKey:@"error"];
    // TODO: update message with error info into database
}

- (void)sendFileContentMessage:(id<DKDInstantMessage>)iMsg
                      password:(id<MKSymmetricKey>)key {
    id<DKDFileContent> content = (id<DKDFileContent>)[iMsg content];
    // 1. save origin file data
    NSData *data = [content data];
    NSString *filename = [content filename];
    BOOL ok = [DIMFileTransfer cacheFileData:data filename:filename];
    if (!ok) {
        NSLog(@"failed to save file data (%lu bytes): %@", data.length, filename);
        return;
    }
    // 2. save instant message without file data
    [content setData:nil];
    save_instant_message(iMsg);
    // 3. add upload task with encrypted data
    NSData *encrypted = [key encrypt:data extra:content.dictionary];
    filename = [DIMFileTransfer filenameForData:encrypted filename:filename];
    id<MKMID> sender = [iMsg sender];
    NSURL *url = [self.fileTransfer uploadEncryptedData:encrypted
                                               filename:filename
                                                 sender:sender];
    if (url) {
        // already upload before, set URL and send out immediately
        NSLog(@"uploaded filename: %@ -> %@ => %@",
              content.filename, filename, url);
        [content setURL:url];
        send_instant_message(iMsg);
    } else {
        // add task for upload
        [self addTask:iMsg filename:filename];
        NSLog(@"waiting upload filename: %@ -> %@", content.filename, filename);
    }
}

- (void)sendText:(NSString *)text receiver:(id<MKMID>)to {
    id<DKDContent> content = [[DIMTextContent alloc] initWithText:text];
    [self sendContent:content receiver:to];
}

- (void)sendImage:(NSData *)jpeg thumbnail:(NSData *)small receiver:(id<MKMID>)to {
    id<MKTransportableData> img = MKTransportableDataCreate(jpeg, nil);
    id<MKTransportableData> ted = MKTransportableDataCreate(small, nil);
    id<MKPortableNetworkFile> ico = MKPortableNetworkFileCreate(ted, nil, nil, nil);
    NSUInteger length = jpeg.length;
    NSAssert(length > 0, @"image data empty");
    NSString *filename = MKHexEncode(MKMD5Digest(jpeg));
    filename = [filename stringByAppendingPathExtension:@"jpeg"];
    id<DKDImageContent> content = DIMImageContentFromData(img, filename);
    // add image data length & thumbnail into message content
    [content setObject:@(length) forKey:@"length"];
    [content setThumbnail:ico];
    [self sendContent:content receiver:to];
}

- (void)sendVoice:(NSData *)mp4 duration:(NSTimeInterval)ti receiver:(id<MKMID>)to {
    id<MKTransportableData> ted = MKTransportableDataCreate(mp4, nil);
    NSUInteger length = mp4.length;
    NSAssert(length > 0, @"voice data empty");
    NSString *filename = MKHexEncode(MKMD5Digest(mp4));
    filename = [filename stringByAppendingPathExtension:@"mp4"];
    id<DKDAudioContent> content = DIMAudioContentFromData(ted, filename);
    // add image data length & thumbnail into message content
    [content setObject:@(length) forKey:@"length"];
    [content setObject:@(ti) forKey:@"duration"];
    [self sendContent:content receiver:to];
}

// private
- (void)sendContent:(id<DKDContent>)content receiver:(id<MKMID>)to {
    NSAssert(to, @"receiver should not empty");
    DIMSharedMessenger *messenger = [DIMGlobal messenger];
    OKPair<id<DKDInstantMessage>, id<DKDReliableMessage>> *result;
    result = [messenger sendContent:content
                             sender:nil
                           receiver:to
                           priority:STDeparturePriorityNormal];
    if (result.second == nil) {
        NSLog(@"not send yet (type: %@): %@", content.type, to);
        return;
    }
    NSAssert(result.first, @"failed to pack instant message: %@", to);
    // save instant message
    DIMMessageDataSource *mds = [DIMMessageDataSource sharedInstance];
    [mds saveInstantMessage:result.first];
}

@end
