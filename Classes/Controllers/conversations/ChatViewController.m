//
//  ChatViewController.m
//  Sechat
//
//  Created by Albert Moky on 2018/12/24.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "NSString+Extension.h"
#import "UIColor+Extension.h"
#import "UIStoryboardSegue+Extension.h"
#import "UIButton+Extension.h"
#import "UIImage+Extension.h"
#import "UIScrollView+Extension.h"
#import "UIViewController+Extension.h"

#import "DKDInstantMessage+Extension.h"
#import "DIMConstants.h"
#import "DIMGlobalVariable.h"
#import "DIMFileTransfer.h"

#import "WebViewController.h"
#import "ImagePickerController.h"
#import "MessageDatabase.h"
#import "Client.h"
#import "GuideCell.h"
#import "TimeCell.h"
#import "ReceiveMessageCell.h"
#import "SentMessageCell.h"
#import "CommandMessageCell.h"
#import "ProfileTableViewController.h"
#import "ChatManageTableViewController.h"
#import "ChatViewController.h"
#import "ZoomInViewController.h"
#import "LocalDatabaseManager.h"
#import "ChatVoiceView.h"
#import "EMAudioRecordHelper.h"
#import "EMAudioPlayerHelper.h"

@interface ChatViewController ()<UITextViewDelegate, UIDocumentPickerDelegate> {
    
    CATextLayer *_textViewPlaceholderLayer;
    UIButton *_addButton;
    UIButton *_submitButton;
    
    BOOL _scrolledToBottom;
    BOOL _adjustingTableViewFrame;
    
    NSMutableArray *_messageArray;
}

@property(nonatomic, strong) UIView *textViewContainer;
@property(nonatomic, readwrite) CGRect keyboardFrame;
@property(nonatomic, strong) UIView *textViewBg;
@property(nonatomic, strong) UITextView *textView;

@property(nonatomic, strong) UIButton *audioButton;
@property(nonatomic, strong) UIButton *recordButton;
@property(nonatomic, strong) UILongPressGestureRecognizer *longPressGuesture;
@property(nonatomic, strong) ChatVoiceView *voiceTipsView;

@end

@implementation ChatViewController

- (void)dealloc{
    
    self.messagesTableView.delegate = nil;
    self.messagesTableView.dataSource = nil;
    
    @try {
        [_textView removeObserver:self forKeyPath:@"contentSize"];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

-(void)loadView{
    
    [super loadView];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(didPressMoreButton:)];
    self.view.backgroundColor = [UIColor colorNamed:@"ViewBackgroundColor"];
    
    CGFloat x = 0.0;
    CGFloat y = 0.0;
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height - [self textViewContainerHeight];
    
    self.messagesTableView = [[UITableView alloc] initWithFrame:CGRectMake(x, y, width, height) style:UITableViewStylePlain];
    self.messagesTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.messagesTableView.delegate = self;
    self.messagesTableView.dataSource = self;
    self.messagesTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.messagesTableView registerClass:[SentMessageCell class] forCellReuseIdentifier:@"sentMsgCell"];
    [self.messagesTableView registerClass:[ReceiveMessageCell class] forCellReuseIdentifier:@"receivedMsgCell"];
    [self.messagesTableView registerClass:[CommandMessageCell class] forCellReuseIdentifier:@"commandMsgCell"];
    [self.messagesTableView registerClass:[TimeCell class] forCellReuseIdentifier:@"timeCell"];
    [self.messagesTableView registerClass:[GuideCell class] forCellReuseIdentifier:@"guideCell"];
    [self.view addSubview:self.messagesTableView];
    
    [self initInputContainer];
}

-(CGFloat)textViewContainerHeight{
    return 50.0;
}

