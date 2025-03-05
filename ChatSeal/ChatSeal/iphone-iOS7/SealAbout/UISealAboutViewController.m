//
//  UISealAboutViewController.m
//  ChatSeal
//
//  Created by Francis Grolemund on 1/16/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "UISealAboutViewController.h"
#import "ChatSeal.h"
#import "UISealAboutCell.h"

// - types
typedef enum {
    UISAVC_SEC_CRYPTO   = 0,
    UISAVC_SEC_DETAILS  = 1,
    
    UISAVC_NUM_SECTIONS
} uisavc_section_t;

typedef enum {
    UISAVC_CR_ROW_SYM   = 0,
    UISAVC_CR_ROW_PUB   = 1,
    UISAVC_CR_ROW_STEG  = 2,
    
    UISAVC_CR_NUM_ROWS
} uisavc_sec_crypto_t;

typedef enum {
    UISAVC_DET_ROW_SHARED  = 0,
    UISAVC_DET_ROW_EXPIRES = 1,
    UISAVC_DET_ROW_SENT    = 2,
    UISAVC_DET_ROW_RECV    = 3,
    
    UISAVC_DET_NUM_ROWS
} uisavc_sec_details_t;

// - forward declarations
@interface UISealAboutViewController (internal)
-(void) commonConfiguration;
@end

/*****************************
 UISealAboutViewController
 *****************************/
@implementation UISealAboutViewController
/*
 *  Object attributes
 */
{
    ChatSealIdentity *sealIdentity;
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
 *  Assign an identity to this screen.
 */
-(void) setIdentity:(ChatSealIdentity *) psi
{
    if (sealIdentity != psi) {
        [sealIdentity release];
        sealIdentity = [psi retain];
        [self.tableView reloadData];
    }
}
@end

/*************************************
 UISealAboutViewController (internal)
 *************************************/
@implementation UISealAboutViewController (internal)
/*
 *  Configure the view.
 */
-(void) commonConfiguration
{
    self.title = NSLocalizedString(@"About", nil);
}

/*
 *  Return the section count for this view.
 */
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return UISAVC_NUM_SECTIONS;
}

/*
 *  Return the section headers.
 */
-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case UISAVC_SEC_CRYPTO:
            return NSLocalizedString(@"Cryptography", nil);
            break;
            
        case UISAVC_SEC_DETAILS:
            return NSLocalizedString(@"General Details", nil);
            break;
            
        default:
            return nil;
            break;
    }
}

/*
 *  Return the number of rows in each section.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case UISAVC_SEC_CRYPTO:
            return UISAVC_CR_NUM_ROWS;
            break;
            
        case UISAVC_SEC_DETAILS:
            return UISAVC_DET_NUM_ROWS;
            break;
            
        default:
            return 0;
            break;
    }
}

/*
 *  Return the table view cell at the given location.
 */
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UISealAboutCell *sac  = [tableView dequeueReusableCellWithIdentifier:@"UISealAboutCell" forIndexPath:indexPath];
    sac.lDescription.text = nil;
    sac.lValue.text       = nil;
    
    if (indexPath.section == UISAVC_SEC_CRYPTO) {
        switch (indexPath.row) {
            case UISAVC_CR_ROW_SYM:
                sac.lDescription.text = NSLocalizedString(@"Chat Encryption", nil);
                sac.lValue.text       = NSLocalizedString(@"AES-256", nil);
                break;
                
            case UISAVC_CR_ROW_PUB:
                sac.lDescription.text = NSLocalizedString(@"RSA Key Length", nil);
                sac.lValue.text       = NSLocalizedString(@"2048 bits", nil);
                break;
                
            case UISAVC_CR_ROW_STEG:
                sac.lDescription.text = NSLocalizedString(@"Steganography", nil);
                sac.lValue.text       = NSLocalizedString(@"YES", nil);
                break;
                
            default:
                //  do nothing
                break;
        }
    }
    else if (indexPath.section == UISAVC_SEC_DETAILS) {
        NSDate *dtExpires = [sealIdentity nextExpirationDate];
        switch (indexPath.row) {
            case UISAVC_DET_ROW_SHARED:
                sac.lDescription.text = NSLocalizedString(@"Shared With Friends", nil);
                sac.lValue.text       = [NSString stringWithFormat:@"%lu", (unsigned long) [sealIdentity sealGivenCount]];
                break;
                
            case UISAVC_DET_ROW_EXPIRES:
                sac.lDescription.text = NSLocalizedString(@"Shared Expiration", nil);
                if (sealIdentity.sealGivenCount && dtExpires) {
                    NSCalendar *cal   = [NSCalendar currentCalendar];
                    NSUInteger expVal = [cal ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:dtExpires];
                    NSUInteger nowVal = [cal ordinalityOfUnit:NSDayCalendarUnit inUnit:NSEraCalendarUnit forDate:[NSDate date]];
                    NSString *sDate = nil;
                    if (expVal == nowVal) {
                        sDate = @"Today";
                    }
                    else if (expVal > nowVal && (expVal - 1) == nowVal) {
                        sDate = @"Tomorrow";
                    }
                    else {
                        sDate = [NSDateFormatter localizedStringFromDate:dtExpires dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
                    }
                    sac.lValue.text = sDate;
                }
                else {
                    sac.lValue.text = NSLocalizedString(@"N/A", nil);
                }
                break;
                
            case UISAVC_DET_ROW_SENT:
                sac.lDescription.text = NSLocalizedString(@"Messages Encrypted", nil);
                sac.lValue.text       = [NSString stringWithFormat:@"%lu", (unsigned long) [sealIdentity sentCount]];
                break;
                
            case UISAVC_DET_ROW_RECV:
                sac.lDescription.text = NSLocalizedString(@"Messages Decrypted", nil);
                sac.lValue.text       = [NSString stringWithFormat:@"%lu", (unsigned long) [sealIdentity recvCount]];
                break;
                
                
            default:
                //  do nothing
                break;
        }
    }
    return sac;
}

/*
 *  These rows are for display only.
 */
-(BOOL) tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}
@end