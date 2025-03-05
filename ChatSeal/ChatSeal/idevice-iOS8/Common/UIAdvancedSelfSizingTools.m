//
//  UIAdvancedSelfSizingTools.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIAdvancedSelfSizingTools.h"
#import "ChatSeal.h"

// - constants
static NSString *UIASST_THREAD_SIZING_STATE = @"cs_sizing";

// - forward declarations
@interface UIAdvancedSelfSizingTools (internal)
+(UIFont *) updatedFontForControlWithDescriptor:(UIFontDescriptor *) fdCur withConstrainedMaximumTextStyle:(NSString *) textStyle andSizeScale:(CGFloat) sizeScale
                                   andMinHeight:(CGFloat) minHeight duringInitialization:(BOOL) isInit;
+(UIFont *) updatedFontForControlWithDescriptor:(UIFontDescriptor *) fdCur withConstrainedMaximumTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit;
+(NSInteger) addToSizingStateWithValue:(NSInteger) toAdd;
@end

/*******************************
 UIAdvancedSelfSizingTools
 *******************************/
@implementation UIAdvancedSelfSizingTools
/*
 *  Ensure that a text label of the given style is appropriately-constrained for standard UI layout.
 */
+(void) constrainTextLabel:(UILabel *) l withPreferredSettingsAndTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit
{
    [self constrainTextLabel:l withPreferredSettingsAndTextStyle:textStyle andMinimumSize:0.0f duringInitialization:isInit];
}

/*
 *  Ensure that a text field of the given style is appropriately-constrained for a standard UI layout.
 */
+(void) constrainTextField:(UITextField *) tf withPreferredSettingsAndTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit
{
    UIFont *font = [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:tf.font.fontDescriptor withConstrainedMaximumTextStyle:textStyle duringInitialization:isInit];
    if (font) {
        tf.font = font;
        [tf invalidateIntrinsicContentSize];
    }
}

/*
 *  Ensure that a text button of the given style is appropriately-constrained for standard UI layout.
 */
+(void) constrainTextButton:(UIButton *) tb withPreferredSettingsAndTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit
{
    [self constrainTextButton:tb withPreferredSettingsAndTextStyle:textStyle andMinimumSize:0.0f duringInitialization:isInit];
}

/*
 *  Ensure that full-screen alert text is constrained, with the header being slightly larger.
 */
+(void) constrainAlertLabel:(UILabel *) l asHeader:(BOOL) isHeader duringInitialization:(BOOL) isInit
{
    CGFloat scale = isHeader ? 1.15f : 1.0f;
    
    UIFont *font = [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:l.font.fontDescriptor
                                                  withConstrainedMaximumTextStyle:isHeader ? UIFontTextStyleHeadline : UIFontTextStyleBody
                                                                     andSizeScale:scale
                                                                     andMinHeight:0.0f
                                                             duringInitialization:isInit];
    if (font) {
        l.font = font;
        [l invalidateIntrinsicContentSize];
    }
}

/*
 *  Ensure that a full-screen alert button is constrained, with the header being slightly larger.
 */
+(void) constrainAlertButton:(UIButton *) b duringInitialization:(BOOL) isInit
{
    UIFont *font = [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:b.titleLabel.font.fontDescriptor
                                                  withConstrainedMaximumTextStyle:UIFontTextStyleBody
                                                                     andSizeScale:1.0f
                                                                     andMinHeight:[ChatSeal minimumButtonFontSize]
                                                             duringInitialization:isInit];
    if (font) {
        b.titleLabel.font = font;
        [b.titleLabel invalidateIntrinsicContentSize];
    }    
}

/*
 *  Ensure that a text label of the given style is appropriately-constrained for standard UI layout, but don't let it diminish below a specific height.
 */
+(void) constrainTextLabel:(UILabel *) l withPreferredSettingsAndTextStyle:(NSString *) textStyle andMinimumSize:(CGFloat) minPointSize duringInitialization:(BOOL) isInit
{
    return [UIAdvancedSelfSizingTools constrainTextLabel:l withPreferredSettingsAndTextStyle:textStyle andSizeScale:1.0f andMinimumSize:minPointSize duringInitialization:isInit];
}

/*
 *  Ensure that a text label of a given style is appropriately-constrainted for the standard UI layout, but adjust its size a bit with some limits.
 */
+(void) constrainTextLabel:(UILabel *) l withPreferredSettingsAndTextStyle:(NSString *) textStyle andSizeScale:(CGFloat) sizeScale andMinimumSize:(CGFloat) minPointSize
      duringInitialization:(BOOL) isInit
{
    UIFont *font = [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:l.font.fontDescriptor
                                                  withConstrainedMaximumTextStyle:textStyle
                                                                     andSizeScale:sizeScale
                                                                     andMinHeight:minPointSize
                                                             duringInitialization:isInit];
    if (font) {
        l.font = font;
        [l invalidateIntrinsicContentSize];
    }
}

/*
 *  Ensure that a text button of the given style is appropriately-constrained for the standard UI layout, but don't let it diminish below a specific height.
 */
+(void) constrainTextButton:(UIButton *) tb withPreferredSettingsAndTextStyle:(NSString *) textStyle andMinimumSize:(CGFloat) minPointSize duringInitialization:(BOOL) isInit
{
    UIFont *font = [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:tb.titleLabel.font.fontDescriptor
                                                  withConstrainedMaximumTextStyle:textStyle
                                                                     andSizeScale:1.0f
                                                                     andMinHeight:minPointSize
                                                             duringInitialization:isInit];
    if (font) {
        tb.titleLabel.font = font;
        [tb.titleLabel invalidateIntrinsicContentSize];
    }
}

