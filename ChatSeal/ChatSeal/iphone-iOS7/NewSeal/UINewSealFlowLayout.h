//
//  UINewSealFlowLayout.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/6/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol UICollectionViewDelegateSealFlowLayout <UICollectionViewDelegateFlowLayout>
-(CGPoint) workingCenterOfView;
@end

@interface UINewSealFlowLayout : UICollectionViewFlowLayout

@end
