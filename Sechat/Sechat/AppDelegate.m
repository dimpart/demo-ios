//
//  AppDelegate.m
//  Sechat
//
//  Created by Albert Moky on 2018/12/21.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "UIColor+Extension.h"

#import "DIMGlobalVariable.h"
#import "DIMConstants.h"

#import "Client.h"
#import "ConversationsTableViewController.h"
#import "ContactsTableViewController.h"
#import "AccountTableViewController.h"
#import "WelcomeViewController.h"
#import "LocalDatabaseManager.h"
//#import "JPUSHService.h"

#import "AppDelegate.h"

@interface AppDelegate ()<UITabBarControllerDelegate/*, JPUSHRegisterDelegate*/>

@property(nonatomic, strong) UITabBarController *tabbarController;
@property(nonatomic, strong) ConversationsTableViewController *conversationController;
@property(nonatomic, strong) ContactsTableViewController *contactController;
@property(nonatomic, strong) AccountTableViewController *accountController;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // load plugins
    [DIMGlobalVariable sharedInstance];
//    [DIMRegister prepare];
//    [DIMFacebook loadPlugins];
//    [DIMMessageProcessor loadPlugins];
    
    // GSP station
    NSString *path = [[NSBundle mainBundle] pathForResource:@"gsp" ofType:@"plist"];
    NSMutableDictionary *mDict = [launchOptions mutableCopy];
    if (!mDict) {
        mDict = [[NSMutableDictionary alloc] init];
    }
    [mDict setObject:path forKey:@"ConfigFilePath"];
    
    [[DIMGlobal terminal] didFinishLaunchingWithOptions:mDict];

//    [self addDefaultUser:@"baloo@4LA5FNbpxP38UresZVpfWroC2GVomDDZ7q"];
//    [self addDefaultUser:@"dim@4TM96qQmGx1UuGtwkdyJAXbZVXufFeT1Xf"];
    
    [[LocalDatabaseManager sharedInstance] createTables];
    [self convertOldTables];
    
    [self setAppApearence];
    self.tabbarController = [self createTabBarController];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = self.tabbarController;
    [self.window makeKeyAndVisible];
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    id<MKMUser> user = [facebook currentUser];
    if (!user) {
        WelcomeViewController *vc = [[WelcomeViewController alloc] init];
        UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
        nc.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.tabbarController presentViewController:nc animated:NO completion:nil];
//    } else {
//        DIMSharedMessenger *messenger = [DIMGlobal messenger];
//        [messenger queryMuteList];
    }
    
    [self updateBadge:nil];
    [self addObservers];
    
    [self getReviewStatus];
    
//    JPUSHRegisterEntity *entity = [[JPUSHRegisterEntity alloc] init];
//    entity.types = JPAuthorizationOptionAlert|JPAuthorizationOptionBadge|JPAuthorizationOptionSound;
//    [JPUSHService registerForRemoteNotificationConfig:entity delegate:self];
//
//    NSString *appKey = @"db6d7573a1643e36cf2451c6";
//    NSString *channel = @"App Store";
//    NSInteger isProduction = 0;
//    NSString *advertisingId = nil;
//
//    [JPUSHService setupWithOption:launchOptions appKey:appKey
//                  channel:channel
//         apsForProduction:isProduction
//    advertisingIdentifier:advertisingId];

    return YES;
}

-(void)getReviewStatus{
    [NSObject performBlockInBackground:^{
        
        NSError *error;
        NSString *url = [NSString stringWithFormat:@"http://itunes.apple.com/lookup?id=1481849344"];
        NSString *responseString = [NSString stringWithContentsOfURL:[NSURL URLWithString:url] encoding:NSUTF8StringEncoding error:&error];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"in_review"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        @try {
            NSDictionary *dic = MKJsonDecode(responseString);
            
            if (dic != nil && [dic isKindOfClass:[NSDictionary class]]) {
                
                //DBG(@"The return dic is : %@", dic);
                
                NSString *appStoreVersion = dic[@"results"][0][@"version"];
                NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

                if ([currentVersion compare:appStoreVersion] != NSOrderedDescending) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"in_review"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }
        } @catch(NSException *e) {

        }
    }];
}

