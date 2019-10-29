//
//  LocalDeviceConstants.mm
//  MobileTSS
//
//  Created by User on 10/11/18.
//
#include "LocalDeviceConstants.h"

#import <Foundation/Foundation.h>
//#import <ifaddrs.h>
#import "MobileGestalt.h"

namespace {
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wunused-variable"
//    const CFStringRef kMGBasebandCertId = CFSTR("BasebandCertId");
//    const CFStringRef kMGChipID = CFSTR("ChipID");
//    const CFStringRef kMGBoardId = CFSTR("BoardId");
//    const CFStringRef kMGFirmwarePreflightInfo = CFSTR("FirmwarePreflightInfo");
    const CFStringRef kMGProductType = CFSTR("ProductType");
#if !TARGET_IPHONE_SIMULATOR
    const CFStringRef kMGHWModel = CFSTR("HWModelStr");
#endif
//    const CFStringRef kMGHasBaseband = CFSTR("HasBaseband");

    // unused.
//    const CFStringRef kMGBasebandSerialNumber = CFSTR("BasebandSerialNumber");
//    const CFStringRef kMGFirmwareNonce = CFSTR("FirmwareNonce");
//#pragma clang diagnostic pop
    static const int Unknown = 0;
    static const DeviceInfo localDatabase[] = {

        {"iPhone2,1", "n88ap", Unknown, Unknown},
        {"iPhone3,1", "n90ap", 257, 12},
        {"iPhone3,2", "n90bap", 257, 12},
        {"iPhone3,3", "n92ap", 2, 4},
        {"iPhone4,1", "n94ap", 2, 4},
        {"iPhone5,1", "n41ap", 3255536192, 4},
        {"iPhone5,2", "n42ap", 3255536192, 4},
        {"iPhone5,3", "n48ap", 3554301762, 4},
        {"iPhone5,4", "n49ap", 3554301762, 4},
        {"iPhone6,1", "n51ap", 3554301762, 4},
        {"iPhone6,2", "n53ap", 3554301762, 4},
        {"iPhone7,1", "n56ap", 3840149528, 4},
        {"iPhone7,2", "n61ap", 3840149528, 4},
        {"iPhone8,1", "n71ap", 3840149528, 4},
        {"iPhone8,1", "n71map", 3840149528, 4},
        {"iPhone8,2", "n66ap", 3840149528, 4},
        {"iPhone8,2", "n66map", 3840149528, 4},
        {"iPhone8,4", "n69ap", 3840149528, 4},
        {"iPhone8,4", "n69uap", 3840149528, 4},
        {"iPhone9,1", "d10ap", 2315222105, 4},
        {"iPhone9,2", "d11ap", 2315222105, 4},
        {"iPhone9,3", "d101ap", 1421084145, 12},
        {"iPhone9,4", "d111ap", 1421084145, 12},
        {"iPhone10,1", "d20ap", 2315222105, 4},
        {"iPhone10,2", "d21ap", 2315222105, 4},
        {"iPhone10,3", "d22ap", 2315222105, 4},
        {"iPhone10,4", "d201ap", 524245983, 12},
        {"iPhone10,5", "d211ap", 524245983, 12},
        {"iPhone10,6", "d221ap", 524245983, 12},

        {"iPhone11,2", "d321ap", 165673526, 12},
        {"iPhone11,4", "d331ap", 165673526, 12},
        {"iPhone11,6", "d331pap", 165673526, 12},
        {"iPhone11,8", "n841ap", 165673526, 12},

        {"iPhone12,1", "n104ap", Unknown, Unknown},
        {"iPhone12,3", "d421ap", Unknown, Unknown},
        {"iPhone12,5", "d431ap", Unknown, Unknown},


        {"iPod1,1", "n45ap", 0, 0},
        {"iPod2,1", "n72ap", 0, 0},
        {"iPod3,1", "n18ap", 0, 0},
        {"iPod4,1", "n81ap", 0, 0},
        {"iPod5,1", "n78ap", 0, 0},
        {"iPod7,1", "n102ap", 0, 0},
        {"iPod9,1", "n112ap", 0, 0},

        {"iPad1,1", "k48ap", 0, 0},
        {"iPad2,1", "k93ap", 0, 0},
        {"iPad2,2", "k94ap", 257, 12},
        {"iPad2,3", "k95ap", 257, 12},
        {"iPad2,4", "k93aap", 0, 0},
        {"iPad2,5", "p105ap", 0, 0},
        {"iPad2,6", "p106ap", 3255536192, 4},
        {"iPad2,7", "p107ap", 3255536192, 4},

        {"iPad3,1", "j1ap", 0, 0},
        {"iPad3,2", "j2ap", 4, 4},
        {"iPad3,3", "j2aap", 4, 4},
        {"iPad3,4", "p101ap", 0, 0},
        {"iPad3,5", "p102ap", 3255536192, 4},
        {"iPad3,6", "p103ap", 3255536192, 4},
        {"iPad4,1", "j71ap", 0, 0},
        {"iPad4,2", "j72ap", 3554301762, 4},
        {"iPad4,3", "j73ap", 3554301762, 4},
        {"iPad4,4", "j85ap", 0, 0},
        {"iPad4,5", "j86ap", 3554301762, 4},
        {"iPad4,6", "j87ap", 3554301762, 4},
        {"iPad4,7", "j85map", 0, 0},
        {"iPad4,8", "j86map", 3554301762, 4},
        {"iPad4,9", "j87map", 3554301762, 4},

        {"iPad5,1", "j96ap", 0, 0},
        {"iPad5,2", "j97ap", 3840149528, 4},
        {"iPad5,3", "j81ap", 0, 0},
        {"iPad5,4", "j82ap", 3840149528, 4},
        {"iPad6,3", "j127ap", 0, 0},
        {"iPad6,4", "j128ap", 3840149528, 4},
        {"iPad6,7", "j98aap", 0, 0},
        {"iPad6,8", "j99aap", 3840149528, 4},

        {"iPad6,11", "j71sap", 0, 0},
        {"iPad6,11", "j71tap", 0, 0},
        {"iPad6,12", "j72sap", 3840149528, 4},
        {"iPad6,12", "j72tap", 3840149528, 4},
        {"iPad7,1", "j120ap", 0, 0},
        {"iPad7,2", "j121ap", 2315222105, 4},
        {"iPad7,3", "j207ap", 0, 0},
        {"iPad7,4", "j208ap", 2315222105, 4},

        {"iPad7,5", "j71bap", 0, 0},
        {"iPad7,6", "j72bap", 3840149528, 4},
        {"iPad7,11", "j172ap", 0, 0},
        {"iPad7,12", "j171ap", Unknown, Unknown},

        {"iPad8,1", "j317ap", 0, 0},
        {"iPad8,2", "j317xap", 0, 0},
        {"iPad8,3", "j318ap", 165673526, 12},
        {"iPad8,4", "j318xap", 165673526, 12},
        {"iPad8,5", "j320ap", 0, 0},
        {"iPad8,6", "j320xap", 0, 0},
        {"iPad8,7", "j321ap", 165673526, 12},
        {"iPad8,8", "j321xap", 165673526, 12},

        {"iPad11,1", "j210ap", 0, 0},
        {"iPad11,2", "j211ap", 165673526, 12},
        {"iPad11,3", "j217ap", 0, 0},
        {"iPad11,4", "j218ap", 165673526, 12},

        {"AppleTV2,1", "k66ap", 0, 0},
        {"AppleTV3,1", "j33ap", 0, 0},
        {"AppleTV3,2", "j33iap", 0, 0},
        {"AppleTV5,3", "j42dap", 0, 0},
        {"AppleTV6,2", "j105aap", 0, 0},
    };
}
template <typename ObjcType>
static inline ObjcType transferToObjcFromMGAnswer(CFStringRef property) {
    return (__bridge_transfer ObjcType)MGCopyAnswer(property);
}
static char *getBufferFromMGAnswer(CFStringRef property, NSString * (^processBlock) (NSString *) = nil) {
    NSString *getAnswer = transferToObjcFromMGAnswer<NSString *>(property);
    if (!getAnswer) {
        return nil;
    }
    if (processBlock) {
        getAnswer = processBlock(getAnswer);
    }
    auto buffer = new char[getAnswer.length + 1];
    [getAnswer getCString:buffer maxLength:getAnswer.length + 1 encoding:NSASCIIStringEncoding];
    return buffer;
}
static DeviceInfo info;
const DeviceInfo *getLocalDeviceInfo(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        info.deviceModel = getBufferFromMGAnswer(kMGProductType);
#if TARGET_IPHONE_SIMULATOR
        for (auto &deviceInfo : localDatabase) {
            if (strcmp(info.deviceModel, deviceInfo.deviceModel) == 0) {
                delete [] info.deviceModel;
                info = deviceInfo;
            }
        }
#else
        info.deviceBoardConfiguration = getBufferFromMGAnswer(kMGHWModel, ^(NSString *str) {return str.lowercaseString;});
#endif
        if (info.deviceModel == nullptr || info.deviceBoardConfiguration == nullptr) {
            // app cannot run without essential information.
            throw "Cannot fetch current model.";
        }

        // Do not expect to get info from simulators.
//        auto basebandID = transferToObjcFromMGAnswer<NSNumber *>(kMGBasebandCertId);
//        NSData *bbsnum = transferToObjcFromMGAnswer<NSDictionary *>(kMGFirmwarePreflightInfo)[@"ChipSerialNo"];
//        info.basebandCertID = basebandID.unsignedLongLongValue;
//        info.bbsnumSize = bbsnum.length;
        /*
        if (!info.basebandCertID && transferToObjcFromMGAnswer<NSNumber *>(kMGHasBaseband).boolValue) {
            NSLog(@"Cannot retrieve baseband info from device. Probably executable is not entitled.");
            // if we fail to retrieve baseband info from device, try to find in local database at first.
            for (auto &deviceInfo : localDatabase) {
                if (strcmp(info.deviceModel, deviceInfo.deviceModel) == 0) {
#ifdef TARGET_IPHONE_SIMULATOR
                    delete [] info.deviceModel;
                    delete [] info.deviceBoardConfiguration;
                    info = deviceInfo;
#else
                    info.basebandCertID = deviceInfo.basebandCertID;
                    info.bbsnumSize = deviceInfo.bbsnumSize;
#endif
                    break;
                }
            }
        }
         */
    });
    return &info;
}
DeviceInfo_ptr findDeviceInfoForSpecifiedModel(const char *deviceModel) {
    if (strcmp(getLocalDeviceInfo()->deviceModel, deviceModel) == 0) {
        return &info;
    }
    for (auto &deviceInfo : localDatabase) {
        if (strcmp(deviceModel, deviceInfo.deviceModel) == 0) {
            return &deviceInfo;
        }
    }
    return nullptr;
}
DeviceInfo_ptr __nullable findDeviceInfoForSpecifiedConfiguration(const char *deviceConfiguration) {
    if (strcmp(getLocalDeviceInfo()->deviceBoardConfiguration, deviceConfiguration) == 0) {
        return &info;
    }
    for (auto &deviceInfo : localDatabase) {
        if (strcmp(deviceConfiguration, deviceInfo.deviceBoardConfiguration) == 0) {
            return &deviceInfo;
        }
    }
    return nullptr;
}
void findAllDeviceInfosForSpecifiedModel(const char *deviceModel, DeviceInfo_ptr *array, size_t arraySize) {
    int index = 0;
    for (auto &deviceInfo : localDatabase) {
        if (strcmp(deviceModel, deviceInfo.deviceModel) == 0) {
            if (index >= arraySize) {
                break;
            }
            array[index++] = &deviceInfo;
        }
    }
}
bool isNonceEntanglingEnabledForModel(const char *deviceModel) {
    char deviceModelNumber[10] = {0};
    if (strstr(deviceModel, "iPhone") == deviceModel) {
        strcpy(deviceModelNumber, deviceModel + strlen("iPhone"));
        *index(deviceModelNumber, ',') = '\0';
        return atoi(deviceModelNumber) >= 11;
    }
    if (strstr(deviceModel, "iPad") == deviceModel) {
        strcpy(deviceModelNumber, deviceModel + strlen("iPad"));
        *index(deviceModelNumber, ',') = '\0';
        return atoi(deviceModelNumber) >= 8;
    }
    // iPod 7 uses A10 :(
//    if (strstr(deviceModel, "iPod") == deviceModel) {
//        strcpy(deviceModelNumber, deviceModel + strlen("iPod"));
//        *index(deviceModelNumber, ',') = '\0';
//        return atoi(deviceModelNumber) >= 9;
//    }
    return false;
}
bool isCurrentDeviceNonceEntanglingEnabled(void) {
    static BOOL enabled = isNonceEntanglingEnabledForModel(getLocalDeviceInfo()->deviceModel);
    return enabled;
}
extern "C" size_t apNonceLengthForDeviceModel(const char *);
size_t apNonceLengthForLocalDevice(void)
{
    return apNonceLengthForDeviceModel(getLocalDeviceInfo()->deviceModel);
}
//void setLocalDeviceBasebandCertID(uint64_t certID) {
//    info.basebandCertID = certID;
//}
//void setLocalDeviceBasebandSerialNumberSize(size_t size) {
//    info.bbsnumSize = size;
//}
//bool hasCellularCapability(void) {
//    static bool cc = false;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//
//#if TARGET_IPHONE_SIMULATOR
//        cc = true;
//#else
//        struct ifaddrs * addrs;
//        const struct ifaddrs * cursor;
//        if (getifaddrs(&addrs) == 0) {
//            cursor = addrs;
//            while (cursor != NULL) {
//                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
//                if ([name isEqualToString:@"pdp_ip0"]) {
//                    cc = true;
//                    break;
//                }
//                cursor = cursor->ifa_next;
//            }
//            freeifaddrs(addrs);
//        }
//#endif
//    });
//    return cc;
//}
void updateDatabase(void) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.ipsw.me/v4/devices"]];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                if (error) {
                                                    return;
                                                }
                                                NSArray<NSDictionary *> *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                                if (![array isKindOfClass: [NSArray class]]) {
                                                    return;
                                                }
                                                NSMutableArray<NSDictionary *> *absentInDatabase = [NSMutableArray array];
                                                NSMutableArray<NSDictionary *> *differentInDatabase = [NSMutableArray array];
                                                NSArray<NSString *> *const identifierArray = @[@"iPhone",@"iPad",@"iPod"];
                                                for (NSDictionary *device in array) {
                                                    NSString *idenifier = device[@"identifier"];
                                                    bool qualified = false;
                                                    for (NSString *identifierInArray in identifierArray) {
                                                        if ([idenifier containsString:identifierInArray]) {
                                                            qualified = true;
                                                            break;
                                                        }
                                                    }
                                                    if (!qualified) {
                                                        continue;
                                                    }
                                                    DeviceInfo_ptr deviceInfo = findDeviceInfoForSpecifiedConfiguration([device[@"boardconfig"] cStringUsingEncoding:NSASCIIStringEncoding]);
                                                    if (deviceInfo == nullptr) {
                                                        [absentInDatabase addObject:device];
                                                    }
                                                    else {
                                                        if (strcmp([device[@"boardconfig"] cStringUsingEncoding:NSASCIIStringEncoding], deviceInfo->deviceBoardConfiguration)) {
                                                            [differentInDatabase addObject:device];
                                                        }
                                                    }
                                                }
                                                NSLog(@"absentInDatabase: %@", absentInDatabase);
                                                if (differentInDatabase.count) {
                                                    NSLog(@"differentInDatabase: %@", differentInDatabase);
                                                }
                                            }];
    [task resume];
}
