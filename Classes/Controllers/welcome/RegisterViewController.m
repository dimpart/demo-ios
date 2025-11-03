//
//  FirstAccountViewController.m
//  Sechat
//
//  Created by Albert Moky on 2019/4/9.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIColor+Extension.h"
#import "UIImage+Extension.h"
#import "UIView+Extension.h"
#import "UIImageView+Extension.h"
#import "UIViewController+Extension.h"

#import "DIMEntity+Extension.h"
#import "DIMProfile+Extension.h"
#import "DIMGlobalVariable.h"
#import "DIMFileTransfer.h"

#import "Facebook+Register.h"
#import "Facebook+Profile.h"
#import "Client.h"

#import "WebViewController.h"
#import "ImagePickerController.h"
#import "ImportAccountViewController.h"

#import "RegisterViewController.h"

@interface RegisterViewController ()<UITextFieldDelegate, UIDocumentPickerDelegate>

@property (strong, nonatomic) id<MKPrivateKey> SK;
@property (strong, nonatomic) id<MKMMeta> meta;
@property (strong, nonatomic) id<MKMID> ID;

@property (strong, nonatomic) UIButton *changeButton;
@property (strong, nonatomic) UILabel *avatarLabel;
@property (strong, nonatomic) UIImageView *avatarImageView;
@property (strong, nonatomic) UITextField *nicknameTextField;
@property (strong, nonatomic) UIButton *importButton;
@property (strong, nonatomic) NSData *imageData;

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) NSString *nickname;

@end

@implementation RegisterViewController

-(void)loadView{
    
    [super loadView];
    
    self.navigationItem.title = NSLocalizedString(@"Register", @"title");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", @"title") style:UIBarButtonItemStylePlain target:self action:@selector(didPressStartButton:)];
    self.view.backgroundColor = [UIColor colorNamed:@"ViewBackgroundColor"];
    
    CGFloat width = 120.0;
    CGFloat height = 120.0;
    CGFloat y = 128.0;
    
    if([UIScreen mainScreen].bounds.size.width == 320.0){
        y = 64.0;
        width = 80.0;
        height = 80.0;
    }
    
    CGFloat x = (self.view.bounds.size.width - width) / 2.0;
    
    self.avatarImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"default_avatar"]];
    self.avatarImageView.frame = CGRectMake(x, y, width, height);
    self.avatarImageView.backgroundColor = [UIColor lightGrayColor];
    self.avatarImageView.layer.cornerRadius = width / 2;
    self.avatarImageView.layer.masksToBounds = YES;
    [self.view addSubview:self.avatarImageView];
    
    height = 24.0;
    x = 0.0;
    y = self.avatarImageView.bounds.size.height - height;
    
    self.avatarLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
    self.avatarLabel.backgroundColor = [UIColor blackColor];
    self.avatarLabel.text = NSLocalizedString(@"Edit", @"title");
    self.avatarLabel.font = [UIFont systemFontOfSize:14.0];
    self.avatarLabel.textColor = [UIColor whiteColor];
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    [self.avatarImageView addSubview:self.avatarLabel];
    
    self.changeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.changeButton.frame = self.avatarImageView.frame;
    [self.changeButton addTarget:self action:@selector(changeAvatar:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.changeButton];
    
    y = self.avatarImageView.frame.origin.y + self.avatarImageView.frame.size.height + 20.0;
    x = 35.0;
    width = self.view.bounds.size.width - x * 2.0;
    height = 0.5;
    
    UIView *seperator = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    seperator.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:seperator];
    
    height = 44.0;
    width = 100.0;
    UILabel *nicknameLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
    nicknameLabel.text = NSLocalizedString(@"Nickname", @"title");
    [self.view addSubview:nicknameLabel];
    
    x = nicknameLabel.frame.origin.x + width + 10.0;
    width = seperator.frame.origin.x + seperator.frame.size.width - x;
    self.nicknameTextField = [[UITextField alloc] initWithFrame:CGRectMake(x, y, width, height)];
    self.nicknameTextField.placeholder = NSLocalizedString(@"e.g moky", @"title");
    self.nicknameTextField.delegate = self;
    self.nicknameTextField.returnKeyType = UIReturnKeyDone;
    [self.view addSubview:self.nicknameTextField];
    
    y = nicknameLabel.frame.origin.y + nicknameLabel.frame.size.height;
    x = 35.0;
    width = self.view.bounds.size.width - x * 2.0;
    height = 0.5;
    
    seperator = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    seperator.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:seperator];
    
    y = seperator.frame.origin.y;
    height = 44.0;
    self.importButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.importButton.frame = CGRectMake(x, y, width, height);
    [self.importButton setTitle:NSLocalizedString(@"Import Existing Account", @"title") forState:UIControlStateNormal];
    [self.importButton addTarget:self action:@selector(importAccount:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.importButton];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)viewDidAppear:(BOOL)animated{
    
    [super viewDidAppear:animated];
    [self.nicknameTextField becomeFirstResponder];
}

