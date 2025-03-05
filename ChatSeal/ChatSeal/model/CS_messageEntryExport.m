//
//  CS_messageEntryExport.m
//  ChatSeal
//
//  Created by Francis Grolemund on 6/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_messageEntryExport.h"
#import "RealSecureImage/RealSecureImage.h"

/**************************
 CS_messageEntryExport
 **************************/
@implementation CS_messageEntryExport
@synthesize seal;
@synthesize exportedContent;
@synthesize decoy;
@synthesize entryUUID;
@synthesize uCachedItem;
@synthesize dCachedExported;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        seal            = nil;
        exportedContent = nil;
        decoy           = nil;
        entryUUID       = nil;
        uCachedItem     = nil;
        dCachedExported = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [seal release];
    seal = nil;
    
    [exportedContent release];
    exportedContent = nil;
    
    [decoy release];
    decoy = nil;
    
    [entryUUID release];
    entryUUID = nil;
    
    [uCachedItem release];
    uCachedItem = nil;
    
    [dCachedExported release];
    dCachedExported = nil;
    
    [super dealloc];
}
@end
