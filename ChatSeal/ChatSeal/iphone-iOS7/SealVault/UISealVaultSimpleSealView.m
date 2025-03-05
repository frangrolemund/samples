//
//  UISealVaultSimpleSealView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/2/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealVaultSimpleSealView.h"
#import "UISealWaxViewV2.h"

// - forward declarations
@interface UISealVaultSimpleSealView (internal)
-(void) commonConfiguration;
@end

/**************************
 UISealVaultSimpleSealView
 **************************/
@implementation UISealVaultSimpleSealView
/*
 *  Object attributes.
 */
{
    UIImageView     *ivSeal;
    UISealWaxViewV2 *swvFront;
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
 *  Free the object.
 */
-(void) dealloc
{
    [ivSeal release];
    ivSeal = nil;
    
    [swvFront release];
    swvFront = nil;
    
    [super dealloc];
}

/*
 *  Assign the seal color and image.
 */
-(void) setSealColor:(RSISecureSeal_Color_t) color withImage:(UIImage *) image
{
    // - apply the image.
    ivSeal.image = image;
    
    // - and the wax.
    [swvFront removeFromSuperview];
    [swvFront release];
    swvFront = nil;
    if (color != RSSC_INVALID) {
        swvFront                  = [[ChatSeal sealWaxInForeground:YES andColor:color] retain];
        swvFront.frame            = self.bounds;
        swvFront.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [swvFront setLocked:YES];
        [swvFront setCenterVisible:YES];
        [swvFront prepareForSmallDisplay];
        [self addSubview:swvFront];
        
        // - size the image.
        CGFloat centerDiam        = [swvFront centerDiameterFromCurrentBounds] - 2.0f;      // - to ensure the center ring always covers it.
        CGSize sz                 = self.bounds.size;
        ivSeal.frame              = CGRectIntegral(CGRectMake((sz.width-centerDiam)/2.0f, (sz.height-centerDiam)/2.0f, centerDiam, centerDiam));
        ivSeal.layer.cornerRadius = centerDiam/2.0f;
    }
}
@end


/*************************************
 UISealVaultSimpleSealView (internal)
 *************************************/
@implementation UISealVaultSimpleSealView (internal)
/*
 *  Configure the view.
 */
-(void) commonConfiguration
{
    // - basic attributes.
    self.backgroundColor    = [UIColor clearColor];
    self.clipsToBounds      = YES;
    
    // - the image view is pretty standard, but the wax will be created later.
    ivSeal                    = [[UIImageView alloc] initWithFrame:self.bounds];
    ivSeal.autoresizingMask   = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    ivSeal.contentMode        = UIViewContentModeScaleAspectFit;
    ivSeal.clipsToBounds      = YES;
    [self addSubview:ivSeal];
}
@end