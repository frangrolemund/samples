//
//  CS_messageEntryExport.h
//  ChatSeal
//
//  Created by Francis Grolemund on 6/12/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSealMessageEntry.h"

@class RSISecureSeal;
@interface CS_messageEntryExport : NSObject
@property (nonatomic, retain) RSISecureSeal       *seal;
@property (nonatomic, retain) NSMutableDictionary *exportedContent;
@property (nonatomic, retain) UIImage             *decoy;
@property (nonatomic, retain) NSUUID              *entryUUID;
@property (nonatomic, retain) NSURL               *uCachedItem;
@property (nonatomic, retain) NSData              *dCachedExported;
@end