//
//  UITwitterFriendFeedTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendFeedTableViewCell.h"
#import "ChatSealFeed.h"
#import "UIAdvancedSelfSizingTools.h"
#import "ChatSeal.h"

/********************************
 UITwitterFriendFeedTableViewCell
 ********************************/
@implementation UITwitterFriendFeedTableViewCell
/*
 *  Object attributes
 */
{
}
@synthesize favAddress;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
    }
    return self;
}

/*
 *  One-time initialization.
 */
-(void) awakeFromNib
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        [self.favAddress setAddressFontHeight:[ChatSealFeed standardFontHeightForSelection]];
    }
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [favAddress release];
    favAddress = nil;
    
    [super dealloc];
}

/*
 *  Reconfigure the cell for dynamic type.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL)isInit
{
    [favAddress updateDynamicTypeNotificationReceived];
}

@end