-(void)initInputContainer{
    
    CGFloat textViewContainerHeight = [self textViewContainerHeight];
    _keyboardFrame = CGRectMake(0, CGRectGetHeight(self.view.bounds), 0, 0);
    
    _textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) - textViewContainerHeight, CGRectGetWidth(self.view.bounds), textViewContainerHeight)];
    _textViewContainer.backgroundColor = [UIColor colorNamed:@"InputBackgroundColor"];
    _textViewContainer.userInteractionEnabled = YES;
    [self.view addSubview:_textViewContainer];
    
    CGFloat width = 26.0;
    CGFloat height = textViewContainerHeight;
    CGFloat x = self.view.bounds.size.width - 10.0 - width;
    CGFloat y = (CGRectGetHeight(_textViewContainer.bounds) - height) / 2;
    
    _addButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
    _addButton.frame = CGRectMake(x, y, width, height);
    [_addButton addTarget:self action:@selector(addButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [_textViewContainer addSubview:_addButton];
    
    width = 28.0;
    height = 28.0;
    x = 10.0;
    y = (_textViewContainer.bounds.size.height - height) / 2;
    
    _audioButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_audioButton setImage:[[UIImage imageNamed:@"interphone"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _audioButton.frame = CGRectMake(x, y, width, height);
    [_audioButton setTintColor:[UIColor colorWithRed:0.0 green:0.478431 blue:1.0 alpha:1.0]];
    [_audioButton addTarget:self action:@selector(didPressAudioButton:) forControlEvents:UIControlEventTouchUpInside];
    [_textViewContainer addSubview:_audioButton];
    
    x = CGRectGetMaxX(_audioButton.frame) + 10.0;
    width = CGRectGetMinX(_addButton.frame) - x - 10.0;
    height = 36.0;
    y = (_textViewContainer.bounds.size.height - height) / 2;
    _textViewBg = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    _textViewBg.layer.cornerRadius = height / 2;
    _textViewBg.layer.masksToBounds = YES;
    _textViewBg.layer.borderColor = [UIColor colorWithHexString:@"cdcdcd"].CGColor;
    _textViewBg.layer.borderWidth = 0.5;
    [_textViewContainer addSubview:_textViewBg];
    
    x = CGRectGetMinX(_textViewBg.frame) + 10.0;
    width = _textViewBg.bounds.size.width - 20.0;
    _textView = [[UITextView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    _textView.returnKeyType = UIReturnKeySend;
    _textView.enablesReturnKeyAutomatically = YES;
    _textView.showsVerticalScrollIndicator = NO;
    _textView.autocorrectionType = UITextAutocorrectionTypeNo;
    _textView.backgroundColor = [UIColor clearColor];
    _textView.scrollsToTop = NO;
    _textView.font = [UIFont systemFontOfSize:17.0];
    _textView.delegate = self;
    [_textViewContainer addSubview:_textView];
    
    _textViewPlaceholderLayer = [[CATextLayer alloc] init];
    _textViewPlaceholderLayer.string = NSLocalizedString(@"", @"title");
    _textViewPlaceholderLayer.frame = CGRectMake(8, 8, 220, 20);
    _textViewPlaceholderLayer.fontSize = 14.0;
    _textViewPlaceholderLayer.foregroundColor = [[UIColor colorWithHexString:@"999999"] CGColor];
    _textViewPlaceholderLayer.contentsScale = [UIScreen mainScreen].scale;
    [_textView.layer addSublayer:_textViewPlaceholderLayer];
    
    [_textView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:NULL];
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, _textViewContainer.frame.size.width, 0.5)];
    line.backgroundColor = [UIColor colorNamed:@"SeperatorColor"];
    [_textViewContainer addSubview:line];
    
    _recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_recordButton setTitle:NSLocalizedString(@"Press and record", @"title") forState:UIControlStateNormal];
    _recordButton.frame = _textViewBg.frame;
    _recordButton.layer.cornerRadius = height / 2;
    _recordButton.layer.masksToBounds = YES;
    _recordButton.layer.borderColor = [UIColor colorWithHexString:@"cdcdcd"].CGColor;
    _recordButton.layer.borderWidth = 0.5;
    _recordButton.userInteractionEnabled = NO;
    
    self.longPressGuesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressHappen:)];
    //[self.contentView addGestureRecognizer:self.longPressGuesture];
    
//    [_recordButton addTarget:self action:@selector(voiceBegin:) forControlEvents:UIControlEventTouchDown];
//    [_recordButton addTarget:self action:@selector(voiceEnd:) forControlEvents:UIControlEventTouchUpInside];
//    [_recordButton addTarget:self action:@selector(voiceDragBack:) forControlEvents:UIControlEventTouchUpOutside];
    
    width = 180.0;
    height = 180.0;
    x = (self.view.bounds.size.width - width) / 2.0;
    y = (self.view.bounds.size.height - height) / 2.0;
    self.voiceTipsView = [[ChatVoiceView alloc] initWithFrame:CGRectMake(x, y, width, height)];
}

-(void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}

