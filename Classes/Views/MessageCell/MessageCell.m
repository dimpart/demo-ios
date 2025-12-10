//
//  MessageCell.m
//  Sechat
//
//  Created by John Chen on 2019/9/20.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIView+Extension.h"

#import "DIMProfile+Extension.h"
#import "DIMInstantMessage+Extension.h"
#import "DIMGlobalVariable.h"
#import "DIMFileTransfer.h"
#import "DIMMessageBuilder.h"

#import "MessageCell.h"
#import "Facebook+Profile.h"
#import <AVFoundation/AVFoundation.h>

@implementation MessageCell

+ (CGSize)sizeWithMessage:(id<DKDInstantMessage>)message bounds:(CGRect)rect{
    return CGSizeMake(0.0, 0.0);
}

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]){
        
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.avatarImageView = [[UIImageView alloc] init];
        [self.avatarImageView addClickTarget:self action:@selector(showProfile:)];
        [self.contentView addSubview:self.avatarImageView];
        
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.nameLabel.font = [UIFont systemFontOfSize:12.0];
        self.nameLabel.textColor = [UIColor lightGrayColor];
        [self.contentView addSubview:self.nameLabel];
        
        UIImage *chatBackgroundImage = [UIImage imageNamed:@"receiver_bubble"];
        UIEdgeInsets insets = UIEdgeInsetsMake(17.0, 26.0, 17.0, 22.0);
        self.messageImageView = [[UIImageView alloc] initWithImage:[chatBackgroundImage resizableImageWithCapInsets:insets]];
        [self.contentView addSubview:self.messageImageView];
        
        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.messageLabel.numberOfLines = -1;
        self.messageLabel.textColor = [UIColor colorNamed:@"ReceiveMessageColor"];
        self.messageLabel.font = [UIFont systemFontOfSize:16.0];
        [self.contentView addSubview:self.messageLabel];
        
        self.picImageView = [[UIImageView alloc] init];
        self.picImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.picImageView];
        
        self.longPressGuesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressHappen:)];
        [self.contentView addGestureRecognizer:self.longPressGuesture];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(didAvatarUpdated:) name:kNotificationName_AvatarUpdated object:nil];
        
        self.audioButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.audioButton addTarget:self action:@selector(didPressPlayAudioButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.audioButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.audioButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
        [self.audioButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
        
        //UIImage *speakerImage = [[UIImage imageNamed:@"speaker"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *speakerImage = [UIImage imageNamed:@"speaker"];
        [self.audioButton setImage:speakerImage forState:UIControlStateNormal];
        self.audioButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.audioButton setTitleEdgeInsets:UIEdgeInsetsMake(0.0, 20.0, 0.0, 0.0)];
    }
    
    return self;
}

-(void)dealloc{
    [self.contentView removeGestureRecognizer:self.longPressGuesture];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)didAvatarUpdated:(NSNotification *)o {
    
    NSDictionary *userInfo = [o userInfo];
    id<MKMID> ID = [userInfo objectForKey:@"ID"];
    if (!ID) {
        ID = [userInfo objectForKey:@"did"];
    }
    
    [NSObject performBlockOnMainThread:^{
        id<DKDEnvelope> env = self.message.envelope;
        id<MKMID> sender = env.sender;
        
        if ([ID isEqual:sender]) {
            DIMVisa *profile = (DIMVisa *)DIMVisaForID(sender);
            CGRect avatarFrame = self.avatarImageView.frame;
            UIImage *image = [profile avatarImageWithSize:avatarFrame.size];
            [self.avatarImageView setImage:image];
        }
    } waitUntilDone:NO];
}

