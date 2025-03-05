//
//  CS_cacheSeal.h
//  ChatSeal
//
//  Created by Francis Grolemund on 10/21/13.
//  Copyright (c) 2013 RealProven, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RealSecureImage/RealSecureImage.h"

// types
typedef enum {
    PHSCSP_RR_STILL_VALID = 0,
    PHSCSP_RR_EXPIRED,
    PHSCSP_RR_REVOKED
} phs_cacheSeal_revoke_reason_t;

@interface CS_cacheSeal : NSObject
+(void) precacheSealForId:(NSString *) sealId;
+(CS_cacheSeal *) retrieveAndCacheSealForId:(NSString *) sealId usingSecureSecureObject:(RSISecureSeal *) secureSeal;
+(void) releaseAllCachedContent;
+(void) forceCacheRecreation;
+(CS_cacheSeal *) sealForId:(NSString *) sealId;
+(CS_cacheSeal *) sealForSafeId:(NSString *) safeId;
+(void) discardSealForId:(NSString *) sealId;
+(UIImage *) sealMissingTableImage;
+(NSArray *) availableSealsWithError:(NSError **) err;
+(void) recacheSeal:(RSISecureSeal *) ss;

-(NSString *) sealId;
-(NSString *) safeSealId;
-(BOOL) isKnown;
-(BOOL) isOwned;
-(RSISecureSeal_Color_t) color;
-(UIImage *) safeImage;
-(UIImage *) tableImage;
-(UIImage *) vaultImage;
-(void) validate;
-(NSUInteger) sealExpirationTimoutInDaysWithError:(NSError **) err;
-(BOOL) setExpirationTimeoutInDays:(NSUInteger) days withError:(NSError **) err;
-(phs_cacheSeal_revoke_reason_t) getRevoked;
-(BOOL) isValid;
-(phs_cacheSeal_revoke_reason_t) checkForRevocationWithScreenshotTaken;
-(BOOL) isRevocationOnScreenshotEnabledWithError:(NSError **) err;
-(BOOL) setRevokeOnScreenshotEnabled:(BOOL) enabled withError:(NSError **) err;
-(phs_cacheSeal_revoke_reason_t) checkForExpiration;
-(BOOL) setExpirationDate:(NSDate *) dtExpires withError:(NSError **) err;
@end
