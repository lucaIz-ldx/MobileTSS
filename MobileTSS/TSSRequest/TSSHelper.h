//
//  TSSHelper.h
//  TssTool
//
//  Created by User on 7/9/18.
//  Copyright © 2018 User. All rights reserved.
//

#ifndef TSSHelper_h
#define TSSHelper_h

#ifdef __cplusplus
#include <cstdint>
#else
#include <stdint.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

int64_t parseECID(const char *ecid);
char *parseNonce(const char *nonce, size_t *parsedLen);
int parseHex(const char *nonce, size_t *parsedLen, char *ret, size_t *retSize);

#ifdef __cplusplus
}
#endif
#endif /* TSSHelper_h */
