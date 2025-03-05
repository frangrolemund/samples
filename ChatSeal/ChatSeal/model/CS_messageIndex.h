//
//  CS_messageIndex.h
//  ChatSeal
//
//  Created by Francis Grolemund on 11/5/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CS_messageIndex : NSObject
+(NSArray *) standardStringSplitWithWhitespace:(NSString *) content andAlphaNumOnly:(BOOL) alphaOnly;
-(id) initWithIndexData:(NSData *) indexData;
-(void) appendContentToIndex:(NSString *) content;
-(BOOL) generateIndexWithSalt:(NSString *) saltValue;
-(BOOL) matchesString:(NSString *) searchTerm usingSalt:(NSString *) saltValue;
-(NSData *) indexData;
-(void) setStringMatchIncludesAbbreviatedToday:(BOOL) includesToday;
@end