- (void)setMessage:(id<DKDInstantMessage>)message {
    if (![_message isEqual:message]) {
        _message = message;
        
        DIMInstantMessage *msg = (DIMInstantMessage *)message;
        
        id<DKDEnvelope> env = message.envelope;
        id<MKMID> sender = env.sender;
        DIMContent *content = (DIMContent *)[message content];
        DIMVisa *profile = (DIMVisa *)DIMVisaForID(sender);
        
        self.nameLabel.text = profile.name;
        
        // avatar
        CGRect avatarFrame = self.avatarImageView.frame;
        UIImage *image = [profile avatarImageWithSize:avatarFrame.size];
        [self.avatarImageView setImage:image];
        
        [self.audioButton removeFromSuperview];
        [self.contentView addSubview:self.messageLabel];
        [self.contentView addSubview:self.picImageView];
        
        // message
        NSString *type = [content type];
        if ([type isEqualToString:DKDContentType_Text]) {
                // show text
                self.messageLabel.text = [content messageWithSender:sender];
                // double click to zoom in
                [self.messageLabel addDoubleClickTarget:self action:@selector(zoomIn:)];
        } else if ([type isEqualToString:DKDContentType_File]) {
                // TODO: show file info
                self.messageLabel.text = [content messageWithSender:sender];
        } else if ([type isEqualToString:DKDContentType_Image]) {
                NSLog(@"image content: %@", content);
                // show image
                if (msg.image) {
                    self.picImageView.image = msg.image;
                } else {
                    self.messageLabel.text = [content messageWithSender:sender];
                }
                
                [self.picImageView addClickTarget:self action:@selector(zoomIn:)];
        } else if ([type isEqualToString:DKDContentType_Audio]) {
                // TODO: show audio info
                [self.messageLabel removeFromSuperview];
                [self.picImageView removeFromSuperview];
                [self.contentView addSubview:self.audioButton];
                
//                NSTimeInterval duration = [[content objectForKey:@"duration"] doubleValue];
//
//                if(duration <= 0){
                
                NSTimeInterval duration = 0;
                if (msg.audioData) {
                    DIMAudioContent *content = (DIMAudioContent *)self.message.content;
                    DIMFileTransfer *ftp = [DIMFileTransfer sharedInstance];
                    NSString *path = [ftp pathForContent:content];
                    
                    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
                    duration = CMTimeGetSeconds(asset.duration);
                }
                
                NSString *durationString = [NSString stringWithFormat:@"%f''", duration];
                [self.audioButton setTitle:durationString forState:UIControlStateNormal];
                self.messageLabel.text = durationString;
        } else if ([type isEqualToString:DKDContentType_Audio]) {
                // TODO: show video info
                self.messageLabel.text = [content messageWithSender:sender];
        } else if ([type isEqualToString:DKDContentType_Page]) {
                // TODO: show web page
                DIMPageContent *page = (DIMPageContent *)content;
                NSString *title = page.title;
                NSString *desc = page.desc;
                NSURL *url = page.URL;
                id<MKPortableNetworkFile> icon = page.icon;
                
                // title
                title = [title stringByAppendingString:@"\n"];
                // desc
                if (desc.length == 0) {
                    NSString *format = NSLocalizedString(@"[Web:%@]", nil);
                    desc = [NSString stringWithFormat:format, url];
                }
                // icon
                UIImage *image = nil;
                if (![icon isEmpty]) {
                    image = [UIImage imageWithData:icon.data];
                }
                
                NSMutableAttributedString *attrText;
                attrText = [[NSMutableAttributedString alloc] init];
                
                if (image) {
                    NSTextAttachment *att = [[NSTextAttachment alloc] init];
                    att.image = image;
                    att.bounds = CGRectMake(0, 0, 12, 12);
                    
                    NSAttributedString *head;
                    head = [NSAttributedString attributedStringWithAttachment:att];
                    [attrText appendAttributedString:head];
                }
                
                NSMutableAttributedString *line1, *line2;
                line1 = [[NSMutableAttributedString alloc] initWithString:title];
                line2 = [[NSMutableAttributedString alloc] initWithString:desc];
                [line2 addAttribute:NSForegroundColorAttributeName
                             value:[UIColor lightGrayColor]
                             range:NSMakeRange(0, desc.length)];
                
                [attrText appendAttributedString:line1];
                [attrText appendAttributedString:line2];
                
                self.messageLabel.attributedText = attrText;
                
                [self.messageLabel addClickTarget:self action:@selector(openURL:)];
        } else {
                NSString *text = [content messageWithSender:sender];
                if ([text length] == 0) {
                    // unsupported message type
                    NSString *format = NSLocalizedString(@"This client doesn't support this message type: %u", nil);
                    text = [NSString stringWithFormat:format, content.type];
                }
                self.messageLabel.text = text;
        }
        
        [self setNeedsLayout];
    }
}

- (void)zoomIn:(UITapGestureRecognizer *)sender {
    
    if (self.delegate != nil) {
        DIMInstantMessage *msg = self.message;
        [self.delegate messageCell:self showImage:msg.image];
    }
}

-(void)showProfile:(id)sender{
    
    if(self.delegate != nil){
        id<DKDEnvelope> env = self.message.envelope;
        id<MKMID> sender = env.sender;
        [self.delegate messageCell:self showProfile:sender];
    }
}

-(void)didLongPressHappen:(id)sender{
    
    if (sender == self.longPressGuesture){
        
        if (self.longPressGuesture.state == UIGestureRecognizerStateBegan){
            
            if(!self.messageLabel.hidden){
            
                [self becomeFirstResponder];
                [self popMemu];
            }
        }
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(copyClick) )
    {
        return YES;
    }
    return NO;
}

- (void)popMemu
{
    UIMenuItem *menuItem_1 = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", @"title") action:@selector(copyClick)];
    
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    menuController.menuItems = [NSArray arrayWithObjects:menuItem_1, nil];
    
    CGFloat width = 40.0;
    CGFloat height = 40.0;
    CGFloat x = self.messageLabel.frame.origin.x;
    CGFloat y = self.frame.origin.y + 10.0;
    [menuController setTargetRect:CGRectMake(x, y, width, height) inView:self.superview];
    [menuController setMenuVisible:YES animated:YES];
}

- (void)copyClick{
    [[UIPasteboard generalPasteboard] setString:self.messageLabel.text];
}

- (void)didPressPlayAudioButton:(id)sender {
    
    if (self.delegate != nil) {
        
        id<DKDFileContent> content = (id<DKDFileContent>)[self.message content];
        
        DIMFileTransfer *ftp = [DIMFileTransfer sharedInstance];
        NSString *path = [ftp pathForContent:content];
        
        [self.delegate messageCell:self playAudio:path];
    }
}

@end
