//
//  ChatSealFeedFriend.m
//  ChatSeal
//
//  Created by Francis Grolemund on 7/15/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "ChatSealFeedFriend.h"
#import "ChatSealFeedType.h"
#import <libkern/OSAtomic.h>

// - forward declarations
@interface ChatSealFeedFriend (internal)
-(id) initWithType:(ChatSealFeedType *) ft andUserId:(NSString *) uid forDelegate:(id<ChatSealFeedFriendDelegate>) delegate withContext:(NSObject *) ctx;
@end

// - locals
static int32_t newFriendVersion = 0;

/*************************
 ChatSealFeedFriend
 *************************/
@implementation ChatSealFeedFriend
/*
 *  Object attributes
 */
{
    id<ChatSealFeedFriendDelegate> delegate;            //  retained!
    NSObject                       *context;
}
@synthesize feedType;
@synthesize userId;
@synthesize friendNameOrDescription;
@synthesize friendDetailDescription;
@synthesize friendLocation;
@synthesize profileImage;
@synthesize isBroken;
@synthesize isIdentified;
@synthesize friendVersion;
@synthesize isDeleted;
@synthesize isTrusted;

/*
 *  Allocate a new friend definition.
 */
+(ChatSealFeedFriend *) friendForFeedType:(ChatSealFeedType *) ft andUserId:(NSString *) userId forDelegate:(id<ChatSealFeedFriendDelegate>) delegate withContext:(NSObject *) ctx
{
    return [[[ChatSealFeedFriend alloc] initWithType:ft andUserId:userId forDelegate:delegate withContext:ctx] autorelease];
}

/*
 *  Create a debug object.
 */
+(ChatSealFeedFriend *) debugFriendWithUserId:(NSString *) userId andName:(NSString *) name andFriendVersion:(uint16_t) version
{
    ChatSealFeedFriend *ff     = [[[ChatSealFeedFriend alloc] initWithType:nil andUserId:userId forDelegate:nil withContext:nil] autorelease];
    ff.friendNameOrDescription = name;
    ff.friendVersion           = version;
    return ff;
}

/*
 *  Return the text to display when a friend's account is deleted.
 */
+(NSString *) standardAccountDeletionText
{
    return NSLocalizedString(@"Account has been deleted.", nil);
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [feedType release];
    feedType = nil;
    
    [userId release];
    userId = nil;
    
    [friendNameOrDescription release];
    friendNameOrDescription = nil;
    
    [friendDetailDescription release];
    friendDetailDescription = nil;
    
    [friendLocation release];
    friendLocation = nil;
    
    [profileImage release];
    profileImage = nil;
    
    [delegate release];
    delegate = nil;
    
    [context release];
    context = nil;

    [super dealloc];
}

/*
 *  Return a debug description.
 */
-(NSString *) description
{
    return [NSString stringWithFormat:@"%@ in %@ as %@ (%@, image = %s, broken = %s, has-info = %s, deleted = %s, trusted = %s)",
            self.userId,
            self.feedType.typeId,
            self.friendNameOrDescription ? self.friendNameOrDescription : @"NO-NAME",
            self.friendDetailDescription ? self.friendDetailDescription : @"NO-DESC",
            self.profileImage ? "YES" : "NO",
            self.isBroken ? "YES" : "NO",
            self.isIdentified ? "YES" : "NO",
            self.isDeleted ? "YES" : "NO",
            self.isTrusted ? "YES" : "NO"
            ];
}

/*
 *  Test if this object is equal to another.
 */
-(BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[ChatSealFeedFriend class]] &&
        self.feedType == ((ChatSealFeedFriend *) object).feedType &&
        [self.userId isEqualToString:[(ChatSealFeedFriend *) object userId]]) {
        return YES;
    }
    return NO;
}

/*
 *  Return the profile image for this friend.
 */
-(UIImage *) profileImage
{
    if (!profileImage) {
        // - if we have no profile image, load it through the delegate now, if that is specified.
        if (delegate) {
            profileImage = [[delegate profileImageForFriend:self withContext:context] retain];
        }
    }
    return [[profileImage retain] autorelease];
}

/*
 *  The purpose of this method is to make sure that the data that matters is updated in this object when
 *  we get changes.
 */
-(void) assignContentFromEquivalentFriend:(ChatSealFeedFriend *) friendData
{
    if (friendData && self.friendVersion != friendData.friendVersion) {
        self.friendNameOrDescription = friendData.friendNameOrDescription;
        self.friendDetailDescription = friendData.friendDetailDescription;
        self.friendLocation          = friendData.friendLocation;
        self.friendVersion           = friendData.friendVersion;
        self.isBroken                = friendData.isBroken;
        self.isIdentified            = friendData.isIdentified;
        self.isDeleted               = friendData.isDeleted;
        self.isTrusted               = friendData.isTrusted;
        if (![context isEqual:friendData->context]) {
            [profileImage release];
            profileImage = nil;
            [context release];
            context = [friendData->context retain];
        }
    }
}
@end


/******************************
 ChatSealFeedFriend (internal)
 ******************************/
@implementation ChatSealFeedFriend (internal)
/*
 *  Initialize the object.
 */
-(id) initWithType:(ChatSealFeedType *)ft andUserId:(NSString *)uid forDelegate:(id<ChatSealFeedFriendDelegate>) d withContext:(NSObject *) ctx
{
    self = [super init];
    if (self) {
        feedType                = [ft retain];
        userId                  = [uid retain];
        friendNameOrDescription = nil;
        friendDetailDescription = nil;
        friendLocation          = nil;
        profileImage            = nil;
        isBroken                = NO;
        isIdentified            = NO;
        friendVersion           = (uint16_t) (OSAtomicIncrement32(&newFriendVersion) & 0xFFFF);           // the friend version always changes unless we direct it no to.
        delegate                = [d retain];
        context                 = [ctx retain];
        isDeleted               = NO;
        isTrusted               = NO;
    }
    return self;
}

@end