//
//  libfragmentzip.h
//  libfragmentzip
//
//  Created by tihmstar on 24.12.16.
//  Copyright © 2016 tihmstar. All rights reserved.
//

#ifndef libfragmentzip_h
#define libfragmentzip_h

#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include "TSSIO_iOS.h"

#define STATIC_INLINE static inline
#define ATTRIBUTE_PACKED __attribute__ ((packed))

#ifdef __cplusplus
extern "C"
{
#endif


typedef struct fragmentzip_info fragmentzip_t;
typedef void (*fragmentzip_process_callback_t)(unsigned int progress);
fragmentzip_t *fragmentzip_open(const char *url, TSSCustomUserData *userData);
//fragmentzip_t *fragmentzip_open_extended(const char *url, CURL *mcurl); //pass custom CURL with web auth by basic/digest or cookies

int fragmentzip_download_file(fragmentzip_t *info, const char *remotepath, TSSDataBuffer *buffer, fragmentzip_process_callback_t callback, TSSCustomUserData *userData);

//fragmentzip_cd *fragmentzip_getCDForPath(fragmentzip_t *info, const char *path);

void fragmentzip_close(fragmentzip_t *info);


#ifdef __cplusplus
}
#endif

#endif /* libfragmentzip_h */
