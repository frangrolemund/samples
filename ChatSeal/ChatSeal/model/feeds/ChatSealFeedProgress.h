//
//  ChatSealFeedProgress.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/24/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChatSealFeedProgress : NSObject
-(BOOL) isComplete;
-(double) overallProgress;
-(BOOL) isScanComplete;
-(double) scanProgress;
-(BOOL) isPostingComplete;
-(double) postingProgress;
@end
