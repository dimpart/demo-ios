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
//  DIMMessageBuilder.m
//  Sechat
//
//  Created by Albert Moky on 2019/10/22.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "DIMGlobalVariable.h"

#import "DIMMessageBuilder.h"

#define readable_name(ID)    [self nameForID:(ID)]

@implementation DIMMessageBuilder

// protected
- (NSString *)nameForID:(id<MKMID>)ID {
    // get name from document
    id<MKMDocument> doc = DIMDocumentForID(ID, @"*");
    NSString *nickname = [doc propertyForKey:@"name"];
    if ([nickname length] > 0) {
        return nickname;
    }
    // get name from ID
    return [MKMAnonymous name:ID];
}

#pragma mark Group Commands

// private
- (NSString *)textFromInviteCommand:(id<DKDInviteGroupCommand>)content
                             sender:(id<MKMID>)commander {
    // get 'added' list
    NSArray<id<MKMID>> *addeds = MKMIDConvert([content objectForKey:@"added"]);
    // build message
    NSMutableArray *mArr = [[NSMutableArray alloc] initWithCapacity:addeds.count];
    for (id<MKMID> item in addeds) {
        [mArr addObject:readable_name(item)];
    }
    NSString *str = [mArr componentsJoinedByString:@", "];
    NSString *format = NSLocalizedString(@"%@ has invited member(s): %@.", nil);
    NSString *text = [NSString stringWithFormat:format, readable_name(commander), str];
    [content setObject:text forKey:@"text"];
    return text;
}

// private
- (NSString *)textFromExpelCommand:(id<DKDExpelGroupCommand>)content
                            sender:(id<MKMID>)commander {
    // get 'removed' list
    NSArray<id<MKMID>> *removeds = MKMIDConvert([content objectForKey:@"removed"]);
    NSMutableArray *mArr = [[NSMutableArray alloc] initWithCapacity:removeds.count];
    for (id<MKMID> item in removeds) {
        [mArr addObject:readable_name(item)];
    }
    NSString *str = [mArr componentsJoinedByString:@", "];
    NSString *format = NSLocalizedString(@"%@ has removed member(s): %@.", nil);
    NSString *text = [NSString stringWithFormat:format, readable_name(commander), str];
    [content setObject:text forKey:@"text"];
    return text;
}

// private
- (NSString *)textFromQuitCommand:(id<DKDQuitGroupCommand>)content
                           sender:(id<MKMID>)commander {
    NSString *format = NSLocalizedString(@"%@ has quitted group chat.", nil);
    NSString *text = [NSString stringWithFormat:format, readable_name(commander)];
    [content setObject:text forKey:@"text"];
    return text;
}

// private
- (NSString *)textFromResetCommand:(id<DKDResetGroupCommand>)content
                            sender:(id<MKMID>)commander {
    NSString *format = NSLocalizedString(@"%@ has updated group members", nil);
    NSString *text = [NSString stringWithFormat:format, readable_name(commander)];
    
    // get 'added' list
    NSArray<id<MKMID>> *addeds = MKMIDConvert([content objectForKey:@"added"]);
    if (addeds.count > 0) {
        NSMutableArray *mArr = [[NSMutableArray alloc] initWithCapacity:addeds.count];
        for (id<MKMID> item in addeds) {
            [mArr addObject:readable_name(item)];
        }
        NSString *str = [mArr componentsJoinedByString:@", "];
        text = [text stringByAppendingFormat:@"; %@ %@", NSLocalizedString(@"invited", nil), str];
    }
    
    // get 'removed' list
    NSArray<id<MKMID>> *removeds = MKMIDConvert([content objectForKey:@"removed"]);
    if (removeds.count > 0) {
        NSMutableArray *mArr = [[NSMutableArray alloc] initWithCapacity:removeds.count];
        for (id<MKMID> item in removeds) {
            [mArr addObject:readable_name(item)];
        }
        NSString *str = [mArr componentsJoinedByString:@", "];
        text = [text stringByAppendingFormat:@"; %@ %@", NSLocalizedString(@"removed", nil), str];
    }
    
    [content setObject:text forKey:@"text"];
    return text;
}

// private
- (NSString *)textFromQueryCommand:(id<DKDQueryGroupCommand>)content
                            sender:(id<MKMID>)commander {
    NSString *format = NSLocalizedString(@"%@ was querying group info, responding...", nil);
    NSString *text = [NSString stringWithFormat:format, readable_name(commander)];
    [content setObject:text forKey:@"text"];
    return text;
}

