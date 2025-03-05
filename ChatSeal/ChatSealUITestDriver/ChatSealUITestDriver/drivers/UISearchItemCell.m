//
//  UISearchItemCell.m
//  ChatSealUITestDriver
//
//  Created by Francis Grolemund on 11/5/13.
//  Copyright (c) 2013 Francis Grolemund. All rights reserved.
//

#import "UISearchItemCell.h"

// - forward declarations
@interface UISearchItemCell (internal) <UISearchBarDelegate>
@end

/*********************
 UISearchItemCell
 *********************/
@implementation UISearchItemCell
/*
 *  Object attributes
 */
{
    
}
@synthesize delegate;

/*
 *  Initialize the object.
 */
-(id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        UISearchBar *sb = (UISearchBar *) [self viewWithTag:100];
        sb.delegate     = self;
        sb.placeholder  = @"Search";
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    delegate = nil;
    [super dealloc];
}

/*
 *  Assign a value to the search text.
 */
-(void) setSearchText:(NSString *) text
{
    UISearchBar *sb = (UISearchBar *) [self viewWithTag:100];
    sb.text         = text;
}

/*
 *  Retrieve the current search text.
 */
-(NSString *) searchText
{
    UISearchBar *sb = (UISearchBar *) [self viewWithTag:100];
    return sb.text;
}
@end


/***************************
 UISearchItemCell (internal)
 ***************************/
@implementation UISearchItemCell (internal)
/*
 *  When the text is changed in the search bar, this is invoked.
 */
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (delegate) {
        [delegate performSelector:@selector(searchValueModified:) withObject:searchText];
    }
}

-(void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

@end
