//
//  CS_tapi_download_image_toverify.h
//  ChatSeal
//
//  Created by Francis Grolemund on 5/31/14.
//  Copyright (c) 2014 RealProven, LLC. All rights reserved.
//

#import "CS_tapi_download_image.h"

//  NOTE: this is used in the transient queue to do do realtime checking of the content to
//        discard ones that are not useful.
@interface CS_tapi_download_image_toverify : CS_tapi_download_image
-(BOOL) isConfirmed;
-(BOOL) hasBeenAnalyzed;
-(void) markAsAnalyzed;
@end