- (void)changeAvatar:(id)sender {
    
    if([[UIDevice currentDevice].systemName hasPrefix:@"Mac"]){
        
        UIDocumentPickerViewController *picController = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeOpen];
        picController.delegate = self;
        [self presentViewController:picController animated:YES completion:nil];
        
    } else {
        
        ImagePickerControllerCompletionHandler handler;
        handler = ^(UIImage * _Nullable image,
                    NSString *path,
                    NSDictionary<UIImagePickerControllerInfoKey,id> *info,
                    UIImagePickerController *ipc) {
            
            NSLog(@"pick image: %@, path: %@", image, path);
            if (image) {
                // image file
                image = [image aspectFit:CGSizeMake(320, 320)];
                NSData *data = [image jpegDataWithQuality:UIImage_JPEGCompressionQuality_Photo];
                self.imageData = data;
                self.avatarImageView.image = image;
            }
        };
        
        AlbumController *album = [[AlbumController alloc] init];
        album.allowsEditing = YES;
        [album showWithViewController:self completionHandler:handler];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
    
    NSLog(@"The urls is %@", urls);
    
    if(urls.count == 0){
        return;
    }
    
    NSURL *url = [urls objectAtIndex:0];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:[url path]];
    
    if(image.size.width > 320.0){
        image = [image aspectFit:CGSizeMake(320.0, 320.0)];
    }
    
    NSData *data = [image jpegDataWithQuality:UIImage_JPEGCompressionQuality_Photo];
    self.imageData = data;
    self.avatarImageView.image = image;
}

-(NSError *)saveAndSubmit {
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    id<MKMUser> user = facebook.currentUser;
    id<MKMID> ID = user.identifier;
    
    id<MKMVisa> visa = user.visa;
    
    if (self.imageData != nil) {
        
        NSString *filename = [MKHexEncode(MKMD5Digest(self.imageData)) stringByAppendingPathExtension:@"jpeg"];
        
        // save to local storage
        [facebook saveAvatar:self.imageData name:filename forID:ID];
        
        // upload to CDN
        DIMFileTransfer *ftp = [DIMFileTransfer sharedInstance];
        NSURL *url = [ftp uploadAvatar:self.imageData filename:filename sender:ID];
        
        // got avatar URL
        visa.avatar = MKPortableNetworkFileParse(NSStringFromURL(url));
    }
    
    [visa setName:self.nickname];
    
    id<MKMUserDataSource> dataSource = (id<MKMUserDataSource>)[user dataSource];
    id<MKSignKey> SK = [dataSource getPrivateKeyForVisaSignature:user.identifier];
    NSAssert(SK, @"failed to get visa sign key for user: %@", user.identifier);
    [visa sign:SK];
    
    [facebook.archivist saveDocument:visa];
    
    // submit to station
    DIMSharedMessenger *messenger = [DIMGlobal messenger];
    [messenger postDocument:visa withMeta:user.meta];
    
    return nil;
}

- (NSError *)generate {
    NSLog(@"refreshing...");
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    id<DIMAccountDBI> adb = [DIMGlobal adb];
    
    DIMRegister *reg = [[DIMRegister alloc] initWithDatabase:adb];
    id<MKMID> ID = [reg createUserWithName:self.nickname avatar:nil];
    
    id<MKSignKey> SK = [facebook getPrivateKeyForVisaSignature:ID];
    id<MKMUser> user = [facebook getUser:ID];
    facebook.currentUser = user;

    // 1. generated private key
    self.SK = (id<MKPrivateKey>)SK;
    if (self.SK == nil) {
        return [NSError errorWithDomain:@"chat.dim" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Can not generate private key"}];
    }

    // 2. generated meta
    self.meta = user.meta;
    if (self.meta == nil) {
        return [NSError errorWithDomain:@"chat.dim" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Can not generate meta"}];
    }

    // 3. generated ID
    self.ID = user.identifier;
    if (self.ID == nil) {
        return [NSError errorWithDomain:@"chat.dim" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Can not generate ID"}];
    }

//    BOOL saved = [facebook saveUserList:client.users withCurrentUser:user];
//    if (!saved) {
//        return [NSError errorWithDomain:@"chat.dim" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Can not save user to client"}];
//    }
    
    return nil;
}

-(void)didPressStartButton:(id)sender{
    
    NSString *nickname = self.nicknameTextField.text;
    
    if(nickname == nil || nickname.length == 0){
        NSString *message = @"Please Input your nickname";
        NSString *title = @"Dim!";
        [self showMessage:NSLocalizedString(message, nil)
                withTitle:NSLocalizedString(title, nil)];
        return;
    }
    
    self.nickname = nickname;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.activityIndicator];
    self.navigationController.navigationBar.userInteractionEnabled = NO;
    [self.activityIndicator startAnimating];
    
    [NSObject performBlockInBackground:^{
    
        NSError *error = [self generate];
        
        if (error != nil) {
            [self showError:error];
            [self restoreUI];
            return;
        }
        
        error = [self saveAndSubmit];
        if (error != nil) {
            [self showError:error];
            [self restoreUI];
            return;
        }
        
        Client *client = [DIMGlobal terminal];
        [client setPushAlias];
        
        [NSObject performBlockOnMainThread:^{
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } waitUntilDone:NO];
    }];
}

-(void)restoreUI{
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", @"title") style:UIBarButtonItemStylePlain target:self action:@selector(didPressStartButton:)];
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

-(void)importAccount:(id)sender{
    
    ImportAccountViewController *vc = [[ImportAccountViewController alloc] initWithNibName:@"ImportAccountViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    
    [self.nicknameTextField resignFirstResponder];
    
    return YES;
}

@end
