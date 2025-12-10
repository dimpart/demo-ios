//
//  ChatManageTableViewController.m
//  Sechat
//
//  Created by Albert Moky on 2019/3/2.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIViewController+Extension.h"
#import "UIStoryboard+Extension.h"
#import "UIStoryboardSegue+Extension.h"

#import "DIMConstants.h"
#import "DIMEntity+Extension.h"
#import "DIMGlobalVariable.h"

#import "Client.h"
#import "MessageDatabase.h"
#import "LocalDatabaseManager.h"

#import "WebViewController.h"
#import "SwitchCell.h"
#import "ProfileTableViewController.h"
#import "ParticipantCollectionCell.h"
#import "ParticipantsCollectionViewController.h"

#import "ChatManageTableViewController.h"

@interface ChatManageTableViewController ()<UITableViewDataSource, UITableViewDelegate, SwitchCellDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SwitchCell *muteCell;
@property (strong, nonatomic) ParticipantsCollectionViewController *participantsCollectionViewController;

@end

#define SECTION_COUNT     4

#define SECTION_MEMBERS   0
#define SECTION_PROFILES  1
#define SECTION_FUNCTIONS 2
#define SECTION_ACTIONS   3

@implementation ChatManageTableViewController

-(void)loadView{
    
    [super loadView];
    
    ParticipantsCollectionViewController *vc;
    vc = [UIStoryboard instantiateViewControllerWithIdentifier:@"participantsCollectionViewController" storyboardName:@"Conversations"];
    vc.conversation = _conversation;
    vc.manageViewController = self;
    _participantsCollectionViewController = vc;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"NormalCell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Profile"];
    [self.tableView registerClass:[SwitchCell class] forCellReuseIdentifier:@"SwitchCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"manage conversation: %@", _conversation.identifier);
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(onGroupMembersUpdated:)
               name:kNotificationName_GroupMembersUpdated object:nil];
}

