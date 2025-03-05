//
//  tdriverMessageBubbleViewController.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 7/10/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealedMessageBubbleViewV2.h"

@interface tdriverMessageBubbleViewController : UIViewController

@property (nonatomic, retain) IBOutlet UISealedMessageBubbleViewV2 *smbvLeft;
@property (nonatomic, retain) IBOutlet UISealedMessageBubbleViewV2 *smbvRight;
@property (nonatomic, retain) IBOutlet UISealedMessageBubbleViewV2 *smbvSmall;
@property (nonatomic, retain) IBOutlet UISealedMessageBubbleViewV2 *smbvImage;
@property (nonatomic, retain) IBOutlet UISealedMessageBubbleViewV2 *smbvSmall2;
@property (nonatomic, retain) IBOutlet UISealedMessageBubbleViewV2 *smbvSmall3;
@end
