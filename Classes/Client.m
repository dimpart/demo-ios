//
//  Client.m
//  DIMP
//
//  Created by Albert Moky on 2019/1/28.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import "DIMConstants.h"
#import "DIMGlobalVariable.h"
#import "DIMFileTransfer.h"
#import "DIMSharedFacebook.h"

#import "Facebook+Profile.h"
#import "Facebook+Register.h"
#import "MessageDatabase.h"
//#import "JPUSHService.h"
#import "Client.h"

@interface Client () {
    
    NSString *_userAgent;
}

@end

@implementation Client

- (NSString *)displayName {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *name = [info valueForKey:@"CFBundleDisplayName"];
    if (name) {
        return name;
    }
    return @"DIM!";
}

- (NSString *)userAgent {
    if (!_userAgent) {
        // device model & system
        UIDevice *device = [UIDevice currentDevice];
        NSString *model = device.model;          // e.g. @"iPhone", @"iPod touch"
        NSString *sysName = device.systemName;   // e.g. @"iOS"
        NSString *sysVer = device.systemVersion; // e.g. @"4.0"
        
        // current language
        NSString *lang = self.language;
        
        NSString *format = @"DIMP/1.0 (%@; U; %@ %@; %@) DIMCoreKit/1.0 (Terminal, like WeChat) DIM-by-GSP/1.0.1";
        _userAgent = [[NSString alloc] initWithFormat:format, model, sysName, sysVer, lang];
        NSLog(@"User-Agent: %@", _userAgent);
    }
    return _userAgent;
}

//#pragma mark DIMStationDelegate
//
//- (void)station:(DIMStation *)server onHandshakeAccepted:(NSString *)session {
//    [super station:server onHandshakeAccepted:session];
//    
//    // post device token
//    NSString *token = MKMHexEncode(self.deviceToken);
//    if (token) {
//        DIMCommand *content = [[DIMCommand alloc] initWithCmd:@"broadcast"];
//        [content setObject:@"apns" forKey:@"title"];
//        [content setObject:token forKey:@"device_token"];
//        
//        DIMMessenger *messenger = [DIMMessenger sharedInstance];
//        [messenger sendCommand:content];
//    }
//}

#pragma mark FSM

// Override
- (void)machine:(DIMSessionStateMachine *)ctx exitState:(id<SMState>)previous
           time:(NSTimeInterval)now {
    DIMSessionState *current = [ctx currentState];
    NSLog(@"session state changed: %@ => %@", previous, current);
    NSUInteger index = [current index];
    NSDictionary *info = @{
        @"stateIndex": @(index),
    };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kNotificationName_ServerStateChanged
                      object:self
                    userInfo:info];

    [super machine:ctx exitState:previous time:now];
}

@end

@implementation Client (AppDelegate)

- (void)_startServer:(NSDictionary *)station withProvider:(DIMServiceProvider *)sp {
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    
    // save meta for server ID
    id<MKMID> ID = MKMIDParse([station objectForKey:@"did"]);
    id<MKMMeta> meta = MKMMetaParse([station objectForKey:@"meta"]);
    
    if (meta) {
        [facebook.archivist saveMeta:meta forID:ID];
    }
    
    // prepare for launch star
    NSMutableDictionary *serverOptions = [[NSMutableDictionary alloc] init];
    NSString *IP = [station objectForKey:@"host"];
    if (IP) {
        //[launchOptions setObject:IP forKey:@"LongLinkAddress"];
        [serverOptions setObject:@"dim.chat" forKey:@"LongLinkAddress"];
        NSDictionary *ipTable = @{
                                  @"dim.chat": @[IP],
                                  };
        [serverOptions setObject:ipTable forKey:@"NewDNS"];
    }
    NSNumber *port = [station objectForKey:@"port"];
    if (port != nil) {
        [serverOptions setObject:port forKey:@"LongLinkPort"];
    }
    
    // configure FTP server
    DIMFileTransfer *ftp = [DIMFileTransfer sharedInstance];
    //ftp.userAgent = self.userAgent;
    ftp.api = self.uploadAPI;
//    ftp.downloadAPI = self.downloadAPI;
//    ftp.avatarAPI = self.avatarAPI;
    
    // connect server
    [self connectToHost:IP port:[port unsignedShortValue]];
    
    // get user from database and login
    id<MKMUser> user = [facebook currentUser];
    if (user) {
        [self loginUser:user.identifier];
    } else {
        NSLog(@"current user not found");
    }
}

- (void)_launchServiceProviderConfig:(NSDictionary *)config {
    
    id<MKMID> ID = MKMIDParse([config objectForKey:@"ID"]);
    if (!ID) {
        ID = MKMIDParse([config objectForKey:@"did"]);
    }
    DIMServiceProvider *sp = [[DIMServiceProvider alloc] initWithID:ID];
    
    // choose the fast station
    NSArray *stations = [config objectForKey:@"stations"];
    NSDictionary *station = stations.firstObject;
    NSLog(@"got station: %@", station);
    
    [self _startServer:station withProvider:sp];
}

