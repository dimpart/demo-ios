//
//  SearchUsersTableViewController.m
//  Sechat
//
//  Created by Albert Moky on 2019/2/3.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "UIStoryboardSegue+Extension.h"
#import "UIViewController+Extension.h"

#import "DIMGlobalVariable.h"
#import "DIMSearchCommand.h"

#import "Client.h"
#import "ContactCell.h"
#import "SearchUsersTableViewController.h"
#import "ChatViewController.h"
#import "ProfileTableViewController.h"

extern NSString * const kNotificationName_OnlineUsersUpdated;
extern NSString * const kNotificationName_SearchUsersUpdated;

static inline BOOL search(NSString *keywords) {
    DIMSharedMessenger *messenger = [DIMGlobal messenger];
    id<DKDContent> content = [[DIMSearchCommand alloc] initWithKeywords:keywords];
    id<MKMID> bot = MKMIDParse(@"archivist@anywhere");
    return [messenger sendContent:content
                           sender:nil
                         receiver:bot
                         priority:STDeparturePriorityNormal];
}

@interface SearchUsersTableViewController ()<UITableViewDelegate, UITableViewDataSource> {
    
    NSMutableArray *_users;
    NSMutableArray *_onlineUsers;
}

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UISearchBar *searchBar;

@end

@implementation SearchUsersTableViewController

-(void)loadView{
    
    [super loadView];
    
    self.navigationItem.title = NSLocalizedString(@"Search User", @"title");
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [self.tableView registerClass:[ContactCell class] forCellReuseIdentifier:@"ContactCell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, 44.0)];
    self.searchBar.delegate = self;
    self.tableView.tableHeaderView = self.searchBar;
}

- (void)dealloc{

    self.tableView.delegate = nil;
    self.tableView.dataSource = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 2. waiting for update
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadData:)
               name:kNotificationName_OnlineUsersUpdated object:nil];
    [nc addObserver:self selector:@selector(reloadData:)
               name:kNotificationName_SearchUsersUpdated object:nil];
    
    // 3. query from the station
    search(DIMCommand_OnlineUsers);
}

- (void)viewWillDisappear:(BOOL)animated {
    
    Client *client = [DIMGlobal terminal];
    
    // 4. stop listening
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:kNotificationName_SearchUsersUpdated object:client];
    [nc removeObserver:self name:kNotificationName_OnlineUsersUpdated object:client];

    [super viewWillDisappear:animated];
}

- (void)reloadData:(NSNotification *)notification {
    
    NSArray *users = [notification.userInfo objectForKey:@"users"];
    
    id<MKMID> ID;
    id<MKMMeta> meta;
    
    if ([notification.name isEqual:kNotificationName_OnlineUsersUpdated]) {
        // online users
        NSLog(@"online users: %@", users);
        
        if (_onlineUsers) {
            [_onlineUsers removeAllObjects];
        } else {
            _onlineUsers = [[NSMutableArray alloc] initWithCapacity:users.count];
        }
        
        for (NSString *item in users) {
            ID = MKMIDParse(item);
            meta = DIMMetaForID(ID);
            if (meta) {
                [_onlineUsers addObject:ID];
            } else {
                // NOTICE: if meta for sender not found,
                //         the client will query it automatically
            }
        }
        
        //Sort
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
        [_onlineUsers sortUsingDescriptors:@[sortDescriptor]];
        
    } else if ([notification.name isEqual:kNotificationName_SearchUsersUpdated]) {
        // search users
        
        if (_users) {
            [_users removeAllObjects];
        } else {
            _users = [[NSMutableArray alloc] initWithCapacity:users.count];
        }
        
        for (NSString *item in users) {
            ID = MKMIDParse(item);
            if (MKMNetwork_IsStation(ID.type)) {
                // ignore
                //continue;
            }
            [_users addObject:ID];
        }
        
        //Sort
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
        [_users sortUsingDescriptors:@[sortDescriptor]];
        
        DIMFacebook *facebook = [DIMGlobal facebook];
        NSDictionary *results = [notification.userInfo objectForKey:@"results"];
        id value;
        for (id key in results) {
            ID = MKMIDParse(key);
            value = [results objectForKey:key];
            if ([value isKindOfClass:[NSDictionary class]]) {
                meta = MKMMetaParse(value);
                [facebook.archivist saveMeta:meta forID:ID];
            }
        }
    }
    
    [NSObject performBlockOnMainThread:^{
        [self.tableView reloadData];
    } waitUntilDone:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *keywords = searchBar.text;
    NSLog(@"****************** searching %@", keywords);
    
    search(keywords);
    
    [searchBar resignFirstResponder];
}

#pragma mark - Table delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (section == 0) {
        return _users.count;
    } else if (section == 1) {
        return _onlineUsers.count;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (section == 1) {
        if (_onlineUsers.count == 1) {
            return NSLocalizedString(@"Online User", nil);
        } else if (_onlineUsers.count > 1) {
            return NSLocalizedString(@"Online Users", nil);
        }
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell" forIndexPath:indexPath];
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    id<MKMID> ID = nil;
    if (section == 0) {
        // search users
        ID = [_users objectAtIndex:row];
    } else if (section == 1) {
        // online users
        ID = [_onlineUsers objectAtIndex:row];
    }
    cell.contact = ID;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - Navigation

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    ProfileTableViewController *controller = [[ProfileTableViewController alloc] init];
    controller.contact = selectedCell.contact;
    [self.navigationController pushViewController:controller animated:YES];
}

@end
