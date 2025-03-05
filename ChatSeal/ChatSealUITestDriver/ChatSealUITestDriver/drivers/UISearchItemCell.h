//
//  UISearchItemCell.h
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 11/5/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol UISearchItemCellDelegate <NSObject>
-(void) searchValueModified:(NSString *) searchValue;
@end

@interface UISearchItemCell : UITableViewCell
-(void) setSearchText:(NSString *) text;
-(NSString *) searchText;
@property (nonatomic, assign) id<UISearchItemCellDelegate> delegate;
@end
