/*
 * libMobileGestalt header.
 * Mobile gestalt functions as a QA system. You ask it a question, and it gives you the answer! :)
 *
 * Copyright (c) 2013-2014 Cykey (David Murray)
 * All rights reserved.
 */

#ifndef LIBMOBILEGESTALT_H_
#define LIBMOBILEGESTALT_H_

#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif
#pragma mark - API

    CF_RETURNS_RETAINED CFPropertyListRef __nullable MGCopyAnswer(CFStringRef __nonnull property);

#ifdef __cplusplus
}
#endif

#endif /* LIBMOBILEGESTALT_H_ */
