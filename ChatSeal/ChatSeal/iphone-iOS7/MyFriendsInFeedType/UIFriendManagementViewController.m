//
//  UIFriendManagementViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/17/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFriendManagementViewController.h"

// - forward declarations
@interface UIFriendManagementViewController (internal)
-(void) _baseCommonConfiguration;
@end

/*********************************
 UIFriendManagementViewController
 *********************************/
@implementation UIFriendManagementViewController
/*
 *  Object attributes
 */
{
}
@synthesize feedFriend;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        [self _baseCommonConfiguration];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _baseCommonConfiguration];
    }
    return self;
}
/*
 *  Initialize the object.
 */
-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self _baseCommonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [feedFriend release];
    feedFriend = nil;
    
    [super dealloc];
}

@end

/*******************************************
 UIFriendManagementViewController (internal)
 *******************************************/
@implementation UIFriendManagementViewController (internal)
/*
 *  Configure the object.
 */
-(void) _baseCommonConfiguration
{
    feedFriend = nil;
}
@end
