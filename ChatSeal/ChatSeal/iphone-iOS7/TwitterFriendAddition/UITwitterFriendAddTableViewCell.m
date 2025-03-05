//
//  UITwitterFriendAddTableViewCell.m
//  ChatSeal
//
//  Created by Francis Grolemund on 8/29/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UITwitterFriendAddTableViewCell.h"
#import "ChatSeal.h"

// - constants
static const CGFloat UITFAC_STD_LEFT_PAD     = 15.0f;
static const CGFloat UITFAC_STD_MID_PAD      = 8.0f;
static const CGFloat UITFAC_STD_VPAD         = 10.0f;
static NSString      *UITFAC_STD_TWIT_PREFIX = @"@";
static const NSUInteger UITFAC_MAX_NAME_LEN  = 15;

// - forward declarations
@interface UITwitterFriendAddTableViewCell (internal) <UITextFieldDelegate>
-(void) commonConfiguration;
-(void) notifyDelegateOfTextChangedToText:(NSString *) newText;
@end

/********************************
 UITwitterFriendAddTableViewCell
 ********************************/
@implementation UITwitterFriendAddTableViewCell
/*
 *  Object attributes
 */
{
    UILabel     *lDesc;
    UITextField *tfUserName;
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    
    [lDesc release];
    lDesc = nil;
    
    [tfUserName release];
    tfUserName = nil;
    
    [super dealloc];
}

/*
 *  Return the required size of this cell.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    // - force dynamic reconfig.
    [super sizeThatFits:size];
    
    // - now figure out how big the text is.
    CGSize szRet   = CGSizeMake(size.width, 1.0f);
    CGSize szLabel = [lDesc sizeThatFits:szRet];
    szRet.height   = MAX(szRet.height, szLabel.height);
    szLabel        = [tfUserName sizeThatFits:szRet];
    szRet.height   = MAX(szRet.height, szLabel.height);
    szRet.height  += (UITFAC_STD_VPAD * 2.0f);
    szRet.height   = MAX(szRet.height, [ChatSeal minimumTouchableDimension]);
    return szRet;
}

/*
 *  Layout the cell content.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - layout the custom items.
    [lDesc sizeToFit];
    lDesc.frame      = CGRectMake(UITFAC_STD_LEFT_PAD, 0.0f, CGRectGetWidth(lDesc.bounds), CGRectGetHeight(self.contentView.bounds));
    CGFloat startX   = CGRectGetMaxX(lDesc.frame) + UITFAC_STD_MID_PAD;
    tfUserName.frame = CGRectMake(startX, 0.0f, CGRectGetWidth(self.contentView.frame) - startX, CGRectGetHeight(self.contentView.bounds));
}

/*
 *  Return the screen name that was entered.
 */
-(NSString *) twitterScreenName
{
    NSString *val = tfUserName.text;
    if (![val length] || [val isEqualToString:UITFAC_STD_TWIT_PREFIX]) {
        return nil;
    }
    return [val substringFromIndex:1];
}

/*
 *  Assign the screen name.
 */
-(void) setScreenName:(NSString *) screenName
{
    tfUserName.text = screenName.length ? [UITFAC_STD_TWIT_PREFIX stringByAppendingString:screenName] : nil;
}

/*
 *  Are we allowed to become first responder?
 */
-(BOOL) canBecomeFirstResponder
{
    return [tfUserName canBecomeFirstResponder];
}

/*
 *  Become first responder.
 */
-(BOOL) becomeFirstResponder
{
    return [tfUserName becomeFirstResponder];
}

/*
 *  Can we resign first responder?
 */
-(BOOL) canResignFirstResponder
{
    return [tfUserName canResignFirstResponder];
}

/*
 *  Resign first responder status.
 */
-(BOOL) resignFirstResponder
{
    [super resignFirstResponder];
    return [tfUserName resignFirstResponder];
}

/*
 *  Are we first responder?
 */
-(BOOL) isFirstResponder
{
    return [tfUserName isFirstResponder];
}

/*
 *  Enable/disable the field.
 */
-(void) setEnabled:(BOOL) isEnabled
{
    [tfUserName setEnabled:isEnabled];
}

/*
 *  Don't automatically create the cell height constraint.
 */
-(BOOL) shouldCreateHeightConstraint
{
    return NO;
}

/*
 *  When necessary, reconfigure the labels to use proper dynamic type sizes.
 */