- (void)onGroupMembersUpdated:(NSNotification *)notification {
    NSString *name = notification.name;
    NSDictionary *info = notification.userInfo;
    [NSObject performBlockOnMainThread:^{
        if ([name isEqual:kNotificationName_GroupMembersUpdated]) {
            id<MKMID> groupID = [info objectForKey:@"group"];
            if ([groupID isEqual:self->_conversation.identifier]) {
                // the same group
                [self->_participantsCollectionViewController reloadData];
                [self->_participantsCollectionViewController.collectionView reloadData];
                [self.tableView reloadData];
            } else {
                // dismiss the personal chat box
                [self dismissViewControllerAnimated:YES completion:^{
                    //
                }];
            }
        }
    } waitUntilDone:NO];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    if (section == SECTION_ACTIONS) {
        // other actions
        if (row == 0) {
            // Clear Chat History
            NSString *title = NSLocalizedString(@"Clear Chat History", nil);
            NSString *format = NSLocalizedString(@"Are you sure to clear all messages with %@ ?\nThis operation is unrecoverable!", nil);
            NSString *text = [NSString stringWithFormat:format, _conversation.name];
            
            void (^handler)(UIAlertAction *);
            handler = ^(UIAlertAction *action) {
                // clear message in conversation
                MessageDatabase *msgDB = [MessageDatabase sharedInstance];
                [msgDB clearConversation:self->_conversation.identifier];
                
                [self.navigationController popToRootViewControllerAnimated:YES];
            };
            [self showMessage:text withTitle:title cancelHandler:nil defaultHandler:handler];
        } else if (row == 1) {
            // Delete and Leave
            NSString *title = NSLocalizedString(@"Delete and Leave", nil);
            NSString *format = NSLocalizedString(@"Are you sure to leave group %@ ?\nThis operation is unrecoverable!", nil);
            NSString *text = [NSString stringWithFormat:format, _conversation.name];
            
            if (!MKMIDIsGroup(_conversation.identifier)) {
                NSAssert(false, @"current conversation is not a group chat: %@", _conversation.identifier);
                return ;
            }
            id<MKMGroup> group = DIMGroupWithID(_conversation.identifier);
            //DIMSharedFacebook *facebook = [DIMGlobal facebook];
            //id<MKMUser> user = [facebook currentUser];
            
            void (^handler)(UIAlertAction *);
            handler = ^(UIAlertAction *action) {
                // send quit group command
                DIMSharedGroupManager *manager = [DIMSharedGroupManager sharedInstance];
                [manager quitGroup:group.identifier];
                
                // clear message in conversation
                MessageDatabase *msgDB = [MessageDatabase sharedInstance];
                [msgDB removeConversation:self->_conversation.identifier];
                
                [self dismissViewControllerAnimated:YES completion:nil];
            };
            [self showMessage:text withTitle:title cancelHandler:nil defaultHandler:handler];
        }
    } else if(section == SECTION_FUNCTIONS){
        
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        
        NSString *sender = [[NSString alloc] initWithFormat:@"%@", user.identifier];
        NSString *identifier = [[NSString alloc] initWithFormat:@"%@", _conversation.identifier];
        NSString *type = @"individual";
        if (MKMIDIsGroup(_conversation.identifier)) {
            type = @"group";
        }

        Client *client = [DIMGlobal terminal];
        NSString *api = client.reportAPI;
        api = [api stringByReplacingOccurrencesOfString:@"{sender}" withString:sender];
        api = [api stringByReplacingOccurrencesOfString:@"{ID}" withString:identifier];
        api = [api stringByReplacingOccurrencesOfString:@"{type}" withString:type];
        NSLog(@"report to URL: %@", api);
        
        WebViewController *web = [[WebViewController alloc] init];
        web.url = NSURLFromString(api);
        [self.navigationController pushViewController:web animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger section = indexPath.section;
    
    if (section == SECTION_MEMBERS) {
        // member list
        UICollectionViewController *cvc = _participantsCollectionViewController;
        UICollectionViewLayout *cvl = cvc.collectionViewLayout;
        CGSize size = cvl.collectionViewContentSize;
        return size.height;
    }
    
    return 44.0;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SECTION_ACTIONS) {
        // other actions
        if (!MKMIDIsGroup(_conversation.identifier)) {
            return 1;
        }
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        DIMSharedGroupManager *manager = [DIMSharedGroupManager sharedInstance];
        if ([manager isOwner:user.identifier ofGroup:_conversation.identifier]) {
            return 1;
        }
    }
    
    if(section == SECTION_PROFILES){
        return 4;
    }
    
    if(section == SECTION_FUNCTIONS){
        return 2;
    }
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = nil;
    // Configure the cell...
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    if (section == SECTION_MEMBERS) {
        
        cell = [tableView dequeueReusableCellWithIdentifier:@"NormalCell" forIndexPath:indexPath];
        // member list
        UIView *view = _participantsCollectionViewController.view;
        UICollectionView *cView = _participantsCollectionViewController.collectionView;
        if (view.superview == nil) {
            cView.frame = cell.bounds;
            [cell addSubview:view];
        }
        
    } else if (section == SECTION_PROFILES) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"ProfileCell"];
        
        // profile
        NSString *key = nil;
        NSString *value = nil;
        switch (row) {
            case 0: { // Name
                if (MKMIDIsGroup(_conversation.identifier)) {
                    key = NSLocalizedString(@"Group name", nil);
                } else {
                    key = NSLocalizedString(@"Nickname", nil);
                }
                value = _conversation.name;
            }
                break;
                
            case 1: { // seed
                if (MKMIDIsGroup(_conversation.identifier)) {
                    key = NSLocalizedString(@"Seed", nil);
                } else {
                    key = NSLocalizedString(@"Username", nil);
                }
                value = _conversation.identifier.name;
            }
                break;
                
            case 2: { // address
                key = NSLocalizedString(@"Address", nil);
                value = (NSString *)_conversation.identifier.address;
            }
                break;
                
            default:
                break;
        }
        cell.textLabel.text = key;
        cell.detailTextLabel.text = value;
        
    } else if(section == SECTION_FUNCTIONS){
        
        if(row == 0){
            cell = [tableView dequeueReusableCellWithIdentifier:@"NormalCell" forIndexPath:indexPath];
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.textLabel.text = NSLocalizedString(@"Report", @"title");
        } else {
            
            DIMSharedFacebook *facebook = [DIMGlobal facebook];
            id<MKMUser> user = [facebook currentUser];
            
            SwitchCell *muteCell = [tableView dequeueReusableCellWithIdentifier:@"SwitchCell" forIndexPath:indexPath];
            muteCell.textLabel.textAlignment = NSTextAlignmentLeft;
            muteCell.textLabel.text = NSLocalizedString(@"Mute", @"title");
            muteCell.delegate = self;
            muteCell.switchOn = [[LocalDatabaseManager sharedInstance] isConversation:self.conversation.identifier
                                                                              forUser:user.identifier];
            cell = muteCell;
        }
        
    } else if(section == SECTION_ACTIONS){
        
        cell = [tableView dequeueReusableCellWithIdentifier:@"NormalCell" forIndexPath:indexPath];
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        if(row == 0){
            cell.textLabel.text = NSLocalizedString(@"Clear Chat History", @"title");
        }else{
            cell.textLabel.text = NSLocalizedString(@"Delete And Leave", @"title");
        }
    }
    
    return cell;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    NSLog(@"segue: %@", segue);
    
    if ([segue.identifier isEqualToString:@"reportSegue"]) {
        
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        
        NSString *sender = [[NSString alloc] initWithFormat:@"%@", user.identifier];
        NSString *identifier = [[NSString alloc] initWithFormat:@"%@", _conversation.identifier];
        NSString *type = @"individual";
        if (MKMIDIsGroup(_conversation.identifier)) {
            type = @"group";
        }
        Client *client = [DIMGlobal terminal];
        NSString *api = client.reportAPI;
        api = [api stringByReplacingOccurrencesOfString:@"{sender}" withString:sender];
        api = [api stringByReplacingOccurrencesOfString:@"{ID}" withString:identifier];
        api = [api stringByReplacingOccurrencesOfString:@"{type}" withString:type];
        NSLog(@"report to URL: %@", api);
        
        WebViewController *web = [segue visibleDestinationViewController];
        web.url = NSURLFromString(api);
        
    } else if ([segue.identifier isEqualToString:@"profileSegue"]) {
        
        ParticipantCollectionCell *cell = sender;
        id<MKMID> ID = cell.participant;
        
        ProfileTableViewController *vc = [segue visibleDestinationViewController];
        vc.contact = ID;
        
    }
}

- (void)switchCell:(SwitchCell *)cell didChangeValue:(BOOL)on{
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    id<MKMUser> user = [facebook currentUser];
    
    NSArray *currentList = [[LocalDatabaseManager sharedInstance] muteListForUser:user.identifier];
    NSMutableArray *newList = [[NSMutableArray alloc] initWithArray:currentList];
    
    if(on){
        if(![newList containsObject:self.conversation.identifier]){
            [newList addObject:self.conversation.identifier];
        }
        [[LocalDatabaseManager sharedInstance] muteConversation:self.conversation.identifier forUser:user.identifier];
    }else{
        [newList removeObject:self.conversation.identifier];
        [[LocalDatabaseManager sharedInstance] unmuteConversation:self.conversation.identifier forUser:user.identifier];
    }
    DIMSharedMessenger *messenger = [DIMGlobal messenger];
    
    DIMMuteCommand *content = [[DIMMuteCommand alloc] initWithList:newList];
    [messenger sendCommand:content priority:STDeparturePrioritySlower];
}

@end
