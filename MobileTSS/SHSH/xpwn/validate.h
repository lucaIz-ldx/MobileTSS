//
//  validate.h
//  MobileTSS
//
//  Created by User on 1/22/19.
//

#ifndef validate_h
#define validate_h

#include "TSSIO_iOS.h"
#include <plist/plist.h>

int verifyIMG3WithIdentity(plist_t shshDict, plist_t buildIdentity, TSSCustomUserData *userData);

#endif /* validate_h */
