//
//  TSSBuildIdentity.m
//  MobileTSS
//
//  Created by User on 1/15/19.
//

#import "TSSBuildIdentity.h"
#import "LocalDeviceConstants.h"
#import <plist/plist.h>

static NSString *getDeviceBoardForPlist(plist_t plist) {
    char *value = NULL;
    plist_get_string_val(plist_access_path(plist, 2, "Info", "DeviceClass"), &value);
    NSCAssert(value != NULL, @"Device class is null.");
    NSString *str = [NSString stringWithCString:value encoding:NSASCIIStringEncoding];
    free(value);
    return str;
}
static plist_t getDeviceBoardConfigMatchingBuildIdentityFromIdentities(plist_t buildIdentities, const char *deviceBoardConfiguration, bool updateInstall) {
    // It is possible that incompatible ota update files includes the current model in its supporteddevicetypes.
    const int arraySize = plist_array_get_size(buildIdentities);
    for (int a = 0; a < arraySize; a++) {
        plist_t identity = plist_array_get_item(buildIdentities, a);
        plist_t info = plist_dict_get_item(identity, "Info");
        char *str = NULL;
        plist_get_string_val(plist_dict_get_item(info, "DeviceClass"), &str);
        if (str && strcmp(deviceBoardConfiguration, str) == 0) {
            free(str);
            str = NULL;
            plist_get_string_val(plist_dict_get_item(info, "RestoreBehavior"), &str);
            if (str && strcmp(str, updateInstall ? "Update" : "Erase") == 0) {
                free(str);
                return identity;
            }
        }
        free(str);
    }
    return NULL;
}
@interface TSSBuildIdentity ()
@property (readwrite, nonatomic, nullable) void *updateInstall;
@property (readwrite, nonatomic, nullable) void *eraseInstall;

@end
@implementation TSSBuildIdentity

+ (nullable NSArray<TSSBuildIdentity *> *)buildIdentitiesInBuildManifest:(nonnull NSDictionary<NSString *,id> *)buildManifest forDeviceModel:(nonnull NSString *)deviceModel {
    NSArray *objcBuildIdentities = buildManifest[@"BuildIdentities"];
    if (!objcBuildIdentities) {
        return nil;
    }
    NSString *str = [[NSString alloc] initWithData:[NSPropertyListSerialization dataWithPropertyList:objcBuildIdentities format:NSPropertyListXMLFormat_v1_0 options:0 error:nil] encoding:NSASCIIStringEncoding];
    plist_t buildIdentities = NULL;
    plist_from_xml([str cStringUsingEncoding:NSASCIIStringEncoding], (uint32_t)str.length, &buildIdentities);
    if (!buildIdentities) {
        return nil;
    }
    DeviceInfo_ptr board[10] = {0};
    findAllDeviceInfosForSpecifiedModel([deviceModel cStringUsingEncoding:NSASCIIStringEncoding], board, sizeof(board)/sizeof(DeviceInfo_ptr));
    NSMutableArray<TSSBuildIdentity *> *array = [NSMutableArray array];
    for (int index = 0; index < sizeof(board)/sizeof(board[0]); index++) {
        if (board[index]) {
            plist_t update = getDeviceBoardConfigMatchingBuildIdentityFromIdentities(buildIdentities, board[index]->deviceBoardConfiguration, true);
            plist_t restore = getDeviceBoardConfigMatchingBuildIdentityFromIdentities(buildIdentities, board[index]->deviceBoardConfiguration, false);
            TSSBuildIdentity *identity = [[TSSBuildIdentity alloc] initWithUpdate:update ? plist_copy(update) : NULL EraseRestore:restore ? plist_copy(restore) : NULL];
            if (identity) {
                [array addObject:identity];
            }
        }
        else break;
    }
    plist_free(buildIdentities);
    return array;
}
- (nullable instancetype)initWithUpdate:(nullable void *)update EraseRestore:(nullable void *)erase { 
    self = [super init];
    if (self) {
        if (update || erase) {
            self.updateInstall = update;
            self.eraseInstall = erase;
        }
        else return nil;
    }
    return self;
}
- (nullable instancetype)initWithBuildManifest:(nonnull NSDictionary<NSString *,id> *)buildManifest DeviceBoard:(nonnull NSString *)deviceBoard {
    NSArray *objcBuildIdentities = buildManifest[@"BuildIdentities"];
    if (!objcBuildIdentities) {
        return nil;
    }
    NSString *str = [[NSString alloc] initWithData:[NSPropertyListSerialization dataWithPropertyList:objcBuildIdentities format:NSPropertyListXMLFormat_v1_0 options:0 error:nil] encoding:NSASCIIStringEncoding];
    plist_t buildIdentities = NULL;
    plist_from_xml([str cStringUsingEncoding:NSASCIIStringEncoding], (uint32_t)str.length, &buildIdentities);
    if (!buildIdentities) {
        return nil;
    }
    plist_t update = getDeviceBoardConfigMatchingBuildIdentityFromIdentities(buildIdentities, [deviceBoard cStringUsingEncoding:NSASCIIStringEncoding], true);
    plist_t restore = getDeviceBoardConfigMatchingBuildIdentityFromIdentities(buildIdentities, [deviceBoard cStringUsingEncoding:NSASCIIStringEncoding], false);
    TSSBuildIdentity *identity = [self initWithUpdate:update ? plist_copy(update) : NULL EraseRestore:restore ? plist_copy(restore) : NULL];
    plist_free(buildIdentities);
    return identity;
}
- (NSString *) deviceBoardConfiguration {
    return getDeviceBoardForPlist(self.eraseInstall ? self.eraseInstall : self.updateInstall);
}
- (void)dealloc
{
    plist_free(self.updateInstall);
    plist_free(self.eraseInstall);
}
@end
