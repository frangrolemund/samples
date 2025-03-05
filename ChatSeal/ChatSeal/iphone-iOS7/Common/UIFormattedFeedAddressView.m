//
//  UIFormattedFeedAddressView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFormattedFeedAddressView.h"
#import "ChatSeal.h"
#import "UIAdvancedSelfSizingTools.h"

// - forward declarations
@interface UIFormattedFeedAddressView (internal)
-(void) _genericAddressConfiguration;
-(void) setUpdatedAddressContent;
@end

/******************************
 UIFormattedFeedAddressView
 NOTE: This intended to be custom laid-out for each feed
       to ensure it is formatted according to each service's requirements.
 ******************************/
@implementation UIFormattedFeedAddressView
/*
 *  Object attributes
 */
{
    UIImageView *ivLogo;
    UILabel     *lAddress;
    CGSize      addressContentSize;
}

/*
 *  Initialize the object.
 */
-(id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _genericAddressConfiguration];
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _genericAddressConfiguration];
    }
    return self;
}


/*
 *  Free the object.
 */
-(void) dealloc
{
    [ivLogo release];
    ivLogo = nil;
    
    [lAddress release];
    lAddress = nil;
    
    [super dealloc];
}

/*
 *  Sub-classes must implement this.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    NSLog(@"CS-ALERT: Implement formatted address sizeThatFits.");
    return CGSizeZero;
}

/*
 *  Change the height of the font for the address text.
 */
-(void) setAddressFontHeight:(CGFloat) height
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        [UIAdvancedSelfSizingTools constrainTextLabel:lAddress withPreferredSettingsAndTextStyle:UIFontTextStyleBody andSizeScale:[ChatSeal superBodyFontScalingFactor] andMinimumSize:1.0f duringInitialization:NO];
    }
    else {
        lAddress.font = [UIFont systemFontOfSize:height];
    }
    [self setUpdatedAddressContent];
}

/*
 *  Assign the text used for the address.
 */
-(void) setAddressText:(NSString *) address
{
#if CHATSEAL_RUNNING_CONTRIVED_SCENARIO
    address = @"@BigDogWinston";
#endif
    lAddress.text = address;
    [self setUpdatedAddressContent];
}

/*
 *  Assign a color to the address text.
 */
-(void) setTextColor:(UIColor *) c
{
    lAddress.textColor = c;
}

/*
 *  Return the image view used to display the logo.
 */
-(UIImageView *) logoImageView
{
    return [[ivLogo retain] autorelease];
}

/*
 *  Return the label used to display the address.
 */
-(UILabel *) addressLabel
{
    return [[lAddress retain] autorelease];
}

/*
 *  The address text is something that we will clip to fit the size of the view, but
 *  the original content size is often useful for layout, which is why we cache it.
 */
-(CGSize) addressContentSize
{
    return addressContentSize;
}

/*
 *  A request to update the dynamic type of the field has been received.
 */
-(void) updateDynamicTypeNotificationReceived
{
    if ([ChatSeal isAdvancedSelfSizingInUse]) {
        [self setAddressFontHeight:lAddress.font.lineHeight];
    }
}

/*
 *  The bounds on this view were changed.
 */
-(void) setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    // - because this is often inserted into an autolayout superview, we don't
    //   always get a new layout here when changes occur.  This happens under
    //   very unusual circumstances in the feed overview cell after we just changed the
    //   font size in the app and then disable the feed.
    [self setNeedsLayout];
}

@end

/**************************************
 UIFormattedFeedAddressView (internal)
 **************************************/
@implementation UIFormattedFeedAddressView (internal)
/*
 *  Configure this view.
 */
-(void) _genericAddressConfiguration
{
    self.backgroundColor = [UIColor clearColor];
    
    ivLogo                          = [[UIImageView alloc] init];
    ivLogo.contentMode              = UIViewContentModeScaleAspectFill;
    ivLogo.layer.minificationFilter = kCAFilterTrilinear;
    [self addSubview:ivLogo];
    
    addressContentSize       = CGSizeZero;
    lAddress                 = [[UILabel alloc] init];
    lAddress.textAlignment   = NSTextAlignmentLeft;
    lAddress.lineBreakMode   = NSLineBreakByTruncatingTail;
    [self addSubview:lAddress];
}

/*
 *  When the address content is modified, ensure that we keep the content size in synch.
 */
-(void) setUpdatedAddressContent
{
    [lAddress sizeToFit];
    addressContentSize = lAddress.bounds.size;
    [self setNeedsLayout];
}

@end
