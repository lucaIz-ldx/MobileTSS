//
//  TSSBuildIdentity.m
//  MobileTSS
//
//  Created by User on 1/15/19.
//

#import "TSSBuildIdentity.h"
#import "LocalDeviceConstants.h"
#import <plist/plist.h>

//static const char *TSSBuildIdentityCachingUpdateKey = "Update";
//static const char *TSSBuildIdentityCachingEraseKey = "Erase";

static void getDeviceBoardConfigMatchingBuildIdentityFromIdentities(plist_t buildIdentities, const char *deviceBoardConfiguration, plist_t *update, plist_t *erase) {
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
            if (str) {
                if (!*update && strcmp(str, "Update") == 0) {
                    *update = identity;
                }
                else if (!*erase && strcmp(str, "Erase") == 0) {
                    *erase = identity;
                }
                else NSLog(@"[WARNING] Unknown restore behavior: %s.\n", str);
            }
        }
        free(str);
    }
}
@interface TSSBuildIdentity ()
@property (readwrite, nonatomic, nullable) void *updateInstall;
@property (readwrite, nonatomic, nullable) void *eraseInstall;
@property (readwrite, copy, nonatomic) NSString *deviceBoardConfiguration;

@end
@implementation TSSBuildIdentity
+ (NSArray<TSSBuildIdentity *> *)buildIdentitiesInBuildManifestData:(NSData *)buildManifestData forDeviceModel:(NSString *)deviceModel {
    plist_t buildManifest = NULL;
    plist_from_xml(buildManifestData.bytes, (uint32_t)buildManifestData.length, &buildManifest);
    plist_t buildIdentities = plist_dict_get_item(buildManifest, "BuildIdentities");
    if (!PLIST_IS_ARRAY(buildIdentities)) {
        plist_free(buildManifest);
        return NULL;
    }
    DeviceInfo_ptr board[10] = {0};
    findAllDeviceInfosForSpecifiedModel([deviceModel cStringUsingEncoding:NSASCIIStringEncoding], board, sizeof(board)/sizeof(DeviceInfo_ptr));
    NSMutableArray<TSSBuildIdentity *> *array = [NSMutableArray array];
    for (int index = 0; index < sizeof(board)/sizeof(board[0]); index++) {
        if (board[index]) {
            plist_t update = NULL, erase = NULL;
            getDeviceBoardConfigMatchingBuildIdentityFromIdentities(buildIdentities, board[index]->deviceBoardConfiguration, &update, &erase);
            TSSBuildIdentity *identity = [[TSSBuildIdentity alloc] initWithUpdateInstall:update eraseInstall:erase];
            if (identity) {
                [array addObject:identity];
            }
        }
        else break;
    }
    plist_free(buildManifest);
    return array;
}
+ (NSString *)buildIdentityCacheFileNameWithDeviceBoard:(NSString *)deviceBoard version:(NSString *)version buildId:(NSString *)buildId {
    return [NSString stringWithFormat:@"%@_%@-%@", deviceBoard, version, buildId];
}
- (nullable instancetype) initWithUpdateInstall: (nullable void *) updateInstall eraseInstall: (nullable void *) eraseInstall {
    self = [super init];
    if (!self) {
        return nil;
    }
    if (updateInstall || eraseInstall) {
        char *value = NULL;
        plist_get_string_val(plist_access_path(eraseInstall ? eraseInstall : updateInstall, 2, "Info", "DeviceClass"), &value);
        if (!value) {
            return nil;
        }
        self.deviceBoardConfiguration = [NSString stringWithCString:value encoding:NSASCIIStringEncoding];
        free(value);
        self.updateInstall = plist_copy(updateInstall);
        self.eraseInstall = plist_copy(eraseInstall);
    }
    else return nil;
    return self;
}
- (instancetype)initWithBuildManifestPlistDictNode:(void *)plistDictNode deviceBoard: (NSString *) deviceBoard {
    plist_t buildIdentities = plist_dict_get_item(plistDictNode, "BuildIdentities");
    if (!PLIST_IS_ARRAY(buildIdentities)) {
        return nil;
    }
    plist_t update = NULL, erase = NULL;
    getDeviceBoardConfigMatchingBuildIdentityFromIdentities(buildIdentities, [deviceBoard cStringUsingEncoding:NSASCIIStringEncoding], &update, &erase);
    TSSBuildIdentity *identity = [self initWithUpdateInstall:update eraseInstall:erase];
    return identity;
}
- (instancetype)initWithBuildManifestData:(NSData *)buildManifestData deviceBoard:(NSString *)deviceBoard {
    plist_t buildManifest = NULL;
    plist_from_xml(buildManifestData.bytes, (uint32_t)buildManifestData.length, &buildManifest);
    if (!PLIST_IS_DICT(buildManifest)) {
        plist_free(buildManifest);
        return nil;
    }
    return [self initWithBuildManifestPlistDictNode:buildManifest deviceBoard:deviceBoard];
}
- (instancetype)initWithBuildIdentitiesData:(NSData *)buildIdentityData {
    plist_t buildIdentityDict = NULL;
    plist_from_xml(buildIdentityData.bytes, (uint32_t)buildIdentityData.length, &buildIdentityDict);
    self = [self initWithUpdateInstall:plist_dict_get_item(buildIdentityDict, "Update") eraseInstall:plist_dict_get_item(buildIdentityDict, "Erase")];
    plist_free(buildIdentityDict);
    return self;
}
- (BOOL)writeBuildIdentitiesToFile:(NSString *)filePath error:(NSError *__autoreleasing  _Nullable * _Nullable)error {
    plist_t dictionary = plist_new_dict();
    if (self.updateInstall) {
        plist_dict_set_item(dictionary, "Update", plist_copy(self.updateInstall));
    }
    if (self.eraseInstall) {
        plist_dict_set_item(dictionary, "Erase", plist_copy(self.eraseInstall));
    }
    
    char *buffer = NULL;
    uint32_t length = 0;
    plist_to_xml(dictionary, &buffer, &length);
    plist_free(dictionary);
    
    return [[NSData dataWithBytesNoCopy:buffer length:length] writeToFile:filePath options:NSDataWritingAtomic error:error];
}
- (void)dealloc
{
    plist_free(self.updateInstall);
    plist_free(self.eraseInstall);
}
@end
