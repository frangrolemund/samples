//
//  UISealedMessageExportConfigData.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/8/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIMessageDetailViewControllerV2.h"
#import "UISealedMessageEnvelopeViewV2.h"
#import "ChatSealMessage.h"
#import "ChatSealFeed.h"

// - this class conveys information about the item being sealed, but also some animation properties that allows for
//   a natural transition between the two views.
@interface UISealedMessageExportConfigData : NSObject
@property (nonatomic, assign) UIMessageDetailViewControllerV2             *caller;                          //  the view that opened the export view.
@property (nonatomic, retain) NSArray                                     *items;                           //  the data to seal.
@property (nonatomic, retain) ChatSealFeed                                *targetFeed;                      //  the feed to receive the message.
@property (nonatomic, assign) id<UIMessageDetailViewControllerV2Delegate> delegate;                         //  to receive the completion status
@property (nonatomic, retain) ChatSealMessage                             *message;                         //  the current message, if it exists
@property (nonatomic, retain) ChatSealMessageEntry                        *appendedEntry;                   //  if we're appending, this is the added entry.
@property (nonatomic, assign) ps_message_type_t                           messageType;                      //  the type of message to generate.
@property (nonatomic, assign) BOOL                                        keyboardIsVisible;                //  if the keyboard is being shown.
@property (nonatomic, assign) BOOL                                        messageIsNew;                     //  whether the message was just created.
@property (nonatomic, retain) NSString                                    *preferredSealId;                 //  when a message is not available, use this seal instead of the default.
@property (nonatomic, retain) NSString                                    *detailActiveItem;                //  the text that was active when we sealed.
@end
