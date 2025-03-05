//
//  ChatSealWeakOperation.h
//  ChatSeal
//
//  Created by Francis Grolemund on 4/26/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

//  - this is designed for a block to check its own operation without
//    introducing a retain cycle.
@interface ChatSealWeakOperation : NSObject
+(ChatSealWeakOperation *) weakOperationWrapper;
-(id) initWithOperation:(NSOperation *) opToSave;
-(BOOL) isCancelled;
-(void) setOperation:(NSOperation *) opToSave;
-(NSOperation *) operation;
@end