/*
 *  Determine if we're currently responding to a size-change notification on the current thread.
 */
+(BOOL) isInSizeChangeNotification
{
    if ([ChatSeal isAdvancedSelfSizingInUse] && [UIAdvancedSelfSizingTools addToSizingStateWithValue:0]) {
        return YES;
    }
    else {
        return NO;
    }
}

/*
 *  Are we starting a new size change sequence of operations?
 */
+(void) startSizeChangeSequence
{
    [UIAdvancedSelfSizingTools addToSizingStateWithValue:1];
}

/*
 *  A size change sequence (from the notification to the layout of the table) has completed.
 */
+(void) completeSizeChangeSequence
{
    [UIAdvancedSelfSizingTools addToSizingStateWithValue:-1];  
}

/*
 *  Return a constrained font for the current settings.
 */
+(UIFont *) constrainedFontForPreferredSettingsAndTextStyle:(NSString *) textStyle
{
    return [UIAdvancedSelfSizingTools constrainedFontForPreferredSettingsAndTextStyle:textStyle andSizeScale:1.0f andMinHeight:0.0f];
}

/*
 *  Return a constrained font for the current settings.
 */
+(UIFont *) constrainedFontForPreferredSettingsAndTextStyle:(NSString *) textStyle andSizeScale:(CGFloat) sizeScale andMinHeight:(CGFloat) minHeight
{
    return [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:nil withConstrainedMaximumTextStyle:textStyle andSizeScale:sizeScale andMinHeight:minHeight duringInitialization:YES];
}

@end

/************************************
 UIAdvancedSelfSizingTools (internal)
 ************************************/
@implementation UIAdvancedSelfSizingTools (internal)
/*
 *  Return a new font for a control with the given requirements.
 *   - the size scale can be used to scale the font's resulting point size to get something slightly different.
  *  - similar to Settings, we'll max out the height so that the label never gets too terribly tall as a rule.
 */
+(UIFont *) updatedFontForControlWithDescriptor:(UIFontDescriptor *) fdCur withConstrainedMaximumTextStyle:(NSString *) textStyle andSizeScale:(CGFloat) sizeScale
                                   andMinHeight:(CGFloat) minHeight duringInitialization:(BOOL) isInit
{
    UIFontDescriptor *fd = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    if (!fd) {
        return nil;
    }
    
    CGFloat maximumPointSize = 0.0f;
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        if ([textStyle isEqualToString:UIFontTextStyleBody]) {
            // - this is basically equivalent to that XXXL text size, which appear to be what the
            //   Settings likes to use.
            maximumPointSize = 21.0f;
        }
        else if ([textStyle isEqualToString:UIFontTextStyleHeadline]) {
            maximumPointSize = 23.0f;
        }
        else if ([textStyle isEqualToString:UIFontTextStyleSubheadline]) {
            maximumPointSize = 21.0f;
        }
        else if ([textStyle isEqualToString:UIFontTextStyleCaption1]) {
            maximumPointSize = 18.0f;
        }
        else if ([textStyle isEqualToString:UIFontTextStyleCaption2]) {
            maximumPointSize = 17.0f;
        }
        else if ([textStyle isEqualToString:UIFontTextStyleFootnote]) {
            maximumPointSize = 19.0f;
        }
        else {
            maximumPointSize = fd.pointSize;
        }
    }
    else {
        // - the old codebase can still take advantage of this, just without the constrained qualities.
        maximumPointSize = fd.pointSize;
    }
    
    // ...figure out the actual point size.
    CGFloat newPointSize = (CGFloat) floor(MAX(MIN(fd.pointSize, maximumPointSize) * sizeScale, minHeight));
    if (!isInit && fdCur) {
        // - when we're not initializing the label, make sure the point size is different before we go through
        //   the cost of changing it.
        if ((int) newPointSize == (int) fdCur.pointSize &&
            [fdCur.postscriptName isEqualToString:fd.postscriptName]) {
            return nil;
        }
    }    
    return [UIFont fontWithDescriptor:fd size:newPointSize];
}

/*
 *  Return a new font with the given requirements.
 */
+(UIFont *) updatedFontForControlWithDescriptor:(UIFontDescriptor *) fdCur withConstrainedMaximumTextStyle:(NSString *) textStyle duringInitialization:(BOOL) isInit
{
    return [UIAdvancedSelfSizingTools updatedFontForControlWithDescriptor:fdCur withConstrainedMaximumTextStyle:textStyle andSizeScale:1.0f andMinHeight:0.0f duringInitialization:isInit];
}

/*
 *  Add to the sizing state and return the result.
 */
+(NSInteger) addToSizingStateWithValue:(NSInteger) toAdd
{
    NSThread *curThread = [NSThread currentThread];
    NSNumber *n = [[curThread threadDictionary] objectForKey:UIASST_THREAD_SIZING_STATE];
    if (toAdd) {
        NSInteger newValue = MAX(n.integerValue + toAdd, 0);
        n = [NSNumber numberWithInteger:newValue];
        [[curThread threadDictionary] setObject:n forKey:UIASST_THREAD_SIZING_STATE];
    }
    return [n integerValue];
}
@end