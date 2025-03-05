//
//  UISealedMessageDisplayCache.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/11/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UISealedMessageDisplayCache : NSObject
-(id) initWithMaximumRowsPerSection:(NSInteger) maxRows;
-(void) setSectionCapacity:(NSUInteger) numSections;
-(void) clearCache;
-(void) cacheRowHeight:(CGFloat) height forIndexPath:(NSIndexPath *) ip;
-(CGFloat) rowHeightForIndexPath:(NSIndexPath *) ip;
@end
