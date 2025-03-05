//
//  CS_privacyContentItem.m
//  ChatSeal
//
//  Created by Francis Grolemund on 12/3/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_privacyContentItem.h"

/************************
 CS_privacyContentItem
 ************************/
@implementation CS_privacyContentItem
/*
 *  Object attributes.
 */
{
    NSString *privacyTitle;
    NSString *privacyDesc;
}

/*
 *  Initialize the object.
 */
-(id) initWithTitle:(NSString *) t andDescription:(NSString *) d
{
    self = [super init];
    if (self) {
        privacyTitle = [t retain];
        privacyDesc  = [d retain];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [privacyTitle release];
    privacyTitle = nil;
    
    [privacyDesc release];
    privacyDesc = nil;
    
    [super dealloc];
}

/*
 *  Return an initialized object.
 */
+(CS_privacyContentItem *) privacyContentWithTitle:(NSString *) title andDescription:(NSString *) desc
{
    return [[[CS_privacyContentItem alloc] initWithTitle:title andDescription:desc] autorelease];
}

/*
 *  Return the title of the privacy definition.
 */
-(NSString *) title
{
    return [[privacyTitle retain] autorelease];
}

/*
 *  Return the description of the privacy definition.
 */
-(NSString *) desc
{
    return [[privacyDesc retain] autorelease];
}


@end
