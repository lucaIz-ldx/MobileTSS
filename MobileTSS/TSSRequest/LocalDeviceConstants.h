//
//  LocalDeviceConstants.h
//  MobileTSS
//
//  Created by User on 10/11/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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

// All DeviceInfo_ptr values from these functions are valid during lifetime of program.
DeviceInfo_ptr getLocalDeviceInfo(void);

DeviceInfo_ptr __nullable findDeviceInfoForSpecifiedModel(const char *deviceModel);
DeviceInfo_ptr __nullable findDeviceInfoForSpecifiedConfiguration(const char *deviceConfiguration);
void findAllDeviceInfosForSpecifiedModel(const char *deviceModel, DeviceInfo_ptr __nullable *__nonnull array, size_t arraySize) NS_SWIFT_UNAVAILABLE("use findAllDeviceConfigurationsForSpecifiedModel:");

NSArray<NSString *> *getAllKnownDeviceModels(void);
NSArray<NSString *> *findAllDeviceConfigurationsForSpecifiedModel(NSString *deviceModel);

void updateDatabase(void);
NS_ASSUME_NONNULL_END
