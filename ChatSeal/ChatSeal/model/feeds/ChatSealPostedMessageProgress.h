//
//  ChatSealPostedMessageProgress.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChatSealPostedMessageProgress : NSObject
-(BOOL) isCompleted;
-(BOOL) hasStarted;
-(double) progress;
-(NSString *) messageId;
-(NSString *) entryId;
-(NSString *) safeEntryId;
-(NSString *) msgDescription;
@end
