//
//  RSI_appkey.h
//  RealSecureImage
//
//  Created by Francis Grolemund on 12/7/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSI_symcrypt.h"

//  - the purpose of the application key is to manage on-disk encryption.
@interface RSI_appkey : NSObject
+(BOOL) isInstalled;
+(NSUInteger) lengthOfSafeSaltedStringAsHex:(BOOL) asHex;
-(void) invalidateCredentials;
-(BOOL) isValid;

-(BOOL) destroyAllKeyDataWithError:(NSError **) err;

-(BOOL) createNewKeyWithPassword:(NSString *) password withError:(NSError **) err;
-(BOOL) authenticateWithPassword:(NSString *) password withError:(NSError **) err;
-(BOOL) changePasswordFrom:(NSString *) password toNewPassword:(NSString *) newpass withError:(NSError **) err;

//  - when using the key for encryption, start an explicit context
//    to make it more efficient for large numbers of operations.
-(BOOL) startKeyContextWithError:(NSError **) err;
-(BOOL) endKeyContextWithError:(NSError **) err;

-(BOOL) writeData:(NSData *) sourceData toURL:(NSURL *) url withError:(NSError **) err;
-(BOOL) readURL:(NSURL *) url intoData:(RSI_securememory **) destData withError:(NSError **) err;

-(NSString *) safeSaltedStringAsHex:(NSString *) source withError:(NSError **) err;
-(NSString *) safeSaltedStringAsBase64:(NSString *) source withError:(NSError **) err;

+(BOOL) destroyKeychainContentsWithError:(NSError **) err;

@end