-(void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:animated];
    
    EMAudioPlayerHelper *player = [EMAudioPlayerHelper sharedHelper];
    if(player.isPlaying){
        [player stopPlayer];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = _conversation.title;
    _adjustingTableViewFrame = NO;
    _messageArray = [[NSMutableArray alloc] init];
    [self groupMessage];
    
    [self addKeyboardObserver];
    [self addDataObserver];
    
    _scrolledToBottom = NO;
    
    [self sendMetaToAudience];
}

- (void)sendMetaToAudience {
    
    //Send Meta to audience
    if (MKMIDIsUser(self.conversation.identifier)) {
        
        //Search whether has send message to this person
        NSUInteger i = 0;
        NSUInteger messageCount = [_conversation numberOfMessage];
        
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        
        BOOL hasSentMessage = NO;
        while(i < messageCount){
            
            id<DKDInstantMessage> iMsg = [_conversation messageAtIndex:i];
            id<MKMID> sender = iMsg.envelope.sender;
            
            if(sender == user.identifier){
                hasSentMessage = YES;
                break;
            }
            
            i++;
        }
        
        if(hasSentMessage == NO){
            
            //Send profile command to audience
            id<MKMID> ID = [user identifier];
            id<MKMVisa> visa = [DIMDocumentUtils lastVisa:[user documents]];
            id<DKDContent> content = DIMDocumentCommandResponse(ID, nil, @[visa]);
            id<MKMID> receiverID = _conversation.identifier;
            DIMSharedMessenger *messenger = [DIMGlobal messenger];
            [messenger sendContent:content
                            sender:ID
                          receiver:receiverID
                          priority:STDeparturePriorityNormal];
            
            NSLog(@"Send profile message to %@", receiverID);
        }
    }
}

-(void)addDataObserver{
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(onMessageSent:)
               name:kNotificationName_MessageSent object:nil];
    [nc addObserver:self selector:@selector(onSendMessageFailed:)
               name:kNotificationName_SendMessageFailed object:nil];
    
    [nc addObserver:self selector:@selector(onMessageInserted:)
               name:kNotificationName_MessageInserted object:nil];
    
    [nc addObserver:self selector:@selector(onGroupMembersUpdated:)
               name:kNotificationName_GroupMembersUpdated object:nil];
}

-(void)removeDataObserver{
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:kNotificationName_MessageSent object:nil];
    [nc removeObserver:self name:kNotificationName_SendMessageFailed object:nil];
    [nc removeObserver:self name:kNotificationName_MessageInserted object:nil];
    [nc removeObserver:self name:kNotificationName_GroupMembersUpdated object:nil];
}

-(void)addKeyboardObserver{
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:)
               name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:)
               name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillChangeFrame:)
               name:UIKeyboardWillChangeFrameNotification object:nil];
}

-(void)removeKeyboardObserver{
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [nc removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [nc removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

-(void)viewDidAppear:(BOOL)animated{
    
    [super viewDidAppear:animated];
    
    if (!_scrolledToBottom) {
        [self scrollToBottom:NO];
        _scrolledToBottom = YES;
    }
    
    [[MessageDatabase sharedInstance] markConversationMessageRead:self.conversation.identifier];
}

- (void)onMessageInserted:(NSNotification *)notification {
    NSString *name = notification.name;
    NSDictionary *info = notification.userInfo;
    
    if ([name isEqual:kNotificationName_MessageInserted]) {
        id<MKMID> ID = MKMIDParse([info objectForKey:@"Conversation"]);
        if ([_conversation.identifier isEqual:ID]) {
            [NSObject performBlockOnMainThread:^{
                [self groupMessage];
                [self scrollAfterInsertNewMessage];
                [[MessageDatabase sharedInstance] markConversationMessageRead:self.conversation.identifier];
            } waitUntilDone:NO];
        }
    }
}

- (void)onGroupMembersUpdated:(NSNotification *)notification {
    NSString *name = notification.name;
    NSDictionary *info = notification.userInfo;
    
    if ([name isEqual:kNotificationName_GroupMembersUpdated]) {
        id<MKMID> groupID = MKMIDParse([info objectForKey:@"group"]);
        if ([_conversation.identifier isEqual:groupID]) {
            [NSObject performBlockOnMainThread:^{
                self.navigationItem.title = self.conversation.title;
            } waitUntilDone:NO];
        }
    }
}

#pragma mark - kvo

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _textView && [keyPath isEqualToString:@"contentSize"]) {
        [self adjustTextViewFrameWhenContentSizeChanged];
    }
}

- (void)adjustTextViewFrameWhenContentSizeChanged {
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopAjustTableView) object:nil];
    _adjustingTableViewFrame = YES;
    
    CGFloat containerHeight = [self textViewContainerHeight];
    CGSize size = _textView.contentSize;
    size.height += 10;
    if (size.height < containerHeight) {
        size.height = containerHeight;
    }
    else if (size.height > 100) {
        size.height = 100;
    }
    CGRect rect = _textViewContainer.frame;
    rect.size.height = size.height;
    
    if (CGRectGetMinY(_keyboardFrame) < CGRectGetHeight(self.view.bounds)) {
        rect.origin.y = CGRectGetMinY(_keyboardFrame) - CGRectGetHeight(rect);
    }
    
    _textViewContainer.frame = rect;
    
    CGFloat height = rect.size.height - _textViewBg.frame.origin.y * 2;
    CGRect textViewBgRect = CGRectMake(_textViewBg.frame.origin.x, _textViewBg.frame.origin.y, _textViewBg.frame.size.width, height);
    CGRect textViewRect = CGRectMake(_textView.frame.origin.x, _textView.frame.origin.y, _textView.frame.size.width, height);
    
    CGRect tableViewRect = self.messagesTableView.frame;
    tableViewRect.size.height = CGRectGetMinY(rect);
    
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.messagesTableView.frame = tableViewRect;
        self.textViewContainer.frame = rect;
        self.textViewBg.frame = textViewBgRect;
        self.textView.frame = textViewRect;
        
    } completion:^(BOOL finished) {
        
        //NSLog(@"%.2f, %.2f", self.messagesTableView.contentOffset.x, self.messagesTableView.contentOffset.y);
        if (CGRectGetMinY(self.keyboardFrame) < CGRectGetHeight(self.view.bounds)) {
            [self scrollToBottom:YES];
        }
        
        [self performSelector:@selector(stopAjustTableView) withObject:nil afterDelay:0.5];
    }];
}

