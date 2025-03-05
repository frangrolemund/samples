//
//  UISealShareDisplayView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 2/25/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealShareDisplayView.h"
#import "ChatSeal.h"
#import "UINewSealCell.h"

// - forward declarations.
@interface UISealShareDisplayView (internal)
-(void) commonConfiguration;
@end

/************************
 UISealShareDisplayView
 ************************/
@implementation UISealShareDisplayView
/*
 *  Object attributes
 */
{
    ChatSealIdentity *psiSeal;
    UINewSealCell    *sealView;
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
    [sealView release];
    sealView = nil;
    
    [psiSeal release];
    psiSeal = nil;
    
    [super dealloc];
}

/*
 *  Assign an identity to this view for display.
 */
-(void) setIdentity:(ChatSealIdentity *) identity
{
    if (identity != psiSeal) {
        [psiSeal release];
        psiSeal = [identity retain];
        
        [sealView removeFromSuperview];
        [sealView release];
        sealView = nil;
        
        // - NOTE: using a seal cell is important here to get the right kind of rotation behavior.  Just using a plain wax
        //         view will ultimately cause problems during rotations of the device and it won't be in synch with the
        //         rotation animation.
        sealView                  = [[ChatSeal sealCellForId:psiSeal.sealId andHeight:CGRectGetHeight(self.bounds)] retain];
        [sealView flagAsSimpleImageDisplayOnly];            // - otherwise rotation animations are wonky.
        sealView.frame            = self.bounds;
        sealView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self addSubview:sealView];
    }
}

/*
 *  Lock/unlock the seal.
 */
-(void) setLocked:(BOOL) isLocked
{
    [sealView setLocked:isLocked];
}
@end

/***********************************
 UISealShareDisplayView (internal)
 ***********************************/
@implementation UISealShareDisplayView (internal)
/*
 *  Configure the object.
 */
-(void) commonConfiguration
{
    psiSeal              = nil;
    sealView             = nil;
    self.backgroundColor = [UIColor clearColor];
}
@end