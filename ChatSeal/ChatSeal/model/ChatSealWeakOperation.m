//
//  ChatSealWeakOperation.m
//  ChatSeal
//
//  Created by Francis Grolemund on 4/26/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import "ChatSealWeakOperation.h"

/****************************
 ChatSealWeakOperation
 ****************************/
@implementation ChatSealWeakOperation
/*
 *  Attribute declarations.
 */
{
    NSOperation *op;
}

/*
 *  Allocate a new temporary weak operation wrapper in the autorelease pool.
 */
+(ChatSealWeakOperation *) weakOperationWrapper
{
    return [[[ChatSealWeakOperation alloc] init] autorelease];
}

/*
 *  Initialize the object.
 */
-(id) init
{
    self = [super init];
    if (self) {
        op = nil;
    }
    return self;
}

/*
 *  Initialize the object.
 */
-(id) initWithOperation:(NSOperation *) opToSave
{
    self = [super init];
    if (self) {
        //  - the reference is weak, meaning it is not retained.
        op = opToSave;
    }
    return self;
}

/*
 *  Free the object.
 */
-(void) dealloc
{
    op = nil;
    [super dealloc];
}

/*
 *  Returns whether the op is cancelled.
 */
-(BOOL) isCancelled
{
    return [op isCancelled];
}

/*
 *  Set the value of the internal operation.
 */
-(void) setOperation:(NSOperation *) opToSave
{
    //  weak == not retained
    op = opToSave;
}

/*
 *  Return the operation handle.
 */
-(NSOperation *) operation
{
    return op;
}

@end
