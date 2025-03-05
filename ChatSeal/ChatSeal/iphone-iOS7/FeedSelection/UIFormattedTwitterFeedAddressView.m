//
//  UIFormattedTwitterFeedAddressView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 5/1/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UIFormattedTwitterFeedAddressView.h"

// - forward declarations
@interface UIFormattedTwitterFeedAddressView (internal)
-(void) commonConfiguration;
-(CGFloat) imageSide;
-(CGFloat) aspectAccurateImageWidth;
-(CGFloat) imageOffsetForSide:(CGFloat) imgSide;
@end

/*********************************
 UIFormattedTwitterFeedAddressView
 *********************************/
@implementation UIFormattedTwitterFeedAddressView
/*
 *  Object attributes
 */
{
    CGFloat aspectRatioImage;
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
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonConfiguration];
    }
    return self;
}


/*
 *  Lay out the object.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    // - the only thing requiring layout are the logo and feed name, but Twitter has
    //   precise requirements for them.
    // - NOTE: https://about.twitter.com/press/twitter-brand-policy
    CGSize szMe                = self.bounds.size;
    CGFloat imgSide            = [self imageSide];
    
    CGRect rcLogo              = CGRectIntegral(CGRectMake(0.0f, ((szMe.height-imgSide)/2.0f), [self aspectAccurateImageWidth], imgSide));
    [self logoImageView].frame = rcLogo;
    
    CGFloat offset             = [self imageOffsetForSide:imgSide];
    CGSize  szTitle            = [self addressContentSize];
    CGFloat maxTitleWidth      = szMe.width - offset - CGRectGetMaxX(rcLogo);
    [self addressLabel].frame  = CGRectIntegral(CGRectMake(CGRectGetMaxX(rcLogo) + offset,
                                                          ((szMe.height-szTitle.height)/2.0f),
                                                          MIN(maxTitleWidth, szTitle.width), szTitle.height));
}

/*
 *  Compute the minimum size necessary to display this view.
 */
-(CGSize) sizeThatFits:(CGSize)size
{
    CGFloat imgSide    = [self imageSide];
    CGSize  szTitle    = [self addressContentSize];
    return CGSizeMake([self aspectAccurateImageWidth] + [self imageOffsetForSide:imgSide] + szTitle.width, MAX(imgSide, szTitle.height));
}

/*
 *  Compute the intrinsic content size for autolayout.
 */
-(CGSize) intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, MAX([self imageSide], CGRectGetHeight(self.addressLabel.bounds)));
}

/*
 *  Make sure the address adheres to the Twitter convention.
 */
-(void) setAddressText:(NSString *)address
{
    if ([address length]) {
        NSRange r = [address rangeOfString:@"@"];
        if (r.location != 0) {
            address = [NSString stringWithFormat:@"@%@", address];
        }
    }
    [super setAddressText:address];
    [self invalidateIntrinsicContentSize];
}
@end

/*********************************************
 UIFormattedTwitterFeedAddressView (internal)
 *********************************************/
@implementation UIFormattedTwitterFeedAddressView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    UIImage *imgLogo = [UIImage imageNamed:@"twitter_logo_blue.png"];
    aspectRatioImage = imgLogo.size.width / imgLogo.size.height;
    [[self logoImageView] setImage:imgLogo];
}

/*
 *  Compute the size of the image, given the font in the view.
 */
-(CGFloat) imageSide
{
    CGFloat capHeight = [self addressLabel].font.capHeight;
    return  ceilf((float) capHeight * 1.1f);                    //  110% the height, per the policy.
}

/*
 *  Ensure that the image retains its aspect ratio.
 */
-(CGFloat) aspectAccurateImageWidth
{
    return [self imageSide] * aspectRatioImage;
}

/*
 *  Compute an offset for the image based on the length of its side.
 */
-(CGFloat) imageOffsetForSide:(CGFloat) imgSide
{
    return ceilf((float) imgSide * 0.3f);                       //  spacing is 30% the width, per the policy.
}
@end
