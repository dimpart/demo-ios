//
//  ImportAccountViewController.m
//  Sechat
//
//  Created by moonfunjohn on 2019/6/25.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIViewController+Extension.h"

#import "DIMGlobalVariable.h"

#import "Facebook+Register.h"
#import "Client.h"

#import "ImportAccountViewController.h"

@interface ImportAccountViewController ()
@property (strong, nonatomic) IBOutlet UITextView *accountTextView;
@end

@implementation ImportAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.navigationItem.title = NSLocalizedString(@"Import Account", @"title");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", @"title") style:UIBarButtonItemStylePlain target:self action:@selector(didPressSaveButton:)];
    self.view.backgroundColor = [UIColor colorNamed:@"ViewBackgroundColor"];
    
    [self.accountTextView becomeFirstResponder];
}

- (void)didPressSaveButton:(id)sender {
    
    NSString *jsonString = self.accountTextView.text;

    if (jsonString == nil || jsonString.length == 0) {
        [self showMessage:NSLocalizedString(@"Please input your account info", nil)
                withTitle:NSLocalizedString(@"Error!", nil)];
        return;
    }

    Class nativeJsonParser = NSClassFromString(@"NSJSONSerialization");
    NSError *error;
    NSMutableDictionary *returnValue = [NSMutableDictionary dictionaryWithDictionary: [nativeJsonParser JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error]];
    
    if (error != nil) {
    
        NSString *privateKey = self.accountTextView.text;
        returnValue = [[NSMutableDictionary alloc] init];
        [returnValue setObject:privateKey forKey:@"data"];
        [returnValue setObject:@"RSA" forKey:@"algorithm"];
    }

    NSString *username = @"dim";
    NSString *version = MKMMetaType_Default;
    
    if ([returnValue objectForKey:@"version"] != nil) {
        version = [returnValue objectForKey:@"version"];
    }
    
    // 1. generate private key
    id<MKPrivateKey> SK = MKPrivateKeyParse(returnValue);
    // 2. generate meta
    id<MKMMeta> meta = MKMMetaGenerate(version, SK, username);
    // 3. generate ID
    id<MKMID> ID = MKMIDGenerate(meta, MKMNetwork_Main, nil);

    Client *client = [DIMGlobal terminal];
    if (![client importUser:ID meta:meta privateKey:SK]) {

        [self showMessage:NSLocalizedString(@"Failed to import user.", nil)
                withTitle:NSLocalizedString(@"Error!", nil)];
    } else {
        
        //Get contacts from server
        DIMSharedMessenger *messenger = [DIMGlobal messenger];
        [messenger queryContacts];
        
        [client setPushAlias];
        
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