-(void)addObservers{
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(updateBadge:)
               name:kNotificationName_ConversationUpdated object:nil];
}

- (void)updateBadge:(NSNotification *)o {
    [NSObject performBlockOnMainThread:^{
        
        NSInteger unreadCount = [[LocalDatabaseManager sharedInstance] getUnreadMessageCount:nil];
        
        NSString *badgeValue = nil;
        if(unreadCount > 0 && unreadCount <= 99){
            badgeValue = [NSString stringWithFormat:@"%zd", unreadCount];
        }else if(unreadCount > 99){
            badgeValue = @"99+";
        }
        
        UITabBarItem *tabBarItem = self.tabbarController.tabBar.items[0];
        tabBarItem.badgeValue = badgeValue;
        
        [UIApplication sharedApplication].applicationIconBadgeNumber = unreadCount;
        
    } waitUntilDone:NO];
}

-(void)setAppApearence{
    
    UIColor *tintColor = [UIColor colorWithHexString:@"0a81ff"];
    
    [[UIButton appearance] setTitleColor:tintColor forState:UIControlStateNormal];
    [[UIActivityIndicatorView appearance] setColor:tintColor];
}

-(void)addDefaultUser:(NSString *)address{
    
    DIMFacebook *facebook = [DIMGlobal facebook];
    id<MKMID> ID = MKMIDParse(address);
    
    NSString *metaPath = [NSString stringWithFormat:@"%@/meta", address];
    NSString *path = [[NSBundle mainBundle] pathForResource:metaPath ofType:@"plist"];
    
    NSDictionary *metaData = [[NSDictionary alloc] initWithContentsOfFile:path];
    id<MKMMeta> meta = MKMMetaParse(metaData);
    if (meta) {
        [facebook.archivist saveMeta:meta forID:ID];
    }
    
    NSString *profilePath = [NSString stringWithFormat:@"%@/profile", address];
    path = [[NSBundle mainBundle] pathForResource:profilePath ofType:@"plist"];
    
    NSDictionary *profileData = [[NSDictionary alloc] initWithContentsOfFile:path];
    id<MKMDocument> profile = MKMDocumentParse(profileData);
    if (profile) {
        [facebook.archivist saveDocument:profile forID:ID];
    }
}

- (UITabBarController *)createTabBarController {
    
    self.conversationController = [[ConversationsTableViewController alloc] init];
    self.contactController = [[ContactsTableViewController alloc] init];
    self.accountController = [[AccountTableViewController alloc] init];
    
    UINavigationController *conversationNavigationController = [[UINavigationController alloc] initWithRootViewController:self.conversationController];
    conversationNavigationController.navigationBar.prefersLargeTitles = YES;
    UINavigationController *contactNavigationController = [[UINavigationController alloc] initWithRootViewController:self.contactController];
    contactNavigationController.navigationBar.prefersLargeTitles = YES;
    UINavigationController *accountNavigationController = [[UINavigationController alloc] initWithRootViewController:self.accountController];
    accountNavigationController.navigationBar.prefersLargeTitles = YES;
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.delegate = self;
    tabBarController.viewControllers = @[conversationNavigationController, contactNavigationController, accountNavigationController];
    
    UITabBarItem *tabBarItem = tabBarController.tabBar.items[0];
    tabBarItem.title = NSLocalizedString(@"Chats", @"title");
    tabBarItem.image = [UIImage imageNamed:@"tabbar_chat"];
    
    tabBarItem = tabBarController.tabBar.items[1];
    tabBarItem.title = NSLocalizedString(@"Contacts", @"title");
    tabBarItem.image = [UIImage imageNamed:@"tabbar_contact"];
    
    tabBarItem = tabBarController.tabBar.items[2];
    tabBarItem.title = NSLocalizedString(@"Settings", @"title");
    tabBarItem.image = [UIImage imageNamed:@"tabbar_setting"];
    
    return tabBarController;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [[DIMGlobal terminal] didEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    
    [[DIMGlobal terminal] willEnterForeground];
    [self updateBadge:nil];
    [self addObservers];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    [[DIMGlobal terminal] willTerminate];
}

#pragma mark - APNs

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // APNs register success
//    [JPUSHService registerDeviceToken:deviceToken];
    
    Client *client = [DIMGlobal terminal];
    [client setPushAlias];
    
    //[[DIMGlobal terminal] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    // APNs register failed
    //[[DIMGlobal terminal] didFailToRegisterForRemoteNotificationsWithError:error];
}

