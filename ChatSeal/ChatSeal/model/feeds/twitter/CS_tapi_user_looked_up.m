//
//  CS_tapi_user_looked_up.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_user_looked_up.h"

/*****************************
 CS_tapi_user_looked_up
 *****************************/
@implementation CS_tapi_user_looked_up
@synthesize screenName;
@synthesize isProtected;
@synthesize fullName;
@synthesize location;
@synthesize sProfileImage;

/*
 *  Return a new user object initialized from the standard dictionary format.
 */
+(CS_tapi_user_looked_up *) userFromTapiDictionary:(NSDictionary *) dict
{
    if (!dict) {
        return nil;
    }
    
    CS_tapi_user_looked_up *tulu = [[[CS_tapi_user_looked_up alloc] init] autorelease];
    tulu.screenName              = [dict objectForKey:@"screen_name"];
    NSNumber *prot               = [dict objectForKey:@"protected"];
    tulu.isProtected             = [prot boolValue];
    tulu.fullName                = [dict objectForKey:@"name"];
    tulu.location                = [dict objectForKey:@"location"];
    tulu.sProfileImage           = [dict objectForKey:@"profile_image_url_https"];
    if (!tulu.sProfileImage) {
        tulu.sProfileImage       = [dict objectForKey:@"profile_image_url"];
    }    
    return tulu;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        screenName    = nil;
        isProtected   = NO;
        fullName      = nil;
        location      = nil;
        sProfileImage = nil;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [screenName release];
    screenName = nil;
    
    [fullName release];
    fullName = nil;
    
    [location release];
    location = nil;
    
    [sProfileImage release];
    sProfileImage = nil;
    
    [super dealloc];
}

@end