#pragma mark - UIKeyboard Notification
- (void)keyboardWillShow:(NSNotification *)o {
    [NSObject performBlockOnMainThread:^{
        [self adjustTextViewFrameWhenRecieveKeyboardNotification:o];
    } waitUntilDone:NO];
}

- (void)keyboardWillHide:(NSNotification *)o {
    [NSObject performBlockOnMainThread:^{
        [self adjustTextViewFrameWhenRecieveKeyboardNotification:o];
    } waitUntilDone:NO];
}

- (void)keyboardWillChangeFrame:(NSNotification *)o {
    [NSObject performBlockOnMainThread:^{
        [self adjustTextViewFrameWhenRecieveKeyboardNotification:o];
    } waitUntilDone:NO];
}

- (void)adjustTextViewFrameWhenRecieveKeyboardNotification:(NSNotification *)o {
    
    CGFloat duration = [[[o userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    UIViewAnimationOptions curve = [[[o userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    _keyboardFrame = [[[o userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardFrame = [self.view convertRect:_keyboardFrame fromView:self.view.window];
    [self adjustTextViewFrame:duration animationOptions:curve];
}

- (void)adjustTextViewFrame:(CGFloat)duration animationOptions:(UIViewAnimationOptions)options {
    
    NSLog(@"Adjust text view frame");
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopAjustTableView) object:nil];
    _adjustingTableViewFrame = YES;
    
    CGRect tableViewRect = self.messagesTableView.frame;
    CGRect textViewRect = _textViewContainer.frame;
    if (CGRectGetMinY(_keyboardFrame) >= CGRectGetHeight(self.view.bounds)) {
        textViewRect.origin.y = CGRectGetHeight(self.view.bounds) - _textViewContainer.frame.size.height;
        tableViewRect.size.height = CGRectGetHeight(self.view.bounds) - _textViewContainer.frame.size.height;
    } else {
        textViewRect.origin.y = CGRectGetMinY(_keyboardFrame) - CGRectGetHeight(textViewRect);
        tableViewRect.size.height = CGRectGetMinY(textViewRect);
    }
    
    if(!CGRectEqualToRect(_textViewContainer.frame, textViewRect)){
        
        [UIView animateWithDuration:duration delay:0 options:options animations:^{
            self.textViewContainer.frame = textViewRect;
            self.messagesTableView.frame = tableViewRect;
            
        } completion:^(BOOL finished) {
            
            if(finished){
                NSLog(@"%.2f, %.2f", self.messagesTableView.contentOffset.x, self.messagesTableView.contentOffset.y);
                if (CGRectGetMinY(self.keyboardFrame) < CGRectGetHeight(self.view.bounds)) {
                    [self scrollToBottom:YES];
                }
                
                [self performSelector:@selector(stopAjustTableView) withObject:nil afterDelay:0.5];
            }
        }];
    }
}

-(void)stopAjustTableView{
    _adjustingTableViewFrame = NO;
}

-(void)scrollToBottom:(BOOL)animated{
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopAjustTableView) object:nil];
    
    _adjustingTableViewFrame = YES;
    CGFloat offsetY = self.messagesTableView.contentSize.height - self.messagesTableView.bounds.size.height;
    
    if(offsetY <= -88.0){
        offsetY = -88.0;
    }
    
    NSLog(@"The scroll to bottom offset y is : %.2f", offsetY);
    [self.messagesTableView setContentOffset:CGPointMake(0.0, offsetY) animated:animated];
    
    [self performSelector:@selector(stopAjustTableView) withObject:nil afterDelay:1.0];
}

#pragma mark - scroll view delegate

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if(scrollView == self.messagesTableView && _adjustingTableViewFrame == NO && [_textView isFirstResponder]){
        [_textView resignFirstResponder];
    }
}

#pragma mark - UITextView delegate

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    
    if([text isEqualToString:@"\n"]){
        [self send];
        return NO;
    }
    
    return YES;
}

-(BOOL)textViewShouldBeginEditing:(UITextView *)textView{
    return YES;
}

-(BOOL)textViewShouldEndEditing:(UITextView *)textView{
    return YES;
}

-(void)send{
    
    NSString *text = _textView.text;
    if ([text length] == 0) {
        return;
    }

    DIMConversation *chatBox = _conversation;
    id<MKMID> receiver = chatBox.identifier;
    NSLog(@"send text: %@ -> %@", text, receiver);
    
    // create message content
    DIMContent *content = [[DIMTextContent alloc] initWithText:text];
    
    if (MKMIDIsGroup(receiver)) {
        content.group = receiver;
    }
    
    // pack message and send out
    DIMSharedMessenger *messenger = [DIMGlobal messenger];
    if (![messenger sendContent:content
                         sender:nil
                       receiver:receiver
                       priority:STDeparturePriorityNormal]) {
        NSLog(@"send content failed: %@ -> %@", content, receiver);
        NSString *message = NSLocalizedString(@"Failed to send this message.", nil);
        NSString *title = NSLocalizedString(@"Error!", nil);
        [self showMessage:message withTitle:title];
        return ;
    }
    
    content.state = DIMMessageState_Read;
    _textView.text = @"";
}

- (void)_showImagePickerController:(ImagePickerController *)ipc {
    // completion handler
    ImagePickerControllerCompletionHandler handler;
    handler = ^(UIImage * _Nullable image,
                NSString *path,
                NSDictionary<UIImagePickerControllerInfoKey,id> *info,
                UIImagePickerController *ipc) {
        
        NSLog(@"pick image: %@, path: %@", image, path);
        [self sendImage:image];
    };
    
    [ipc showWithViewController:self completionHandler:handler];
}

-(void)sendImage:(UIImage *)image{
    
    DIMConversation *chatBox = _conversation;
    id<MKMID> receiver = chatBox.identifier;
    
    // 1. build message content
    if (image) {
        CGSize maxSize = CGSizeMake(1024, 1024);
        CGSize imgSize = image.size;
        if (imgSize.width > maxSize.width || imgSize.height > maxSize.height) {
            NSLog(@"original data length: %lu", [image pngData].length);
            image = [image aspectFit:maxSize];
        }
        
        // image file
        NSData *data = [image jpegDataWithQuality:UIImage_JPEGCompressionQuality_Photo];
        
        // thumbnail
        UIImage *thumbnail = [image thumbnail];
        NSData *small = [thumbnail jpegDataWithQuality:UIImage_JPEGCompressionQuality_Thumbnail];
        NSLog(@"thumbnail data length: %lu < %lu, %lu", small.length, data.length, [image pngData].length);
        
        DIMEmitter *emitter = [DIMGlobal emitter];
        [emitter sendImage:data thumbnail:small receiver:receiver];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
    
    NSLog(@"The urls is %@", urls);
    
    if(urls.count == 0){
        return;
    }
    
    NSURL *url = [urls objectAtIndex:0];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:[url path]];
    [self sendImage:image];
}

- (void)camera:(id)sender {
    NSLog(@"open camera");
    CameraController *camera = [[CameraController alloc] init];
    [self _showImagePickerController:camera];
}

- (void)album:(id)sender {
    NSLog(@"open album");
    AlbumController *album = [[AlbumController alloc] init];
    [self _showImagePickerController:album];
}

- (void)onMessageSent:(NSNotification *)notification {
    NSString *name = notification.name;
    NSDictionary *info = notification.userInfo;
    id<DKDContent> content = DKDContentParse([info objectForKey:@"content"]);
    NSLog(@"%@: %@", name, content);
    // TODO: mark the message sent
}

- (void)onSendMessageFailed:(NSNotification *)notification {
    NSString *name = notification.name;
    NSDictionary *info = notification.userInfo;
    id<DKDContent> content = DKDContentParse([info objectForKey:@"content"]);
    NSError *error = [info objectForKey:@"error"];
    NSLog(@"%@: %@, error: %@", name, content, error);
    // TODO: mark the message failed for trying again
}

-(void)groupMessage{
    
    if (!_conversation) {
        NSAssert(false, @"conversation empty!");
        return;
    }
    
    [_messageArray removeAllObjects];
    
    DIMCommand *guide = [[DIMCommand alloc] initWithCmd:@"guide"];
    id<MKMID> admin = MKMIDParse(@"moky@4DnqXWdTV8wuZgfqSCX9GjE2kNq7HJrUgQ");
    id<DKDEnvelope> env = DKDEnvelopeCreate(admin, _conversation.identifier, nil);
    id<DKDInstantMessage> guideMessage = DKDInstantMessageCreate(env, guide);
    
    [_messageArray addObject:guideMessage];
    
    NSUInteger i = 0;
    NSUInteger messageCount = [_conversation numberOfMessage];
    NSTimeInterval currentTime = 0;
    
    while(i < messageCount){
        
        id<DKDInstantMessage> iMsg = [_conversation messageAtIndex:i];
        NSTimeInterval msgTime = [[iMsg objectForKey:@"time"] doubleValue];
        
        if(msgTime > currentTime + 15 * 60){
            [_messageArray addObject:[NSDate dateWithTimeIntervalSince1970:msgTime]];
            currentTime = msgTime;
        }
        
        [_messageArray addObject:iMsg];
        i++;
    }
}

- (NSInteger)messageCount {
    NSInteger count = [_messageArray count];
    return count;
}

- (id)messageAtIndex:(NSInteger)index {
    return [_messageArray objectAtIndex:index];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self messageCount];
}

- (NSString *)identifierForReusableCellAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = indexPath.row;
    
    id obj = [self messageAtIndex:row];
    
    NSString *identifier = @"receivedMsgCell";
    
    if([obj isKindOfClass:[NSDate class]]){
        identifier = @"timeCell";
    } else {
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
    
        id<DKDInstantMessage> iMsg = [self messageAtIndex:row];
        id<DKDContent> content = iMsg.content;
        id<MKMID> sender = iMsg.envelope.sender;
        
        NSString *type = [content type];
        if (type == DKDContentType_History || type == DKDContentType_Command) {
            if ([[(DIMCommand *)content cmd] isEqualToString:@"guide"]) {
                // show guide
                identifier = @"guideCell";
            } else {
                // command message
                identifier = @"commandMsgCell";
            }
        } else if ([sender isEqual:_conversation.identifier]) {
            // message from conversation target
            identifier = @"receivedMsgCell";
        } else if ([sender isEqual:user.identifier]) {
            // message from current user
            identifier = @"sentMsgCell";
        } else {
            NSArray *users = [facebook.archivist localUsers];
            for (user in users) {
                if ([user.identifier isEqual:sender]) {
                    // message from my account
                    identifier = @"sentMsgCell";
                }
            }
        }
    }
    return identifier;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *identifier = [self identifierForReusableCellAtIndexPath:indexPath];
    NSInteger row = indexPath.row;
    
    if ([identifier isEqualToString:@"guideCell"]) {
        GuideCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        cell.delegate = self;
        return cell;
    }
    
    if([identifier isEqualToString:@"timeCell"]){
        TimeCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        NSDate *d = [self messageAtIndex:row];
        [cell setTime:[d timeIntervalSince1970]];
        return cell;
    }
    
    id<DKDInstantMessage> iMsg = [self messageAtIndex:row];
    
    if([identifier isEqualToString:@"commandMsgCell"]){
        CommandMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        cell.msg = iMsg;
        cell.delegate = self;
        return cell;
    }
    
    if ([identifier isEqualToString:@"sentMsgCell"]) {
        SentMessageCell *cell  = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        cell.message = iMsg;
        cell.delegate = self;
        return cell;
    }
    
    if ([identifier isEqualToString:@"receivedMsgCell"]) {
        ReceiveMessageCell *cell  = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        cell.showName = YES;
        cell.message = iMsg;
        cell.delegate = self;
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *identifier = [self identifierForReusableCellAtIndexPath:indexPath];
    
    NSInteger row = indexPath.row;
    id<DKDInstantMessage> iMsg = [self messageAtIndex:row];
    CGRect bounds = tableView.bounds;
    
    CGFloat height = 0.0;
    if ([identifier isEqualToString:@"commandMsgCell"]) {
        CGSize size = [CommandMessageCell sizeWithMessage:iMsg bounds:bounds];
        height = size.height;
    } else if ([identifier isEqualToString:@"receivedMsgCell"]) {
        CGSize size = [ReceiveMessageCell sizeWithMessage:iMsg bounds:bounds showName:YES];
        height = size.height;
    } else if ([identifier isEqualToString:@"guideCell"]) {
        CGSize size = [GuideCell sizeWithMessage:iMsg bounds:bounds];
        height = size.height;
    } else if ([identifier isEqualToString:@"timeCell"]) {
        CGSize size = [TimeCell sizeWithMessage:iMsg bounds:bounds];
        height = size.height;
    } else {
        CGSize size = [SentMessageCell sizeWithMessage:iMsg bounds:bounds];
        height = size.height;
    }
    
    return height;
}

#pragma mark - Voice Actions

-(void)didLongPressHappen:(id)sender{
    
    NSLog(@"Long press state %zd", self.longPressGuesture.state);
    
    if(self.longPressGuesture.state == UIGestureRecognizerStateBegan){
        
        [self voiceBegin:nil];
        
    } else if(self.longPressGuesture.state == UIGestureRecognizerStateEnded || self.longPressGuesture.state == UIGestureRecognizerStateCancelled){
        [self voiceEnd:nil];
    }
}

-(void)didPressAudioButton:(id)sender{
    
    if(_recordButton.superview == nil){
        
        [_textView resignFirstResponder];
        [_textView removeFromSuperview];
        [_textViewBg removeFromSuperview];
        
        [_textViewContainer addSubview:_recordButton];
        [_textViewContainer addGestureRecognizer:self.longPressGuesture];
        
        UIImage *image = [[UIImage imageNamed:@"keyboard"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.audioButton setImage:image forState:UIControlStateNormal];
        
    } else {
        
        [_textViewContainer removeGestureRecognizer:self.longPressGuesture];
        [_recordButton removeFromSuperview];
        
        [_textViewContainer addSubview:_textViewBg];
        [_textViewContainer addSubview:_textView];
        
        UIImage *image = [[UIImage imageNamed:@"interphone"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.audioButton setImage:image forState:UIControlStateNormal];
    }
}

-(void)voiceBegin:(id)sender{
    
    [self.view addSubview:self.voiceTipsView];
    NSLog(@"Voice Begin");
    
    NSString *recordFilename = [[NSUUID UUID] UUIDString];
    NSString *documentPath = [[DIMStorage documentDirectory] stringByAppendingPathComponent:recordFilename];
    [[EMAudioRecordHelper sharedHelper] startRecordWithPath:documentPath completion:^(NSError * _Nonnull error) {
        
        if(error == nil){
            NSLog(@"Now start to record %@", documentPath);
        }else{
            NSLog(@"Recording can not start, error : %@", error);
        }
        
    }];
}

-(void)voiceEnd:(id)sender{
    
    NSLog(@"End to record");
    [self.voiceTipsView removeFromSuperview];
    
    id<MKMID> receiver = [_conversation identifier];
    
    [[EMAudioRecordHelper sharedHelper] stopRecordWithCompletion:^(NSString * _Nonnull aPath, NSInteger aTimeLength) {
        
        //Convert audio
        NSLog(@"Begin to convert audio file %@", aPath);
        NSString *mp4Filename = [[[NSUUID UUID] UUIDString] stringByAppendingString:@".mp4"];
        NSString *outputPath = [[DIMStorage documentDirectory] stringByAppendingPathComponent:mp4Filename];
        
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:aPath]];
        
        AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
        session.outputFileType = AVFileTypeMPEG4;
        session.metadata = asset.metadata;
        session.outputURL = [NSURL fileURLWithPath:outputPath];
        [session exportAsynchronouslyWithCompletionHandler:^{
            
            if(session.status == AVAssetExportSessionStatusCompleted){
                NSLog(@"AV Export success");
                NSData *data = [[NSData alloc] initWithContentsOfFile:outputPath];
                DIMEmitter *emitter = [DIMGlobal emitter];
                [emitter sendVoice:data
                          duration:CMTimeGetSeconds(asset.duration)
                          receiver:receiver];
            }
            
            if(session.status == AVAssetExportSessionStatusCancelled){
                NSLog(@"AV Export success");
            } else {
                NSLog(@"AV Export error %@", session.error);
            }
        }];
    }];
}

-(void)voiceDragBack:(id)sender{
    
    NSLog(@"Recording cancelled");
    [[EMAudioRecordHelper sharedHelper] cancelRecord];
}

#pragma mark - Navigation

-(void)addButtonAction:(id)sender{
    
    if([[UIDevice currentDevice].systemName hasPrefix:@"Mac"]){
        
        UIDocumentPickerViewController *picController = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeOpen];
        picController.delegate = self;
        [self presentViewController:picController animated:YES completion:nil];
        
    } else {
    
        UIAlertController *actionsheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Camera", @"title") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self camera:actionsheet];
        }];
        
        UIAlertAction *albumAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Album", @"title") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self album:actionsheet];
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"title") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        
        [albumAction setValue:[UIImage imageNamed:@"sharemore_pic"] forKey:@"image"];
        [cameraAction setValue:[UIImage imageNamed:@"sharemore_video"] forKey:@"image"];
        
        [actionsheet addAction:cameraAction];
        [actionsheet addAction:albumAction];
        [actionsheet addAction:cancelAction];
        
        if([[UIDevice currentDevice].model hasPrefix:@"iPhone"]){
            [self presentViewController:actionsheet animated:YES completion:nil];
        } else {
            UIPopoverPresentationController *popover = actionsheet.popoverPresentationController;

            if (popover) {

                popover.sourceView = _addButton;
                popover.sourceRect = _addButton.bounds;
                popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
            }
            
            [self presentViewController:actionsheet animated:YES completion:nil];
        }
    }
}