// private
- (NSString *)textFromGroupCommand:(id<DKDGroupCommand>)content
                            sender:(id<MKMID>)commander {
    if ([content conformsToProtocol:@protocol(DKDInviteGroupCommand)]) {
        return [self textFromInviteCommand:(id<DKDInviteGroupCommand>)content
                                    sender:commander];
    }
    if ([content conformsToProtocol:@protocol(DKDExpelGroupCommand)]) {
        return [self textFromExpelCommand:(id<DKDExpelGroupCommand>)content
                                   sender:commander];
    }
    if ([content conformsToProtocol:@protocol(DKDQuitGroupCommand)]) {
        return [self textFromQuitCommand:(id<DKDQuitGroupCommand>)content
                                  sender:commander];
    }
    if ([content isKindOfClass:[DIMResetGroupCommand class]]) {
        return [self textFromResetCommand:(id<DKDResetGroupCommand>)content
                                   sender:commander];
    }
    if ([content isKindOfClass:[DIMQueryGroupCommand class]]) {
        return [self textFromQueryCommand:(id<DKDQueryGroupCommand>)content
                                   sender:commander];
    }
    NSAssert(!content, @"group command error: %@", content);
    return nil;
}

#pragma mark System Commands

- (NSString *)textFromLoginCommand:(id<DKDLoginCommand>)content
                            sender:(id<MKMID>)commander {
    id<MKMID> ID = [content identifier];
    NSDictionary *station = content.stationInfo;
    NSString *format = NSLocalizedString(@"%@ login: %@", nil);
    NSString *text = [NSString stringWithFormat:format, readable_name(ID), station];
    [content setObject:text forKey:@"text"];
    return text;
}

#pragma mark -

- (NSString *)textFromCommand:(id<DKDCommand>)content sender:(id<MKMID>)commander {
    NSString *text = [content objectForKey:@"text"];
    if ([text length] > 0) {
        return text;
    }
    if ([content isKindOfClass:[DIMGroupCommand class]]) {
        return [self textFromGroupCommand:(id<DKDGroupCommand>)content
                                   sender:commander];
    }
    if ([content isKindOfClass:[DIMHistoryCommand class]]) {
        // TODO: process history command
    }
    if ([content isKindOfClass:[DIMLoginCommand class]]) {
        return [self textFromLoginCommand:(id<DKDLoginCommand>)content
                                   sender:commander];
    }
    NSString *format = NSLocalizedString(@"Current version doesn't support this command: %@", nil);
    return [NSString stringWithFormat:format, [content cmd]];
}

- (NSString *)textFromContent:(id<DKDContent>)content {
    // Text
    if ([content isKindOfClass:[DIMTextContent class]]) {
        return [(DIMTextContent *)content text];
    }
    NSString *text = [content objectForKey:@"text"];
    if ([text length] > 0) {
        return text;
    }
    // File: Image, Audio, Video
    if ([content isKindOfClass:[DIMFileContent class]]) {
        if ([content isKindOfClass:[DIMImageContent class]]) {
            NSString *filename = [(DIMImageContent *)content filename];
            NSString *format = NSLocalizedString(@"[Image:%@]", nil);
            text = [NSString stringWithFormat:format, filename];
        } else if ([content isKindOfClass:[DIMAudioContent class]]) {
            NSString *filename = [(DIMAudioContent *)content filename];
            NSString *format = NSLocalizedString(@"[Voice:%@]", nil);
            text = [NSString stringWithFormat:format, filename];
        } else if ([content isKindOfClass:[DIMVideoContent class]]) {
            NSString *filename = [(DIMVideoContent *)content filename];
            NSString *format = NSLocalizedString(@"[Movie:%@]", nil);
            text = [NSString stringWithFormat:format, filename];
        } else {
            NSString *filename = [(DIMFileContent *)content filename];
            NSString *format = NSLocalizedString(@"[File:%@]", nil);
            text = [NSString stringWithFormat:format, filename];
        }
    } else if ([content isKindOfClass:[DIMPageContent class]]) {
        DIMPageContent *page = (DIMPageContent *)content;
        NSString *text = page.title;
        if ([text length] == 0) {
            text = page.desc;
            if ([text length] == 0) {
                text = [page.URL absoluteString];
            }
        }
        NSString *format = NSLocalizedString(@"[Web:%@]", nil);
        text = [NSString stringWithFormat:format, text];
    } else {
        NSString *format = NSLocalizedString(@"This client doesn't support this message type: %u", nil);
        text = [NSString stringWithFormat:format, content.type];
    }
    
    if ([text length] > 0) {
        [content setObject:text forKey:@"text"];
    }
    return text;
}

@end

@implementation DIMContent (Extension)

- (nullable NSString *)messageWithSender:(id<MKMID>)sender {
    DIMMessageBuilder *builder = [[DIMMessageBuilder alloc] init];
    if ([self conformsToProtocol:@protocol(DKDCommand)]) {
        return [builder textFromCommand:(id<DKDCommand>)self sender:sender];
    } else {
        return [builder textFromContent:self];
    }
}

@end
