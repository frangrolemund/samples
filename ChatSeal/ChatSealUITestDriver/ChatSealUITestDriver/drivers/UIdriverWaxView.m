//
//  UIdriverWaxView.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 8/14/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIdriverWaxView.h"
#import "UISealWaxViewV2.h"

/**************************
 UIdriverWaxView
 **************************/
@implementation UIdriverWaxView
/*
 *  Object attributes.
 */
{
    UISealWaxViewV2 *waxViewFront;
    UIImageView    *ivFace;
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        self.layer.borderColor = [[UIColor blackColor] CGColor];
        self.layer.borderWidth = 1.0f;
        
        ivFace = [[UIImageView alloc] init];
        ivFace.clipsToBounds = YES;
        ivFace.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:ivFace];        
        
        waxViewFront = [[UISealWaxViewV2 alloc] init];
        [self addSubview:waxViewFront];
        [waxViewFront setOuterColor:[UIColor colorWithRed:150.0f/255.0f green:172.0f/255.0f blue:183.0f/255.0f alpha:1.0f]
                        andMidColor:[UIColor colorWithRed:65.0f/255.0f green:68.0f/255.0f blue:75.0f/255.0f alpha:1.0f]
                      andInnerColor:[UIColor colorWithRed:205.0f/255.0f green:206.0f/255.0f blue:213.0f/255.0f alpha:1.0f]];
        [self setLocked:[waxViewFront locked]];
    }
    return self;
}

/*
 * Free the view.
 */
-(void) dealloc
{
    [waxViewFront release];
    waxViewFront = nil;
    
    [ivFace release];
    ivFace = nil;
    
    [super dealloc];
}

/*
 *  Do post-layout activities.
 */
-(void) layoutSubviews
{
    [super layoutSubviews];
    
    //  - make sure the sub-views stay in synch
    waxViewFront.frame = self.bounds;
    
    CGFloat side  = [waxViewFront centerDiameterFromCurrentBounds];
    ivFace.bounds = CGRectMake(0.0f, 0.0f, side, side);
    ivFace.center = CGPointMake(CGRectGetWidth(self.bounds)/2.0f, CGRectGetHeight(self.bounds)/2.0f);
    ivFace.layer.cornerRadius = side/2.0f;
    
    // - scale the face image precisely
    UIImage *img = [UIImage imageNamed:@"sample-face.jpg"];
    CGSize szOrig = img.size;
    CGFloat ar = szOrig.width / szOrig.height;
    if (szOrig.height < szOrig.width) {
        szOrig.width = side * ar;
        szOrig.height = side;
    }
    else {
        szOrig.height = side / ar;
        szOrig.width  = side;
    }
    CGSize scaledSize = CGSizeMake(szOrig.width * [UIScreen mainScreen].scale, szOrig.height * [UIScreen mainScreen].scale);
    UIGraphicsBeginImageContextWithOptions(scaledSize, YES, 1.0f);
    [img drawInRect:CGRectMake(0.0f, 0.0f, scaledSize.width, scaledSize.height)];
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    ivFace.image = img;
}

/*
 *  Lock/unlock the item.
 */
-(void) setLocked:(BOOL) isLocked
{
    waxViewFront.locked = isLocked;
}

/*
 *  Return the current locked state.
 */
-(BOOL) locked
{
    return waxViewFront.locked;
}

/*
 *  When showing a small seal, use the small display feature to get better quality.
 */
-(void) prepareForSmallDisplay
{
    [waxViewFront prepareForSmallDisplay];
}

-(void) drawForDecoyRect:(CGRect) rc
{
    [waxViewFront drawForDecoyRect:rc];
}

@end
