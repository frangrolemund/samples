//
//  CS_postedMessageState.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/13/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    CS_PMS_PENDING     = 0,
    CS_PMS_DELIVERING,
    CS_PMS_COMPLETED,
    CS_PMS_POSTPONED               // - missing seal, which we'll try again when we acquire it again.
} cs_postedmessage_state_t;

@interface CS_postedMessageState : NSObject
+(CS_postedMessageState *) stateForSafeEntry:(NSString *) safeEntryId;
-(NSString *) safeEntryId;
-(NSDate *) dateCreated;
-(NSComparisonResult) compare:(CS_postedMessageState *) otherState;
@property (nonatomic, assign) cs_postedmessage_state_t  state;
@property (nonatomic, assign) int64_t                   totalToSend;
@property (nonatomic, assign) int64_t                   numSent;
@property (nonatomic, retain) NSString                  *msgDescription;
@end