-(void)didPressMoreButton:(id)sender{
    
    ChatManageTableViewController *controller = [[ChatManageTableViewController alloc] init];
    controller.conversation = self.conversation;
    [self.navigationController pushViewController:controller animated:YES];
}

-(void)didPressAgreementButton:(id)sender{
    
    Client *client = [DIMGlobal terminal];
    
    WebViewController *web = [[WebViewController alloc] init];
    web.url = NSURLFromString([client termsAPI]);
    web.title = NSLocalizedString(@"Terms", nil);
    [self.navigationController pushViewController:web animated:YES];
}

-(void)scrollAfterInsertNewMessage {

    _adjustingTableViewFrame = YES;
    [self.messagesTableView reloadData];

    if (self.messagesTableView.contentOffset.y + self.messagesTableView.bounds.size.height > self.messagesTableView.contentSize.height - 100) {
        [NSObject performBlockOnMainThread:^{
            [self scrollToBottom:YES];
        } afterDelay:0.2];
    }
}

#pragma mark MessageCellDelegate

-(void)messageCell:(MessageCell *)cell showImage:(UIImage *)image{
    
    ZoomInViewController *controller = [[ZoomInViewController alloc] init];
    controller.image = image;
    [self.navigationController presentViewController:controller animated:YES completion:nil];
}

-(void)messageCell:(MessageCell *)cell openUrl:(NSURL *)url{
    
    WebViewController *web = [[WebViewController alloc] init];
    web.hidesBottomBarWhenPushed = YES;
    web.url = url;
    [self.navigationController pushViewController:web animated:YES];
}

-(void)messageCell:(MessageCell *)cell showProfile:(id<MKMID>)profile{
    
    ProfileTableViewController *vc = [[ProfileTableViewController alloc] init];
    vc.contact = profile;
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)messageCell:(MessageCell *)cell playAudio:(NSString *)audioPath{
    
    EMAudioPlayerHelper *player = [EMAudioPlayerHelper sharedHelper];
    
    if(!player.isPlaying){
    
        [[EMAudioPlayerHelper sharedHelper] startPlayerWithPath:audioPath model:self completion:^(NSError * _Nonnull error) {
            
            if(error == nil){
                NSLog(@"Audio Player play %@ successfully", audioPath);
            } else {
                NSLog(@"Audio Player play error %@", error);
            }
        }];
    } else {
        [player stopPlayer];
    }
}

@end
