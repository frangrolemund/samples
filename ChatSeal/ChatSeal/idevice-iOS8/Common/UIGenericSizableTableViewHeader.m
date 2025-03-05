//
//  UIGenericSizableTableViewHeader.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIGenericSizableTableViewHeader.h"
#import "UIGenericSizableTableViewCell.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UIGSTV_STD_HPAD = 18.0f;

// - forward declarations
@interface UIGenericSizableTableViewHeader (internal)
-(void) commonConfiguration;
-(void) reconfigureHeaderFontForSizingAndIsInit:(BOOL) isInit;
@end

/***************************************************
 UIGenericSizableTableViewHeader
 - with only text this works well with the tableHeaderView property, but
   it can also be used for custom section headers as well.
 ***************************************************/
@implementation UIGenericSizableTableViewHeader
/*
 *  Object attributes.
 */
{
    UILabel *lHeader;               // - this may not be used if the header does its own formatting.
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithText:(NSString *)headerText
{
    self = [super init];
    if (self) {
        [self commonConfiguration];
        lHeader               = [[UILabel alloc] init];
        lHeader.font          = [UIFont systemFontOfSize:15.0f];
        [self reconfigureHeaderFontForSizingAndIsInit:YES];
        lHeader.textColor     = [UIColor darkGrayColor];
        lHeader.numberOfLines = 0;
        lHeader.textAlignment = NSTextAlignmentCenter;
        lHeader.text          = headerText;
        [self addSubview:lHeader];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    [lHeader release];
    lHeader = nil;
    
    [super dealloc];
}

/*
 *  Return the dimension of the vertical padding.
 */
-(CGFloat) standardVerticalPad
{
    return lHeader.font.lineHeight * 0.75f;
}

/*
 *  Size this view based on what the text requires.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    if (size.width > (UIGSTV_STD_HPAD * 2.0f)) {
        size.width -= (UIGSTV_STD_HPAD * 2.0f);
    }
    CGSize szText  = [lHeader sizeThatFits:size];
    szText.height += ([self standardVerticalPad] * 2.0f);
    return szText;
}

/*
 *  Lay out the content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    CGFloat vpad  = [self standardVerticalPad];
    lHeader.frame = CGRectIntegral(CGRectMake(UIGSTV_STD_HPAD, vpad, CGRectGetWidth(self.bounds) - (UIGSTV_STD_HPAD * 2.0f), CGRectGetHeight(self.bounds) - (vpad * 2.0f)));
}

/*
 *  This is issued when the content size changes.
 */
-(void) updateDynamicTypeNotificationReceived
{
    [self reconfigureHeaderFontForSizingAndIsInit:NO];
}

@end

/*******************************************
 UIGenericSizableTableViewHeader (internal)
 *******************************************/
@implementation UIGenericSizableTableViewHeader (internal)
/*
 *  Shared configuration.
 */
-(void) commonConfiguration
{
    lHeader = nil;
}

/*
 *  Set up the header font, if necessary to support dynamic sizing.
 */
-(void) reconfigureHeaderFontForSizingAndIsInit:(BOOL) isInit
{
    if (![ChatSeal isAdvancedSelfSizingInUse]) {
        return;
    }
    [UIAdvancedSelfSizingTools constrainTextLabel:lHeader withPreferredSettingsAndTextStyle:UIFontTextStyleSubheadline duringInitialization:isInit];
    [self setNeedsLayout];
}

@end