#pragma mark- JPUSHRegisterDelegate

// iOS 12 Support
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification{
  if (notification && [notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
    //从通知界面直接进入应用
  }else{
    //从通知设置界面进入应用
  }
}

// iOS 10 Support
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger))completionHandler {
  // Required
//  NSDictionary * userInfo = notification.request.content.userInfo;
//  if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
//    [JPUSHService handleRemoteNotification:userInfo];
//  }
  completionHandler(UNNotificationPresentationOptionAlert); // 需要执行这个方法，选择是否提醒用户，有 Badge、Sound、Alert 三种类型可以选择设置
}

// iOS 10 Support
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
  // Required
//  NSDictionary * userInfo = response.notification.request.content.userInfo;
//  if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
//    [JPUSHService handleRemoteNotification:userInfo];
//  }
  completionHandler();  // 系统要求执行这个方法
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

  // Required, iOS 7 Support
//  [JPUSHService handleRemoteNotification:userInfo];
  completionHandler(UIBackgroundFetchResultNewData);
}

//- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
//    // APNs receive notification
//    [[DIMGlobal terminal] didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
//}

#pragma mark - Convert old tables

static id<MKMID> DIMIDWithAddress(id<MKMAddress> address) {
    id<MKMID> ID = [[MKMID alloc] initWithString:address.string
                                        name:nil
                                     address:address
                                    terminal:nil];
    id<MKMMeta> meta = DIMMetaForID(ID);
    if (!meta) {
        // failed to get meta for this ID
        return nil;
    }
    NSString *seed = [meta seed];
    if ([seed length] == 0) {
        return ID;
    }
    return MKMIDCreate(seed, address, nil);
}

-(void)convertOldTables{
    
    LocalDatabaseManager *sqliteManager = [LocalDatabaseManager sharedInstance];
    
    NSString *dir = [DIMStorage documentDirectory];
    dir = [dir stringByAppendingPathComponent:@".dim"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *de = [fm enumeratorAtPath:dir];
        
    id<MKMID> ID;
    id<MKMAddress> address;
    NSString *string;

    NSString *path;
    
    while (path = [de nextObject]) {
        if (![path hasSuffix:@"/messages.plist"]) {
            continue;
        }
        
        string = [path substringToIndex:(path.length - 15)];
        address = MKMAddressParse(string);
            
        ID = DIMIDWithAddress(address);
        NSString *plistPath = [NSString stringWithFormat:@"%@/%@", dir, path];
        
        if (ID) {
            
            [sqliteManager insertConversation:ID];
            
            //Get All Conversation Messages
            NSArray *array = [NSArray arrayWithContentsOfFile:plistPath];
            if (!array) {
                NSLog(@"messages not found: %@", plistPath);
                continue;
            }
            
            NSLog(@"messages from %@", plistPath);
            for (id item in array) {
                id<DKDInstantMessage> msg = DKDInstantMessageParse(item);
                if (!msg) {
                    NSAssert(false, @"message invalid: %@", item);
                    continue;
                }
                
                [sqliteManager addMessage:msg toConversation:ID];
            }
            
            NSError *error;
            [fm removeItemAtPath:plistPath error:&error];
            
        } else {
            NSLog(@"failed to load message in path: %@", plistPath);
        }
    }
    
    NSLog(@"Convert Finish");
}

@end
