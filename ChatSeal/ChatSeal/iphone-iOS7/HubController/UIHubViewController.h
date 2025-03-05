//
//  UIHubViewController.h
//  ChatSeal
//
//  Created by Francis Grolemund on 9/20/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

// - the hub will look for view controllers that adopt this
//   protocol in order to notify them when they are going to be switched-to
@protocol UIHubManagedViewController <NSObject>
@optional
+(NSString *) currentTextForTabBadgeThatIsActive:(BOOL) isActive;
-(void) viewControllerWillBecomeActiveTab;
-(void) viewControllerDidBecomeActiveTab;
-(void) viewControllerShouldProcessApplicationURL:(NSURL *) url;
@end

@class ChatSealMessage;
@class UIVaultFailureOverlayView;
@interface UIHubViewController : UIViewController
-(void) setTabsVisible:(BOOL) isVisible withNewMessage:(ChatSealMessage *) psm forStartupDisplay:(BOOL) isForStartup;
-(BOOL) tabsAreVisible;
-(void) updateAlertBadges;
-(void) updateFeedAlertBadge;
-(UIViewController *) currentViewController;
-(CGFloat) tabBarHeight;
-(BOOL) isViewControllerTopOfTheHub:(UIViewController *) vc;
-(void) syncNavigationItemFromTopViewController:(UIViewController *) vc withAnimation:(BOOL) animated;
-(IBAction)doPrivacy:(id)sender;

@property (nonatomic, retain) IBOutlet UIView                    *vwContainer;
@property (nonatomic, retain) IBOutlet UIView                    *vwTabBG;
@property (nonatomic, retain) IBOutlet UITabBar                  *tbTabs;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint        *lcContainerHeight;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint        *lcLeftEdge;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint        *lcRightEdge;
@property (nonatomic, retain) IBOutlet UIVaultFailureOverlayView *vfoVaultOverlay;
@property (nonatomic, retain) IBOutlet UIButton                  *bPrivacy;
@end
