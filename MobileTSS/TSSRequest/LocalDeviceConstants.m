//
//  LocalDeviceConstants.mm
//  MobileTSS
//
//  Created by User on 10/11/18.
//
#include "LocalDeviceConstants.h"

#import <Foundation/Foundation.h>
#import "MobileGestalt.h"

static const CFStringRef kMGProductType = CFSTR("ProductType");
#if !TARGET_IPHONE_SIMULATOR
static const CFStringRef kMGHWModel = CFSTR("HWModelStr");
#endif

typedef struct DeviceInfo DeviceInfo;
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
    {"iPhone12,8", "d79ap", Unknown, Unknown},
    
    {"iPhone13,1", "d52gap", Unknown, Unknown},
    {"iPhone13,2", "d53gap", Unknown, Unknown},
    {"iPhone13,3", "d53pap", Unknown, Unknown},
    {"iPhone13,4", "d54pap", Unknown, Unknown},

//    {"iPod1,1", "n45ap", 0, 0},
//    {"iPod2,1", "n72ap", 0, 0},
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
    {"iPad8,9", "j418ap", Unknown, Unknown},
    {"iPad8,10", "j417ap", Unknown, Unknown},
    {"iPad8,11", "j421ap", Unknown, Unknown},
    {"iPad8,12", "j420ap", Unknown, Unknown},

    {"iPad11,1", "j210ap", 0, 0},
    {"iPad11,2", "j211ap", 165673526, 12},
    {"iPad11,3", "j217ap", 0, 0},
    {"iPad11,4", "j218ap", 165673526, 12},
    {"iPad11,6", "j171aap", Unknown, Unknown},
    {"iPad11,7", "j172aap", Unknown, Unknown},
    
    {"iPad13,1", "j307ap", Unknown, Unknown},
    {"iPad13,2", "j308ap", Unknown, Unknown},
    {"iPad13,4", "j517ap", Unknown, Unknown},
    {"iPad13,5", "j517xap", Unknown, Unknown},
    {"iPad13,6", "j518ap", Unknown, Unknown},
    {"iPad13,7", "j518xap", Unknown, Unknown},
    {"iPad13,8", "j522ap", Unknown, Unknown},
    {"iPad13,9", "j522xap", Unknown, Unknown},
    {"iPad13,10", "j523ap", Unknown, Unknown},
    {"iPad13,11", "j523xap", Unknown, Unknown},

//    {"AppleTV2,1", "k66ap", 0, 0},
//    {"AppleTV3,1", "j33ap", 0, 0},
//    {"AppleTV3,2", "j33iap", 0, 0},
//    {"AppleTV5,3", "j42dap", 0, 0},
//    {"AppleTV6,2", "j105aap", 0, 0},
};

