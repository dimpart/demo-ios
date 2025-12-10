//
//  ContactCell.m
//  Sechat
//
//  Created by Albert Moky on 2019/3/5.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIView+Extension.h"
#import "UIColor+Extension.h"

#import "DIMConstants.h"
#import "DIMEntity+Extension.h"
#import "DIMProfile+Extension.h"
#import "DIMGlobalVariable.h"

#import "Facebook+Profile.h"

#import "ContactCell.h"

@implementation ContactCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]){
        
        self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];
        self.avatarImageView.layer.cornerRadius = 22.0;
        self.avatarImageView.layer.masksToBounds = YES;
        [self.contentView addSubview:self.avatarImageView];
        
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.nameLabel.font = [UIFont systemFontOfSize:16.0];
        [self.contentView addSubview:self.nameLabel];
        
        self.descLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.descLabel.font = [UIFont systemFontOfSize:13.0];
        self.descLabel.textColor = [UIColor colorWithHexString:@"9f9f9f"];
        [self.contentView addSubview:self.descLabel];
        
        self.separatorInset = UIEdgeInsetsMake(0.0, 70.0, 0.0, 0.0);
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(didAvatarUpdated:)
                   name:kNotificationName_AvatarUpdated object:nil];
        [nc addObserver:self selector:@selector(didProfileUpdated:)
                   name:kNotificationName_DocumentUpdated object:nil];
        [nc addObserver:self selector:@selector(didGroupMemberUpdated:)
                   name:kNotificationName_GroupMembersUpdated object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setContact:(id<MKMID>)contact {
    _contact = contact;
    [self setData];
    [self setNeedsLayout];
}

- (void)setData {
    
    CGRect frame = self.avatarImageView.frame;
    
    id<MKMDocument> profile = DIMDocumentForID(_contact, @"*");
    UIImage *image;
    if (MKMIDIsGroup(_contact)) {
        image = [(DIMBulletin *)profile logoImageWithSize:frame.size];
    } else {
        image = [(DIMVisa *)profile avatarImageWithSize:frame.size];
    }
    
    [_avatarImageView setImage:image];
    
    NSString *name = DIMNameForID(_contact);
    self.nameLabel.text = name;
    self.descLabel.text = [_contact string];
}

- (void)didAvatarUpdated:(NSNotification *)o {
    NSDictionary *userInfo = [o userInfo];
    id<MKMID> ID = [userInfo objectForKey:@"ID"];
    if (!ID) {
        ID = [userInfo objectForKey:@"did"];
    }
    
    if ([ID isEqual:self.contact]) {
        [NSObject performBlockOnMainThread:^{
            [self setData];
            [self setNeedsLayout];
        } waitUntilDone:NO];
    }
}

- (void)didProfileUpdated:(NSNotification *)o {
    NSDictionary *profileDic = [o userInfo];
    id<MKMID> ID = [profileDic objectForKey:@"ID"];
    if (!ID) {
        ID = [profileDic objectForKey:@"did"];
    }
    
    if ([ID isEqual:self.contact]) {
        [NSObject performBlockOnMainThread:^{
            [self setData];
            [self setNeedsLayout];
        } waitUntilDone:NO];
    }
}

- (void)didGroupMemberUpdated:(NSNotification *)o {
    NSDictionary *profileDic = [o userInfo];
    id<MKMID> ID = [profileDic objectForKey:@"group"];
    if ([ID isEqual:self.contact]) {
        [NSObject performBlockOnMainThread:^{
            [self setData];
            [self setNeedsLayout];
        } waitUntilDone:NO];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat x = 13.0;
    CGFloat y = 10.0;
    CGFloat width = self.avatarImageView.bounds.size.width;
    CGFloat height = self.avatarImageView.bounds.size.height;
    self.avatarImageView.frame = CGRectMake(x, y, width, height);
    
    x = x * 2 + width;
    y = 13.0;
    height = 19.0;
    width = self.contentView.bounds.size.width - 13.0 - x;
    self.nameLabel.frame = CGRectMake(x, y, width, height);
    
    y = y + height + 5.0;
    height = 15.0;
    self.descLabel.frame = CGRectMake(x, y, width, height);
}

@end
