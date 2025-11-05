//
//  ContactsTableViewController.m
//  Sechat
//
//  Created by Albert Moky on 2018/12/23.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "DIMConstants.h"
#import "DIMGlobalVariable.h"
#import "DIMAmanuensis.h"

#import "Client.h"
#import "ContactCell.h"
#import "ProfileTableViewController.h"
#import "SearchUsersTableViewController.h"
#import "ChatViewController.h"
#import "MessageDatabase.h"

#import "ContactsTableViewController.h"

@interface ContactsTableViewController ()<UITableViewDelegate, UITableViewDataSource> {
    
    NSMutableDictionary<NSString *, NSMutableArray<id<MKMID>> *> *_contactsTable;
    NSMutableArray *_contactsKey;
}

@property(nonatomic, strong) UITableView *tableView;

@end

@implementation ContactsTableViewController

-(void)loadView{
    
    [super loadView];
    
    self.navigationItem.title = NSLocalizedString(@"Contacts", @"title");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(didPressSearchButton:)];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [self.tableView registerClass:[ContactCell class] forCellReuseIdentifier:@"ContactCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)dealloc{

    self.tableView.delegate = nil;
    self.tableView.dataSource = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _contactsTable = nil;
    _contactsKey = nil;
    [self reloadData];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadData)
               name:kNotificationName_ContactsUpdated object:nil];
    [nc addObserver:self selector:@selector(onGroupMembersUpdated:)
               name:kNotificationName_GroupMembersUpdated object:nil];
}

-(void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
}

- (void)onGroupMembersUpdated:(NSNotification *)notification {
    NSString *name = notification.name;
    
    if ([name isEqual:kNotificationName_GroupMembersUpdated]) {
        
        NSDictionary *userInfo = notification.userInfo;
        id<MKMID> groupID = [userInfo objectForKey:@"group"];
        
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        NSArray<id<MKMID>> *contacts = user.contacts;
        
        if(![contacts containsObject:groupID]){
            
            [facebook addContact:groupID user:user.identifier];
            
            //Post contacts to server
            NSArray<id<MKMID>> *allContacts = [facebook contacts:user.identifier];
            
            DIMSharedMessenger *messenger = [DIMGlobal messenger];
            [messenger postContacts:allContacts];
            
            [NSObject performBlockOnMainThread:^{
                [self reloadData];
            } waitUntilDone:NO];
        }
    }
}

- (void)reloadData {
    _contactsTable = [[NSMutableDictionary alloc] init];
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    id<MKMUser> user = [facebook currentUser];
    NSArray<id<MKMID>> *contacts = user.contacts;
    NSInteger count = [contacts count];
    
    NSMutableArray<id<MKMID>> *mArray;
    id<MKMID> contact;
    id<MKMDocument> profile;
    NSString *name;
    while (--count >= 0) {
        contact = [contacts objectAtIndex:count];
        profile = DIMDocumentForID(contact, @"*");
        name = profile.name;
        if (name.length == 0) {
            name = contact.name;
            if (name.length == 0) {
                name = @"Đ"; // BTC Address: ฿
            }
        }
        name = [name substringToIndex:1];
        mArray = [_contactsTable objectForKey:name];
        if (!mArray) {
            mArray = [[NSMutableArray alloc] init];
            [_contactsTable setObject:mArray forKey:name];
        }
        [mArray addObject:contact];
        
        if (MKMIDIsGroup(contact)){
            NSArray *members = [facebook members:contact];
            
            if(members.count == 0){
                NSArray *assistant = [facebook assistants:contact];
                DIMSharedMessenger *messenger = [DIMGlobal messenger];
                [messenger queryGroupForID:contact fromMembers:assistant];
            }
        }
    }
    _contactsKey = [[_contactsTable allKeys] mutableCopy];
    
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSComparator cmp = ^NSComparisonResult(NSString *obj1, NSString *obj2) {
        const char *s1 = [obj1 cStringUsingEncoding:enc];
        const char *s2 = [obj2 cStringUsingEncoding:enc];
        return strcmp(s1, s2);
    };
    [_contactsKey sortUsingComparator:cmp];
    
    [NSObject performBlockOnMainThread:^{
        [self.tableView reloadData];
    } waitUntilDone:NO];
}

#pragma mark - Table delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return _contactsKey.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSString *key = [_contactsKey objectAtIndex:section];
    NSArray *contacts = [_contactsTable objectForKey:key];
    return contacts.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    NSString *key = [_contactsKey objectAtIndex:section];
    return key;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    // Configure the cell...
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSString *key = [_contactsKey objectAtIndex:section];
    NSArray *list = [_contactsTable objectForKey:key];
    id<MKMID> ID = [list objectAtIndex:row];
    
    ContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.contact = ID;
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView beginUpdates];
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        NSInteger section = indexPath.section;
        NSInteger row = indexPath.row;
        
        NSString *key = [_contactsKey objectAtIndex:section];
        NSMutableArray *list = [_contactsTable objectForKey:key];
        id<MKMID> ID = [list objectAtIndex:row];
        
        DIMSharedFacebook *facebook = [DIMGlobal facebook];
        id<MKMUser> user = [facebook currentUser];
        [facebook removeContact:ID user:user.identifier];
        
        //Post contacts to server
        NSArray<id<MKMID>> *allContacts = [facebook contacts:user.identifier];
        
        DIMSharedMessenger *messenger = [DIMGlobal messenger];
        [messenger postContacts:allContacts];
        
        [list removeObjectAtIndex:row];
        if (list.count == 0) {
            [_contactsKey removeObject:key];
            [_contactsTable removeObjectForKey:key];
            
            [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                     withRowAnimation:UITableViewRowAnimationFade];
        }
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
    
    [tableView endUpdates];
}

#pragma mark - Navigation

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    id<MKMID> contact = selectedCell.contact;
    
    if (MKMEntityTypeIsGroup(contact.type)) {
        
        DIMConversation *convers = DIMConversationWithID(contact);
        ChatViewController *vc = [[ChatViewController alloc] init];
        vc.conversation = convers;
        vc.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:vc animated:YES];
        
    } else {
    
        ProfileTableViewController *controller = [[ProfileTableViewController alloc] init];
        controller.contact = contact;
        controller.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:controller animated:YES];
    }
}

-(void)didPressSearchButton:(id)sender{
    
    SearchUsersTableViewController *controller = [[SearchUsersTableViewController alloc] init];
    controller.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:controller animated:YES];
}

@end