- (void)didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
//    UIApplication *app = [UIApplication sharedApplication];
//
//    // APNs
//    if ([launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey]) {
//        // TODO:
//        // ...
//
//        // clear icon badge
//        NSInteger badge = app.applicationIconBadgeNumber;
//        if (badge > 0) {
//            badge = 0;
//            app.applicationIconBadgeNumber = badge;
//        }
//    }
//    [app registerForRemoteNotifications];
//
//    UNUserNotificationCenter *nc = [UNUserNotificationCenter currentNotificationCenter];
//    nc.delegate = self;
//
//    UNAuthorizationOptions options = UNAuthorizationOptionBadge|UNAuthorizationOptionSound|UNAuthorizationOptionAlert;
//    [nc requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
//        NSLog(@"APNs requestAuthorizationWithOptions completed");
//    }];
    
    // launch server
    NSString *spConfig = [launchOptions objectForKey:@"ConfigFilePath"];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:spConfig];
    [self _launchServiceProviderConfig:config];
    
    // clear icon badge
//    app.applicationIconBadgeNumber = 0;
//    [nc removeAllPendingNotificationRequests];
}

- (void)didEnterBackground {
    DIMClientSession *session = [self session];
    [self.messenger reportOffline:session.identifier];
    [session.station pause];
}

- (void)willEnterForeground {
    DIMClientSession *session = [self session];
    [session.station resume];
    [self.messenger reportOnline:session.identifier];

    // clear icon badge
    UIApplication *app = [UIApplication sharedApplication];
    app.applicationIconBadgeNumber = 0;
    UNUserNotificationCenter *nc = [UNUserNotificationCenter currentNotificationCenter];
    [nc removeAllPendingNotificationRequests];
}

- (void)willTerminate {
    DIMClientSession *session = [self session];
    [session.station end];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSLog(@"willPresentNotification: %@", notification);
    // show alert even in foreground
    completionHandler(UNNotificationPresentationOptionAlert);
}

@end

@implementation Client (APNs)

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *token = MKHexEncode(deviceToken);
    NSLog(@"APNs token: %@", deviceToken);
    NSLog(@"APNs token(hex): %@", token);
    // TODO: send this device token to server
    if (deviceToken.length > 0) {
        self.deviceToken = deviceToken;
    }
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"APNs failed to get token: %@", error);
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
              fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSLog(@"APNs user info: %@", userInfo);
    UIApplication *app = [UIApplication sharedApplication];
    UIApplicationState applicationState = app.applicationState;
    switch (applicationState) {
        case UIApplicationStateActive: {
            
        }
            break;
            
        case UIApplicationStateInactive: {
            
        }
            break;
            
        case UIApplicationStateBackground: {
            
        }
            break;
            
        default:
            break;
    }
}

-(void)setPushAlias{
    
//    DIMSharedFacebook *facebook = [DIMGlobal facebook];
//    id<MKMUser> user = [facebook currentUser];
//    if (user != nil) {
//        NSString *alias = user.identifier.address;
//        [JPUSHService setAlias:alias completion:^(NSInteger iResCode, NSString *iAlias, NSInteger seq) {
//            NSLog(@"Response code %zd", iResCode);
//            NSLog(@"Response code %@", iAlias);
//            NSLog(@"Response code %zd", seq);
//        } seq:0];
//    }
}

@end

@implementation Client (API)

- (NSString *)uploadAPI {
    return @"http://tfs.dim.chat:8081/{ID}/upload?md5={MD5}&salt={SALT}";
    //return @"http://106.52.25.169:8081/{ID}/upload?md5={MD5}&salt={SALT}";
    //return @"https://sechat.dim.chat/{ID}/upload";
}

//- (NSString *)downloadAPI {
//    return @"https://sechat.dim.chat/download/{ID}/{filename}";
//}
//
//- (NSString *)avatarAPI {
//    return @"https://sechat.dim.chat/avatar/{ID}/{filename}";
//}

- (NSString *)reportAPI {
    return @"https://sechat.dim.chat/report?type={type}&identifier={ID}&sender={sender}";
}

- (NSString *)termsAPI {
    return @"https://wallet.dim.chat/dimchat/sechat/privacy.html";
}

- (NSString *)aboutAPI {
    //return @"https://dim.chat/sechat";
    return @"https://sechat.dim.chat/support";
}

@end

@implementation Client (Register)

- (BOOL)importUser:(id<MKMID>)ID meta:(id<MKMMeta>)meta privateKey:(id<MKPrivateKey>)SK {
    
    DIMSharedFacebook *facebook = [DIMGlobal facebook];
    
    // 1. save meta & private key
    if (![facebook savePrivateKey:SK withType:DIMPrivateKeyType_Meta forUser:ID]) {
        NSAssert(false, @"failed to save private key for new user: %@", ID);
        return NO;
    }
    if (![facebook.archivist saveMeta:meta forID:ID]) {
        NSAssert(false, @"failed to save meta for new user: %@", ID);
        return NO;
    }
    
    NSArray<id<MKMID>> *users = [facebook.archivist localUsers];
    id<MKMUser> user = DIMUserWithID(ID);
    [self loginUser:ID];
    
    NSMutableArray<id<MKMUser>> *mArray = [[NSMutableArray alloc] init];
    for (id<MKMID> item in users) {
        [mArray addObject:DIMUserWithID(item)];
    }
    BOOL saved = [facebook saveUserList:mArray withCurrentUser:user];
    NSAssert(saved, @"failed to save users: %@, current user: %@", users, user);
    
    return saved;
}

@end
