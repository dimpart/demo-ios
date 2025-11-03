//
//  AccountTableViewController.m
//  Sechat
//
//  Created by Albert Moky on 2018/12/23.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "UIStoryboardSegue+Extension.h"
#import "UIView+Extension.h"
#import "UIViewController+Extension.h"

#import "DIMEntity+Extension.h"
#import "DIMProfile+Extension.h"
#import "DIMConstants.h"
#import "DIMGlobalVariable.h"

#import "WebViewController.h"
#import "Facebook+Profile.h"
#import "Facebook+Register.h"
#import "AccountEditViewController.h"
#import "Client.h"
#import "ContactCell.h"
#import "AccountTableViewController.h"

@interface AccountTableViewController ()<UITableViewDelegate, UITableViewDataSource>{
    
    BOOL _inReview;
}

@property(nonatomic, strong) UITableView *tableView;

@end

@implementation AccountTableViewController

-(void)loadView{
    
    [super loadView];
    
    self.navigationItem.title = NSLocalizedString(@"Settings", @"title");
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    [self.tableView registerClass:[ContactCell class] forCellReuseIdentifier:@"ContactCell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"NormalCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

-(void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self reloadData];
    _inReview = [[NSUserDefaults standardUserDefaults] boolForKey:@"in_review"];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(didProfileUpdated:)
               name:kNotificationName_DocumentUpdated object:nil];
    [nc addObserver:self selector:@selector(onAvatarUpdated:)
               name:kNotificationName_AvatarUpdated object:nil];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

- (void)onAvatarUpdated:(NSNotification *)notification {
    
    id<MKMDocument> profile = [notification.userInfo objectForKey:@"profile"];
    id<MKMUser> user = [DIMGlobal facebook].currentUser;
    if ([profile.identifier isEqual:user.identifier]) {
        [self reloadData];
    }
}

-(void)didProfileUpdated:(NSNotification *)o{
    
    NSDictionary *userInfo = [o userInfo];
    id<MKMID> userID = [userInfo objectForKey:@"ID"];
    id<MKMUser> user = [DIMGlobal facebook].currentUser;
    
    if([userID isEqual:user.identifier]){
        [self reloadData];
    }
}

- (void)reloadData {
    [NSObject performBlockOnMainThread:^{
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        
        CGRect avatarFrame = self.avatarImageView.frame;
        DIMVisa *profile = (DIMVisa *)[user visa];
        UIImage *image = [profile avatarImageWithSize:avatarFrame.size];
        [self.avatarImageView setImage:image];
        self.nameLabel.text = DIMNameForID(user.identifier);
        self.descLabel.text = [user.identifier string];
        
        [self.tableView reloadData];
    } waitUntilDone:NO];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    if(_inReview){
        return 2;
    }
    
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if(_inReview){
        if (section == 1) {
            return 2;
        }
    }else{
        if (section == 2) {
            return 2;
        }
    }
    
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if(indexPath.section == 0){
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        ContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
        cell.contact = [facebook currentUser].identifier;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NormalCell"];
    
    if(_inReview){
        if(indexPath.section == 1){
            
            if(indexPath.row == 0){
                cell.textLabel.text = NSLocalizedString(@"Terms", @"title");
            }else if(indexPath.row == 1){
                cell.textLabel.text = NSLocalizedString(@"About", @"title");
            }
            
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        
        if(indexPath.section == 1){
            
            cell.textLabel.text = NSLocalizedString(@"Wallet", @"title");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
        } else{
            
            if(indexPath.row == 0){
                cell.textLabel.text = NSLocalizedString(@"Terms", @"title");
            }else if(indexPath.row == 1){
                cell.textLabel.text = NSLocalizedString(@"About", @"title");
            }
            
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if(indexPath.section == 0){
        return 64.0;
    }
    
    return 44.0;
}

#pragma mark - Navigation

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(indexPath.section == 0){
        
        AccountEditViewController *controller = [[AccountEditViewController alloc] init];
        controller.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:controller animated:YES];
        
    } else if(indexPath.section == 1){
        
        Client *client = [DIMGlobal terminal];
        WebViewController *web = [[WebViewController alloc] init];
        web.hidesBottomBarWhenPushed = YES;
        
        if(_inReview){
        
            if(indexPath.row == 0){
                
                web.url = NSURLFromString([client termsAPI]);
                web.title = NSLocalizedString(@"Terms", nil);
                
            } else if(indexPath.row == 1){
                
                web.url = NSURLFromString([client aboutAPI]);
                web.title = NSLocalizedString(@"About", nil);
            }
            
        } else {
            
            NSString *urlString = @"https://dim.candycandy.store";
            web.url = NSURLFromString(urlString);
            web.title = NSLocalizedString(@"DIM", nil);
        }
        
        [self.navigationController pushViewController:web animated:YES];
        
    } else if(indexPath.section == 2){
        
        Client *client = [DIMGlobal terminal];
        WebViewController *web = [[WebViewController alloc] init];
        web.hidesBottomBarWhenPushed = YES;
        
        if(indexPath.row == 0){
                
            web.url = NSURLFromString([client termsAPI]);
            web.title = NSLocalizedString(@"Terms", nil);
                
        } else if(indexPath.row == 1){
                
            web.url = NSURLFromString([client aboutAPI]);
            web.title = NSLocalizedString(@"About", nil);
        }
        
        [self.navigationController pushViewController:web animated:YES];
    }
}

@end
