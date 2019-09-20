//
//  TSSC.h
//  TssTool
//
//  Created by User on 7/14/18.
//  Copyright © 2018 User. All rights reserved.
//

#include "TSSIO_iOS.h"
#include <plist/plist.h>

_Pragma("clang assume_nonnull begin")

static const size_t generatorBufferSize = 16 + 2 + 1;
typedef struct {
    // must be nonnull and valid.
    const char *deviceModel;
    const char *deviceBoardConfig;
    uint64_t ecid;  // if 0, random generate one.
    // pass {NULL, 0} for no nonce; pass {NULL, 1} for a new nonce; pass {const char *, length} for a specified nonce.
    TSSDataBuffer apnonce;
    TSSDataBuffer sepnonce;
    char *generator;    // must be nonnull
//    uint64_t basebandCertID;
//    size_t bbsnumSize;
} DeviceInfo_BridgedCStruct;

struct BuildIdentity {
    plist_t __nullable updateInstall;
    plist_t __nullable eraseInstall;
#ifdef __cplusplus
    BuildIdentity(plist_t __nullable _updateInstall = nullptr, plist_t __nullable _eraseInstall = nullptr) noexcept : updateInstall(_updateInstall), eraseInstall(_eraseInstall) {}
#endif
};
typedef struct BuildIdentity BuildIdentity;

#ifdef __cplusplus
extern "C" {
#endif

    int downloadPartialzip(const char *url, const char *file, TSSDataBuffer *__nullable dst/*pass null/nullptr if just check availability*/, TSSCustomUserData *__nullable userData);
    int isBuildIdentitySignedForDevice(const BuildIdentity *buildIdentity, DeviceInfo_BridgedCStruct *device, TSSDataBuffer *__nullable shshDataBuffer, TSSCustomUserData *__nullable userData);
    // 0 success.
    size_t apNonceLengthForDeviceModel(const char *deviceModel);
    size_t requiredSepNonceLengthForModel(const char *deviceModel);

#ifdef __cplusplus
}
#endif
_Pragma("clang assume_nonnull end")

