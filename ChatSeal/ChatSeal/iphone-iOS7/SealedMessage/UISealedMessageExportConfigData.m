//
//  UISealedMessageExportConfigData.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UISealedMessageExportConfigData.h"

/*********************************************
 UISealedMessageExportConfigData
 *********************************************/
@implementation UISealedMessageExportConfigData
@synthesize caller;
@synthesize items;
@synthesize targetFeed;
@synthesize delegate;
@synthesize message;
@synthesize messageType;
@synthesize keyboardIsVisible;
@synthesize appendedEntry;
@synthesize messageIsNew;
@synthesize preferredSealId;
@synthesize detailActiveItem;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        caller            = nil;
        items             = nil;
        targetFeed        = nil;
        delegate          = nil;
        message           = nil;
        messageType       = PSMT_GENERIC;
        keyboardIsVisible = NO;
        appendedEntry     = nil;
        messageIsNew      = NO;
        preferredSealId   = nil;
        detailActiveItem  = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    caller = nil;
    
    [items release];
    items = nil;
    
    [targetFeed release];
    targetFeed = nil;
    
    delegate = nil;
    
    [message release];
    message = nil;
    
    [appendedEntry release];
    appendedEntry = nil;
    
    [preferredSealId release];
    preferredSealId = nil;
    
    [detailActiveItem release];
    detailActiveItem = nil;
    
    [super dealloc];
}
@end
