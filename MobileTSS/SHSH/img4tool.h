//
//  img4tool.h
//  futurerestore
//
//  Created by tihmstar on 03.09.16.
//  Copyright © 2016 tihmstar. All rights reserved.
//

#ifndef img4tool_h
#define img4tool_h

#import "TSSIO_iOS.h"

#ifdef __cplusplus
extern "C" {
#endif

TSSDataBuffer readDataBufferFromFile(const char *filePath);
int verifyGenerator(const char *im4mBuffer, const char *generator, TSSCustomUserData *userData);
    
#ifdef __cplusplus
}
#endif
    
#endif /* img4tool_h */
