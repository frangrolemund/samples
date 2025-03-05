//
//  UITransformView.m
//  ChatSeal
//
//  Created by Francis Grolemund on 10/13/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "UITransformView.h"

// - the quiet transform layer doesn't emit warnings
//   when attached to the view.
@interface CAQuietTransformLayer : CATransformLayer
@end

/***************************
 UITransformView
 ***************************/
@implementation UITransformView
/*
 *  The only purpose of this view is to host the quiet transform layer.
 */
+(Class) layerClass
{
    return [CAQuietTransformLayer class];
}
@end

/***************************
 CAQuietTransformLayer
 ***************************/
@implementation CAQuietTransformLayer

/*
 *  This isn't supported and we don't want the warnings.
 */
-(void) setBackgroundColor:(CGColorRef)backgroundColor
{
}

/*
 *  This isn't supported and we don't want the warnings.
 */
-(void) setOpaque:(BOOL)opaque
{
}
@end