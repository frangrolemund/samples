//
//  UIFriendAdditionViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/29/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFriendAdditionViewController.h"

// - forwarfd declarations
@interface UIFriendAdditionViewController (internal)
-(void) _baseCommonConfiguration;
@end

/********************************
 UIFriendAdditionViewController
 ********************************/
@implementation UIFriendAdditionViewController
/*
 *  Object attributes
 */
{
}
@synthesize feedType;

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
    [feedType release];
    feedType = nil;
    
    [super dealloc];
}

@end

/******************************************
 UIFriendAdditionViewController (internal)
 ******************************************/
@implementation UIFriendAdditionViewController (internal)
/*
 *  Standard configuration.
 */
-(void) _baseCommonConfiguration
{
    feedType = nil;
}
@end
