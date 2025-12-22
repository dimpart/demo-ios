//
//  DIMProfile+Extension.m
//  DIMP
//
//  Created by Albert Moky on 2019/3/2.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIImage+Extension.h"
#import "UIColor+Extension.h"

#import "DIMGlobalVariable.h"

#import "Facebook+Profile.h"
#import "Facebook+Register.h"
#import "Client.h"

#import "DIMProfile+Extension.h"

@implementation DIMVisa (Extension)

- (UIImage *)avatarImageWithSize:(const CGSize)size {
    
    UIImage *image = nil;
    
    id<MKPortableNetworkFile> avatar = [self avatar];
    // TODO: encrypted file?
    NSString *url = [avatar string];
    if (url) {
        if ([url containsString:@"://"]) {
            DIMSharedFacebook *facebook = [DIMGlobal facebook];
            id<MKMID> ID = MKMIDParse([self objectForKey:@"did"]);
            image = [facebook loadAvatarWithURL:url forID:ID];
        } else {
            image = [UIImage imageNamed:url];
        }
    }
    
    if(image == nil){
        image = [UIImage imageNamed:@"default_avatar"];
    }
    
    return image;
}

@end

@implementation DIMBulletin (Extension)

- (UIImage *)logoImageWithSize:(const CGSize)size {
    UIImage *image = nil;
    do {
//        // get image with logo (URL)
//        NSString *logo = self.logo;
//        if (logo) {
//            if ([logo containsString:@"://"]) {
//                NSURL *url = [NSURL URLWithString:logo];
//                image = [UIImage imageWithContentsOfURL:url];
//            } else {
//                image = [UIImage imageNamed:logo];
//            }
//            break;
//        }
        
        // create image with members' avatar(s)
        id<MKMID> ID = MKMIDParse([self objectForKey:@"did"]);
        NSArray<id<MKMID>> *members = DIMGroupWithID(ID).members;
        if (members.count > 0) {
            CGSize tileSize;
            if (members.count > 4) {
                tileSize = CGSizeMake(size.width / 3 - 2, size.height / 3 - 2);
            } else {
                tileSize = CGSizeMake(size.width / 2 - 2, size.height / 2 - 2);
            }
            NSMutableArray<UIImage *> *mArray;
            mArray = [[NSMutableArray alloc] initWithCapacity:members.count];
            for (id<MKMID> ID in members) {
                DIMVisa *visa = (DIMVisa *)DIMVisaForID(ID);
                image = [visa avatarImageWithSize:tileSize];
                if (image) {
                    [mArray addObject:image];
                    if (mArray.count >= 9) {
                        break;
                    }
                }
            }
            UIColor *bgColor = [UIColor colorWithHexString:@"E0E0F5"];
            image = [UIImage tiledImages:mArray size:size backgroundColor:bgColor];
            break;
        }
        //NSAssert(false, @"group members cannot be empty");
        
        // create image with first character of name
        NSString *name = self.name;
        if (name.length == 0) {
            id<MKMID> ID = MKMIDParse([self objectForKey:@"did"]);
            name = ID.name;
            if (name.length == 0) {
                name = @"Đ"; // BTC Address: ฿
            }
        }
        NSString *text = [name substringToIndex:1];
        //text = [NSString stringWithFormat:@"[%@]", text];
        UIColor *textColor = [UIColor blackColor];
        UIColor *bgColor = [UIColor colorWithHexString:@"E0E0F5"];
        image = [UIImage imageWithText:text size:size color:textColor backgroundColor:bgColor];
        
        break;
    } while (YES);
    return image;
}

@end