static DeviceInfo localDeviceInfo;
const DeviceInfo *getLocalDeviceInfo(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *productType = (__bridge_transfer NSString *)MGCopyAnswer(kMGProductType);
        char *buffer = malloc(productType.length + 1);
        [productType getCString:buffer maxLength:productType.length + 1 encoding:NSASCIIStringEncoding];
        localDeviceInfo.deviceModel = buffer;
#if TARGET_IPHONE_SIMULATOR
        DeviceInfo_ptr deviceInfoDatabase = localDatabase;
        for (int a = 0; a < sizeof(localDatabase)/sizeof(localDatabase[0]); a++, deviceInfoDatabase++) {
            if (strcmp(buffer, deviceInfoDatabase->deviceModel) == 0) {
                free(buffer);
                buffer = NULL;
                localDeviceInfo = *deviceInfoDatabase;
                break;
            }
        }
        if (buffer) {
            [NSException raise:NSInternalInconsistencyException format:@"Invalid simulator device model: %s.", localDeviceInfo.deviceModel];
        }
#else
        NSString *model = ((__bridge_transfer NSString *)MGCopyAnswer(kMGHWModel)).lowercaseString;
        buffer = malloc(model.length + 1);
        [model getCString:buffer maxLength:model.length + 1 encoding:NSASCIIStringEncoding];
        localDeviceInfo.deviceBoardConfiguration = buffer;
#endif
        if (localDeviceInfo.deviceModel == NULL || localDeviceInfo.deviceBoardConfiguration == NULL) {
            // app cannot run without essential information.
            [NSException raise:NSInternalInconsistencyException format:@"Cannot get device information."];
        }
    });
    return &localDeviceInfo;
}
typedef void (^IterationBlock)(DeviceInfo_ptr deviceInfoInDatabase, NSUInteger index, BOOL *stop);
static void iterateDatabaseWithBlock(IterationBlock NS_NOESCAPE block);
DeviceInfo_ptr findDeviceInfoForSpecifiedModel(const char *deviceModel) {
    __block DeviceInfo_ptr info = NULL;
    iterateDatabaseWithBlock(^(DeviceInfo_ptr deviceInfoInDatabase, NSUInteger index, BOOL *stop) {
        if (strcmp(deviceInfoInDatabase->deviceModel, deviceModel) == 0) {
            *stop = YES;
            info = deviceInfoInDatabase;
        }
    });
    return info;
}
DeviceInfo_ptr __nullable findDeviceInfoForSpecifiedConfiguration(const char *deviceConfiguration) {
    __block DeviceInfo_ptr info = NULL;
    iterateDatabaseWithBlock(^(DeviceInfo_ptr deviceInfoInDatabase, NSUInteger index, BOOL *stop) {
        if (strcmp(deviceConfiguration, deviceInfoInDatabase->deviceBoardConfiguration) == 0) {
            *stop = YES;
            info = deviceInfoInDatabase;
        }
    });
    return info;
}
void findAllDeviceInfosForSpecifiedModel(const char *deviceModel, DeviceInfo_ptr *array, size_t arraySize) {
    iterateDatabaseWithBlock(^(DeviceInfo_ptr deviceInfoInDatabase, NSUInteger index, BOOL *stop) {
        if (strcmp(deviceModel, deviceInfoInDatabase->deviceModel) == 0) {
            if (index >= arraySize) {
                *stop = YES;
            }
            array[index++] = deviceInfoInDatabase;
        }
    });
}
NSArray<NSString *> *getAllKnownDeviceModels(void) {
    NSMutableOrderedSet<NSString *> *orderSet = [NSMutableOrderedSet orderedSetWithCapacity:sizeof(localDatabase)/sizeof(localDatabase[0])];
    iterateDatabaseWithBlock(^(DeviceInfo_ptr deviceInfoInDatabase, NSUInteger index, BOOL *stop) {
        [orderSet addObject:[NSString stringWithCString:deviceInfoInDatabase->deviceModel encoding:NSASCIIStringEncoding]];
    });
    return [orderSet array];
}
NSArray<NSString *> *findAllDeviceConfigurationsForSpecifiedModel(NSString *deviceModel) {
    NSMutableArray<NSString *> *array = [NSMutableArray array];
    const char *deviceModelCString = [deviceModel cStringUsingEncoding:NSASCIIStringEncoding];
    iterateDatabaseWithBlock(^(DeviceInfo_ptr deviceInfoInDatabase, NSUInteger index, BOOL *stop) {
        if (strcmp(deviceModelCString, deviceInfoInDatabase->deviceModel) == 0) {
            [array addObject:[NSString stringWithCString:deviceInfoInDatabase->deviceBoardConfiguration encoding:NSASCIIStringEncoding]];
        }
    });
    return array;
}