-(void) reconfigureLabelsForDynamicTypeDuringInit:(BOOL) isInit
{
    [UIAdvancedSelfSizingTools constrainTextLabel:lDesc withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
    [UIAdvancedSelfSizingTools constrainTextField:tfUserName withPreferredSettingsAndTextStyle:UIFontTextStyleBody duringInitialization:isInit];
}
@end

/********************************************
 UITwitterFriendAddTableViewCell (internal)
 ********************************************/
@implementation UITwitterFriendAddTableViewCell (internal)
/*
 *  Configure this control.
 */
-(void) commonConfiguration
{
    lDesc           = [[UILabel alloc] init];
    lDesc.text      = NSLocalizedString(@"User Name", nil);
    lDesc.textColor = [UIColor blackColor];
    lDesc.font      = [UIFont systemFontOfSize:18.0f];
    [lDesc sizeToFit];
    [self.contentView addSubview:lDesc];
    
    tfUserName                        = [[UITextField alloc] init];
    tfUserName.font                   = [UIFont systemFontOfSize:18.0f];
    tfUserName.textColor              = [UIColor blackColor];
    tfUserName.placeholder            = NSLocalizedString(@"@name", nil);
    tfUserName.returnKeyType          = UIReturnKeyDone;
    tfUserName.clearButtonMode        = UITextFieldViewModeAlways;
    tfUserName.delegate               = self;
    tfUserName.autocorrectionType     = UITextAutocorrectionTypeNo;
    tfUserName.spellCheckingType      = UITextSpellCheckingTypeNo;
    tfUserName.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tfUserName.keyboardType           = UIKeyboardTypeAlphabet;    
    [self.contentView addSubview:tfUserName];
}

/*
 *  The text field has started editing.
 */
-(void) textFieldDidBeginEditing:(UITextField *)textField
{
    if ([textField.text length] == 0) {
        textField.text = UITFAC_STD_TWIT_PREFIX;
    }
}

/*
 *  The text field has ended editing.
 */
-(void) textFieldDidEndEditing:(UITextField *)textField
{
    if ([textField.text isEqualToString:UITFAC_STD_TWIT_PREFIX]) {
        textField.text = nil;
    }
}

/*
 *  Determine if a change is permitted.
 */
-(BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *curText  = textField.text;
    NSString *proposed = [curText stringByReplacingCharactersInRange:range withString:string];
    BOOL ret           = YES;
    if ([proposed length]) {
        // - if the first item doesn't remain a prefix, don't allow it.
        if (![[proposed substringToIndex:1] isEqualToString:UITFAC_STD_TWIT_PREFIX]) {
            return NO;
        }
        
        // - now validate that the screen name is a decent one for Twitter standards.
        proposed = [proposed substringFromIndex:1];
        NSRange r = [proposed rangeOfString:UITFAC_STD_TWIT_PREFIX];
        if (r.location != NSNotFound || [proposed length] > UITFAC_MAX_NAME_LEN) {
            return NO;
        }
        
        // - I'm explicitly building this instead of using the canned categories, because it isn't clear if they only provide Latin characters.
        NSMutableCharacterSet *mcs = [NSMutableCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
        [mcs addCharactersInString:@"abcdefghijklmnopqrstuvwxyz"];
        [mcs addCharactersInString:@"0123456789_"];
        r = [proposed rangeOfCharacterFromSet:[mcs invertedSet]];
        if (r.location != NSNotFound) {
            return NO;
        }
    }
    else {
        // - allow selection and full deletion of the content, but if we do then just make sure
        //   the prefix remains.
        tfUserName.text = UITFAC_STD_TWIT_PREFIX;
        ret = NO;
    }
    
    // - Let the delegate know the text was modified.
    [self notifyDelegateOfTextChangedToText:proposed];
    return ret;
}

/*
 *  Determine if we are allowed to return by consulting the delegate.
 */
-(BOOL) textFieldShouldReturn:(UITextField *)textField
{
    BOOL ret = YES;
    if (delegate && [delegate respondsToSelector:@selector(twitterFriendAddReturnRequested:)]) {
        ret = [delegate twitterFriendAddReturnRequested:self];
    }
    if (ret) {
        [self resignFirstResponder];
    }
    return ret;
}

/*
 *  Should the field be cleared?
 */
-(BOOL) textFieldShouldClear:(UITextField *)textField
{
    // - we do this ourselves.
    if (![tfUserName.text isEqualToString:UITFAC_STD_TWIT_PREFIX]) {
        tfUserName.text = UITFAC_STD_TWIT_PREFIX;
        [self notifyDelegateOfTextChangedToText:nil];
    }
    return NO;
}

/*
 *  Let the delegate know when text is modified.
 */
-(void) notifyDelegateOfTextChangedToText:(NSString *) newText
{
    if (delegate && [delegate respondsToSelector:@selector(twitterFriendAddTextChanged:toValue:)]) {
        [delegate twitterFriendAddTextChanged:self toValue:[newText length] ? newText : nil];
    }
}

@end
