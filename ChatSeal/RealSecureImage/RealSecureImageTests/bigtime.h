//
//  bigtime.h
//  RealComics
//
//  Created by Francis Grolemund on 8/16/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#ifndef RealComics_bigtime_h
#define RealComics_bigtime_h

typedef unsigned long long bigtime_t;
#define MICRO_IN_SEC (bigtime_t) 1000000

extern bigtime_t btclock(void);
extern double btinsec(bigtime_t bt);

#endif