//static NSString *additionalDatabasePath;
//static NSArray<NSValue *> *getAdditionalDatabase() {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        additionalDatabasePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/Database.plist"];
//        additionalDatabase = [NSArray arrayWithContentsOfFile:additionalDatabasePath];
//    });
//}
static void iterateDatabaseWithBlock(IterationBlock NS_NOESCAPE block) {
    DeviceInfo_ptr deviceInfoDatabase = localDatabase;
    BOOL stop = NO;
    for (NSUInteger a = 0; a < sizeof(localDatabase)/sizeof(localDatabase[0]); a++, deviceInfoDatabase++) {
        block(deviceInfoDatabase, a, &stop);
        if (stop) {
            return;
        }
    }
//    [getAdditionalDatabase() enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        DeviceInfo info;
//        [obj getValue:&info];
//        block(&info, idx, stop);
//    }];
}
void updateDatabase(void) {
#if !TARGET_IPHONE_SIMULATOR
    [NSException raise:NSInternalInconsistencyException format:@"updateDatabase is supposed to be run in simulator."];
#else
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.ipsw.me/v4/devices"]];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            return;
        }
        NSArray<NSDictionary *> *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![array isKindOfClass: [NSArray class]]) {
            NSLog(@"Object is not an array.");
            return;
        }
        NSMutableArray<NSDictionary *> *absentInDatabase = [NSMutableArray array];
        // NSMutableArray<NSDictionary *> *differentInDatabase = [NSMutableArray array];
        NSSet<NSString *> *const identifierArray = [NSSet setWithObjects:@"iPhone",@"iPad", nil];
        for (NSDictionary *device in array) {
            NSString *identifier = device[@"identifier"];
            BOOL qualified = NO;
            for (NSString *identifierInArray in identifierArray) {
                if ([identifier containsString:identifierInArray]) {
                    identifier = [identifier substringFromIndex:identifierInArray.length];
                    if ([identifier componentsSeparatedByString:@","][0].integerValue >= 2) {
                        qualified = true;
                    }
                    break;
                }
            }
            if (!qualified) {
                continue;
            }
            DeviceInfo_ptr deviceInfo = findDeviceInfoForSpecifiedConfiguration([[device[@"boardconfig"] lowercaseString] cStringUsingEncoding:NSASCIIStringEncoding]);
            if (deviceInfo == NULL) {
                [absentInDatabase addObject:device];
            }
//            else {
//                if (strcmp([device[@"boardconfig"] cStringUsingEncoding:NSASCIIStringEncoding], deviceInfo->deviceBoardConfiguration)) {
//                    [differentInDatabase addObject:device];
//                }
//            }
        }
//        NSLog(@"absentInDatabase: %@", absentInDatabase);
        [absentInDatabase sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSString *modelName1 = obj1[@"identifier"];
            NSString *modelName2 = obj2[@"identifier"];
            return [modelName1 compare:modelName2];
        }];
        for (NSDictionary *deviceInfoDict in absentInDatabase) {
            NSString *modelName = deviceInfoDict[@"identifier"];
            NSString *deviceConfig = [deviceInfoDict[@"boardconfig"] lowercaseString];
            if (modelName && deviceConfig) {
                printf("{\"%s\", \"%s\", Unknown, Unknown},\n", modelName.UTF8String, deviceConfig.UTF8String);
            }
            else {
                NSLog(@"Model or deviceconfig is missing. %@", deviceInfoDict);
            }
        }
//        if (differentInDatabase.count) {
//            NSLog(@"differentInDatabase: %@", differentInDatabase);
//        }
//        if (!absentInDatabase.count) {
//            return;
//        }
//
//        NSMutableArray<NSDictionary *> *database = [getAdditionalDatabase() mutableCopy];
//        if (!database) {
//            database = [NSMutableArray arrayWithCapacity:absentInDatabase.count];
//        }
//
//        for (NSDictionary *dict in absentInDatabase) {
//            [database addObject:@{@"identifier" : dict[@"identifier"], @"boardconfig" : dict[@"boardconfig"]}];
//        }
    }];
    [task resume];
#endif
}
