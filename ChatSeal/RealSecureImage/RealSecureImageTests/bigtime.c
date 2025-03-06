//
//  bigtime.c
//  RealComics
//
//  Created by Francis Grolemund on 8/16/12.
//  Copyright (c) 2012 RealProven, LLC. All rights reserved.
//

#include <sys/time.h>
#include "bigtime.h"

/*
 *  Return the current clock value as a 64-bit value.
 */
bigtime_t btclock(void)
{
    struct timeval tv;
    
    gettimeofday(&tv, NULL);
    bigtime_t ret = ((bigtime_t) tv.tv_sec) * MICRO_IN_SEC;
    ret += (bigtime_t) tv.tv_usec;
    return ret;
}

/*
 *  Compute a big time value in seconds
 */
double btinsec(bigtime_t bt)
{
    return ((double)bt) / ((double)MICRO_IN_SEC);
}

