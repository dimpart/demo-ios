//
//  Client.h
//  DIMP
//
//  Created by Albert Moky on 2019/1/28.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import <UIKit/UIApplication.h>
#import <UserNotifications/UserNotifications.h>
#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface Client : DIMTerminal<UNUserNotificationCenterDelegate>

@property (strong, nonatomic) NSData *deviceToken;

@property (readonly, nonatomic) NSString *displayName;

@end

@interface Client (AppDelegate)

- (void)didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
- (void)didEnterBackground;
- (void)willEnterForeground;
- (void)willTerminate;

@end

@interface Client (APNs)

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
              fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
-(void)setPushAlias;

@end

@interface Client (API)

// @"https://sechat.dim.chat/{ID}}/upload"
@property (readonly, copy, nonatomic) NSString *uploadAPI;

//// @"https://sechat.dim.chat/download/{ID}/{filename}"
//@property (readonly, copy, nonatomic) NSString *downloadAPI;
//
//// @"https://sechat.dim.chat/avatar/{ID}/{filename}"
//@property (readonly, copy, nonatomic) NSString *avatarAPI;

// @"https://sechat.dim.chat/report?type={type}&identifier={ID}&sender={sender}"
@property (readonly, copy, nonatomic) NSString *reportAPI;

@property (readonly, copy, nonatomic) NSString *termsAPI;
@property (readonly, copy, nonatomic) NSString *aboutAPI;

@end

@interface Client (Register)

- (BOOL)importUser:(id<MKMID>)ID meta:(id<MKMMeta>)meta privateKey:(id<MKPrivateKey>)SK;

@end

NS_ASSUME_NONNULL_END
