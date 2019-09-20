//
//  LocalDeviceConstants.h
//  MobileTSS
//
//  Created by User on 10/11/18.
//

#ifndef LocalDeviceConstants_h
#define LocalDeviceConstants_h
#ifndef __cplusplus
#include <stdint.h>
#include <stddef.h>
#else
#include <cstdint>
#include <cstddef>
#endif
#ifdef __OBJC__
#import <Foundation/NSObjCRuntime.h>
#else
#define NS_SWIFT_UNAVAILABLE(a)
#endif
_Pragma("clang assume_nonnull begin")

// device hardware info; these info are same in all devices for same model.

struct DeviceInfo {
    const char *deviceModel;
    const char *deviceBoardConfiguration;
    uint64_t _basebandCertID;
    size_t _bbsnumSize;
//    const unsigned char *__nullable bbsnum;
//    unsigned int basebandChipID;
//    unsigned int basebandSerialNumber;
};
// DeviceInfo is designed to be immutable.
typedef const struct DeviceInfo * DeviceInfo_ptr;

#ifdef __cplusplus
extern "C" {
#endif
    DeviceInfo_ptr getLocalDeviceInfo(void);
    size_t apNonceLengthForLocalDevice(void);

    bool isNonceEntanglingEnabledForModel(const char *deviceModel);
    bool isCurrentDeviceNonceEntanglingEnabled(void);    // A12+

    DeviceInfo_ptr __nullable findDeviceInfoForSpecifiedModel(const char *deviceModel);
    DeviceInfo_ptr __nullable findDeviceInfoForSpecifiedConfiguration(const char *deviceConfiguration);
    void findAllDeviceInfosForSpecifiedModel(const char *deviceModel, DeviceInfo_ptr __nullable *__nonnull array, size_t arraySize) NS_SWIFT_UNAVAILABLE("");

    void updateDatabase(void);
//    void setLocalDeviceBasebandCertID(uint64_t certID);
//    void setLocalDeviceBasebandSerialNumberSize(size_t size);
//    bool hasCellularCapability(void);
#ifdef __cplusplus
}
#endif

_Pragma("clang assume_nonnull end")
#endif /* LocalDeviceConstants_h */
