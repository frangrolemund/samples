//
//  AlertManager.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/24/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "AlertManager.h"
#import "ChatSeal.h"

@implementation AlertManager
/*
 * Display an alert when errors occur.
 */
+(UIAlertView *) displayErrorAlertWithTitle:(NSString *) title andText:(NSString *) text
{
    return [AlertManager displayErrorAlertWithTitle:title andText:text andDelegate:nil];
}

/*
 * Display an alert when errors occur.
 */
+(UIAlertView *) displayErrorAlertWithTitle:(NSString *) title andText:(NSString *) text andDelegate:(id<UIAlertViewDelegate>) delegate
{
    UIAlertView * (^alertBlock)() = ^(){
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:text delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles: nil];
        av.delegate     = delegate;
        [av show];
        return [av autorelease];
    };
    
    // - ensure this always happens on the main thread or we'll hang!
    if ([[NSThread mainThread] isEqual:[NSThread currentThread]]) {
        return alertBlock();
    }
    else {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^(void) {
            alertBlock();
        }];
        return nil;
    }
}

/*
 *  Return the message that should be displayed when storage is low.
 */
+(NSString *) standardLowStorageMessage
{
    NSString *model = [[UIDevice currentDevice] model];
    return [NSString stringWithFormat:NSLocalizedString(@"Your %@'s storage is almost full.  You can manage it in Settings under General/Usage.", nil), model];
}

/*
 *  Return the text in a standard form, assuming a replaceable device argument.
 */
+(NSString *) standardErrorTextWithText:(NSString *) text
{
    if ([ChatSeal isLowStorageAConcern]) {
        text = [AlertManager standardLowStorageMessage];
    }
    else {
        NSString *model = [[UIDevice currentDevice] model];
        text            = [NSString stringWithFormat:text, model];
        text            = [NSString stringWithFormat:@"%@  Please try again the next time you restart this device.", text];
    }
    return text;
}

/*
 *  Display a common low-space aware alerat message.
 */
+(void) displayFatalAlertWithLowSpaceDetectionUsingTitle:(NSString *) title andText:(NSString *) text
{
    text = [AlertManager standardErrorTextWithText:text];
    [AlertManager displayErrorAlertWithTitle:title andText:text];
}

@end
