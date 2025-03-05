//
//  ChatSealRemoteIdentity.h
//  ChatSeal
//
//  Created by Francis Grolemund on 1/23/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ChatSealRemoteIdentity;
@protocol ChatSealRemoteIdentityDelegate <NSObject>
@optional
-(void) remoteIdentityTransferStarted:(ChatSealRemoteIdentity *) identity;
-(void) remoteIdentityTransferFailed:(ChatSealRemoteIdentity *) identity withError:(NSError *) err;
-(void) remoteIdentityTransferProgress:(ChatSealRemoteIdentity *) identity withPercentageDone:(NSNumber *) pctComplete;
-(void) remoteIdentityBeginningImport:(ChatSealRemoteIdentity *) identity;
-(void) remoteIdentityTransferCompletedSuccessfully:(ChatSealRemoteIdentity *) identity withSealId:(NSString *) sealId;
-(void) remoteIdentityTransferCompletedWithDuplicateSeal:(ChatSealRemoteIdentity *) identity withSealId:(NSString *) sealId;
@end

@interface ChatSealRemoteIdentity : NSObject <ChatSealRemoteIdentityDelegate>
-(BOOL) beginSecureImportProcessing:(NSError **) err;
-(BOOL) isComplete;
-(NSURL *) secureURL;

@property (nonatomic, assign) id<ChatSealRemoteIdentityDelegate> delegate;
@end
