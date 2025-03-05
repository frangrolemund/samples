//
//  AppDelegate.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 4/9/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "AppDelegate.h"
#import "ChatSeal.h"
#import "ChatSealFeedCollector.h"

@implementation AppDelegate

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

// - make sure the completion handler is cached before we continue.
- (void) application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [ChatSeal saveBackgroundSessionCompletionHandler:^(void) {
        NSString *sTmp = @"All events were handled --> ";
        NSDate *d = [NSDate date];
        sTmp = [NSString stringWithFormat:@"%@%4.4f", sTmp, d.timeIntervalSinceReferenceDate];
        NSURL *u = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        u = [u URLByAppendingPathComponent:@"handleEventsForBackgroundURLSession.txt"];
        [sTmp writeToURL:u atomically:YES encoding:NSASCIIStringEncoding error:nil];
        
        completionHandler();
    }];
    
    // - reopen the feed collector so that it can begin processing.
    if ([ChatSeal openVaultWithPassword:nil andError:nil]) {
    }
}

@end
