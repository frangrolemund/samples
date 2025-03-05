//
//  ChatSealMessageEntry.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/14/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RealSecureImage/RealSecureImage.h"

@interface ChatSealMessageEntry : NSObject
+(NSString *) standardDisplayFormattedTimeForDate:(NSDate *) date;
+(NSMutableAttributedString *) standardDisplayDetailsForAuthorSuffix:(NSString *) beginString withAuthorColor:(UIColor *) authorColor andBoldFont:(UIFont *) fontBold
                                                              onDate:(NSDate *) date withTimeString:(NSString *) sTime andTimeFont:(UIFont *) timeFont;
+(CGFloat) standardPlaceholderDimension;

-(RSISecureSeal *) seal;
-(NSDate *) creationDate;
-(NSString *) author;
-(BOOL) isOwnerEntry;
-(NSUInteger) numItems;
-(BOOL) isItemAnImageAtIndex:(NSUInteger) idx;
-(NSString *) itemAsStringAtIndex:(NSUInteger) idx;
-(UIImage *) itemAtIndex:(NSUInteger) idx asImageWithMaxSize:(CGSize) szMax andError:(NSError **) err;
-(id) itemAtIndex:(NSUInteger) idx withError:(NSError **) err;
-(CGFloat) cellHeightForImageAtIndex:(NSUInteger) idx;
-(CGSize) imageSizeForItemAtIndex:(NSUInteger) idx;
-(NSData *) sealedMessageWithError:(NSError **) err;
-(BOOL) wasRevocation;
-(BOOL) hasAlternateDecoy;
-(UIImage *) imagePlaceholderAtIndex:(NSUInteger) idx;
-(BOOL) isRead;
-(NSString *) messageId;
-(NSString *) entryId;
-(NSString *) sealId;
-(BOOL) isStale;
@end
