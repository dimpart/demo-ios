//
//  ConversationCell.m
//  Sechat
//
//  Created by Albert Moky on 2019/3/5.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIView+Extension.h"
#import "UIColor+Extension.h"

#import "DIMGlobalVariable.h"
#import "DIMMessageBuilder.h"
#import "DIMProfile+Extension.h"
#import "DIMConstants.h"
#import "DIMConversation.h"

#import "Client.h"
#import "LocalDatabaseManager.h"

#import "ConversationCell.h"

@implementation ConversationCell

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]){
        
        self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];
        self.avatarImageView.layer.cornerRadius = 22.0;
        self.avatarImageView.layer.masksToBounds = YES;
        [self.contentView addSubview:self.avatarImageView];
        
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.nameLabel.font = [UIFont systemFontOfSize:16.0];
        [self.contentView addSubview:self.nameLabel];
        
        self.lastMsgLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.lastMsgLabel.font = [UIFont systemFontOfSize:13.0];
        self.lastMsgLabel.textColor = [UIColor colorWithHexString:@"9f9f9f"];
        [self.contentView addSubview:self.lastMsgLabel];
        
        self.lastTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.lastTimeLabel.font = [UIFont systemFontOfSize:12.0];
        self.lastTimeLabel.textColor = [UIColor colorWithHexString:@"9f9f9f"];
        self.lastTimeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:self.lastTimeLabel];
        
        self.badgeView = [[BadgeView alloc] init];
        self.badgeView.font = [UIFont systemFontOfSize:14.0];
        [self.badgeView setBackgroundColor:[UIColor redColor]];
        [self.badgeView setMaxBounds:CGRectMake(0.0, 0.0, 20.0, 20.0)];
        self.badgeView.badgeValue = @"";
        [self.contentView addSubview:self.badgeView];
        
        self.separatorInset = UIEdgeInsetsMake(0.0, 70.0, 0.0, 0.0);

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(onConversationUpdated:)
                   name:kNotificationName_ConversationUpdated object:nil];
        [nc addObserver:self selector:@selector(onProfileUpdate:)
                   name:kNotificationName_DocumentUpdated object:nil];
    }
    
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setConversation:(DIMConversation *)conversation {
    if (![_conversation.ID isEqual:conversation.ID]) {
        _conversation = conversation;
        [self loadData];
        [self setNeedsLayout];
    }
}

- (void)onProfileUpdate:(NSNotification *)o {
    NSDictionary *profileDic = [o userInfo];
    id<MKMID> ID = [profileDic objectForKey:@"ID"];
    if ([ID isEqual:self.conversation.ID]) {
        [NSObject performBlockOnMainThread:^{
            [self loadData];
            [self setNeedsLayout];
        } waitUntilDone:NO];
    }
}

- (void)onConversationUpdated:(NSNotification *)o {
    NSDictionary *info = [o userInfo];
    id<MKMID> ID = MKMIDParse([info objectForKey:@"ID"]);
    if ([_conversation.ID isEqual:ID]) {
        [NSObject performBlockOnMainThread:^{
            [self loadData];
            [self setNeedsLayout];
        } waitUntilDone:NO];
    }
}

- (void)loadData {
    id<MKMDocument> doc = DIMDocumentForID(_conversation.ID, @"*");
    
    // avatar
    CGRect frame = _avatarImageView.frame;
    UIImage *image;
    if (MKMIDIsGroup(_conversation.ID)) {
        image = [(DIMBulletin *)doc logoImageWithSize:frame.size];
    } else {
        image = [(DIMVisa *)doc avatarImageWithSize:frame.size];
    }
    
    [_avatarImageView setImage:image];
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    _nameLabel.text = [facebook getName:_conversation.ID];

    // last message
    NSString *last = nil;
    NSInteger count = [_conversation numberOfMessage];
    id<DKDInstantMessage> msg;
    id<MKMID> sender;
    DIMContent *content;
    while (--count >= 0) {
        msg = [_conversation messageAtIndex:count];
        sender = msg.envelope.sender;
        content = (DIMContent *)[msg content];
        last = [content messageWithSender:sender];
        if (last.length > 0) {
            // got it
            break;
        }
    }
    _lastMsgLabel.text = last;
    
    NSTimeInterval timestamp = [[msg objectForKey:@"time"] doubleValue];
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:timestamp];
    
    self.lastTimeLabel.text = [self dateString:date];
    
    //Unread Message
    NSInteger unreadCount = [[LocalDatabaseManager sharedInstance] getUnreadMessageCount:_conversation.ID];
    
    if(unreadCount > 0 && unreadCount <= 99){
        self.badgeView.badgeValue = [NSString stringWithFormat:@"%zd", unreadCount];
    }else if(unreadCount > 99){
        self.badgeView.badgeValue = @"99+";
    }else{
        self.badgeView.badgeValue = @"";
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat x = 13.0;
    CGFloat y = 10.0;
    CGFloat width = 44.0;
    CGFloat height = 44.0;
    
    self.avatarImageView.frame = CGRectMake(x, y, width, height);
    
    if(self.badgeView.badgeValue == nil || [self.badgeView.badgeValue isEqualToString:@""]){
        
        width = 0.0;
        height = 0.0;
        self.badgeView.hidden = YES;
        
    }else{
    
        [self.badgeView sizeToFit];
        width = self.badgeView.bounds.size.width;
        height = self.badgeView.bounds.size.height;
        self.badgeView.hidden = NO;
    }
    
    x = self.contentView.bounds.size.width - width - 13.0;
    y = (self.contentView.bounds.size.height - height) / 2.0;
    self.badgeView.frame = CGRectMake(x, y, width, height);
    
    width = 70.0;
    y = 13.0;
    x = self.badgeView.frame.origin.x - width - 13.0;
    height = 19.0;
    self.lastTimeLabel.frame = CGRectMake(x, y, width, height);
    
    x = self.avatarImageView.frame.origin.x + self.avatarImageView.frame.size.width + 13.0;
    y = 13.0;
    width = self.lastTimeLabel.frame.origin.x - x - 5.0;
    height = 19.0;
    self.nameLabel.frame = CGRectMake(x, y, width, height);
    
    y = y + height + 5.0;
    height = 15.0;
    width = self.badgeView.frame.origin.x - 13.0 - x;
    self.lastMsgLabel.frame = CGRectMake(x, y, width, height);
}

-(NSString *)dateString:(NSDate *)date{
    
    NSString *timeString = @"";
    NSDate *days_ago = [[[NSDate date] dateBySubtractingDays:7] dateAtStartOfDay];
    
    if([date isYesterday]){
        timeString = NSLocalizedString(@"Yesterday", @"title");
    } else if([date isToday]){
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:NSLocalizedString(@"HH:mm a", @"title")];
        timeString = [dateFormatter stringFromDate:date];
        
    } else if([date isLaterThanDate:days_ago]){
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"EEEE"];
        timeString = [dateFormatter stringFromDate:date];
    } else {
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy/MM/dd"];
        timeString = [dateFormatter stringFromDate:date];
    }
    
    return timeString;
}

@end
