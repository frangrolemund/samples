//
//  UISealVaultCell.h
//  ChatSeal
//
//  Created by Francis Grolemund on 12/24/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UISealVaultSimpleSealView.h"
#import "UIGenericSizableTableViewCell.h"

@class ChatSealIdentity;
@class ChatSealVaultPlaceholder;
@interface UISealVaultCell : UIGenericSizableTableViewCell
+(void) registerCellForTable:(UITableView *) tv forCellReuseIdentifier:(NSString *) cellId;
-(void) configureCellWithIdentity:(ChatSealIdentity *) psi andShowDisclosureIndicator:(BOOL) showDisclosure;
-(void) updateStatsWithIdentity:(ChatSealIdentity *) psi andAnimation:(BOOL) animated;
-(void) setActiveSealDisplayOnSelection:(BOOL) enabled;
-(void) drawStylizedVersionWithPlaceholder:(ChatSealVaultPlaceholder *) ph;
+(CGFloat) standardCellHeight;
-(BOOL) doesCellContentChangeWithIdentity:(ChatSealIdentity *) psi;

@property (nonatomic, retain) IBOutlet UILabel *lOwnerName;
@property (nonatomic, retain) IBOutlet UISealVaultSimpleSealView *svSeal;
@property (nonatomic, retain) IBOutlet UILabel *lActivityTitle;
@property (nonatomic, retain) IBOutlet UILabel *lSentCount;
@property (nonatomic, retain) IBOutlet UILabel *lSentLabel;
@property (nonatomic, retain) IBOutlet UILabel *lRecvCount;
@property (nonatomic, retain) IBOutlet UILabel *lRecvLabel;
@property (nonatomic, retain) IBOutlet UILabel *lUnused;
@property (nonatomic, retain) IBOutlet UILabel *lStatus;
@end
