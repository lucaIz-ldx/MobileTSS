//
//  TSSRequest.m
//  MobileTSS
//
//  Created by User on 7/8/18.
//  Copyright © 2018 User. All rights reserved.
//

#import "TSSRequest.h"
#import "TSSHelper.h"
#import "TSSC.h"
#import "LocalDeviceConstants.h"
#import "NSString+ASCIIString.h"

#define SET_ERROR_CODE_LOCALIZED(errCode, msg) do {if (error){\
*error = [NSError errorWithDomain:TSSRequestErrorDomain code:errCode userInfo:@{NSLocalizedDescriptionKey : msg}];\
}} while (0)

@interface TSSNonce (Private)
@property (readonly, nonatomic) TSSDataBuffer internalNonceBufferCopy;
@end

NSErrorDomain const TSSRequestErrorDomain = @"TSSRequestErrorDomain";

static void messageOutputFromRequest(void *__nonnull userData, const char *message) {
    TSSRequest *request = (__bridge TSSRequest *)userData;
    [request.delegate request:request verboseOutput:[NSString stringWithCStringASCII:message]];
}
static inline const char *buildManifestPathFromArchive(BOOL isOTA) {
    return isOTA ? "AssetData/boot/BuildManifest.plist" : "BuildManifest.plist";
}
@interface TSSRequest () {
    TSSCustomUserData _customUserData;
    TSSCustomUserData *userData;
    TSSBoolean canceledSignal;
}
@property (nonatomic) DeviceInfo_ptr deviceInfo;
@property (nonatomic) plist_t loadedBuildManifest;    // only nonnull if supportedDevices are loaded

@property (readwrite, copy, nonatomic) NSString *firmwareURL;
@property (readwrite, copy, nonatomic, nullable) NSArray<NSString *> *supportedDevices;
@property (readwrite, strong, nonatomic) TSSFirmwareVersion *firmwareVersion;
@property (readwrite, strong, nonatomic) TSSBuildIdentity *currentBuildIdentity;
@property (strong, nonatomic) NSArray<NSValue *> *supportedDeviceInfos;

@end
static NSString *globalBuildManifestCacheDirectory = nil;
@implementation TSSRequest
+ (NSString *) buildManifestCacheDirectory {
    return globalBuildManifestCacheDirectory;
}
+ (void) setBuildManifestCacheDirectory:(NSString *)buildManifestCacheDirectory {
    globalBuildManifestCacheDirectory = buildManifestCacheDirectory;
}

#pragma mark - Init
- (instancetype) initWithFirmwareURL: (NSString *) urlInString {
    return [self initWithFirmwareURL:urlInString deviceBoardConfiguration:nil ecid:nil];
}
- (instancetype) initWithFirmwareURL: (NSString *) urlInString deviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration {
    return [self initWithFirmwareURL:urlInString deviceBoardConfiguration:deviceBoardConfiguration ecid:nil];
}
- (instancetype) initWithFirmwareURL: (NSString *) urlInString deviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration ecid: (nullable TSSECID *) ecid {
    self = [super init];
    if (self) {
        self.firmwareURL = urlInString;
        self.deviceInfo = deviceBoardConfiguration ? findDeviceInfoForSpecifiedConfiguration(deviceBoardConfiguration.asciiString) : NULL;
        _ecid = ecid ? ecid : TSSECID.randomECID;
        userData = &_customUserData;
        _customUserData.callback = NULL;
        _customUserData.signal = &canceledSignal;
        _customUserData.userData = (__bridge void *)self;
        _customUserData.timeout = 0;
        [self resetStatusData];
    }
    return self;
}
#pragma mark - Getter & Setter
- (NSString *) deviceModel {
    return self.deviceInfo ? [NSString stringWithCStringASCII:self.deviceInfo->deviceModel] : nil;
}
- (NSString *) deviceBoardConfig {
    return self.deviceInfo ? [NSString stringWithCStringASCII:self.deviceInfo->deviceBoardConfiguration] : nil;
}
- (void)setDelegate:(id<TSSRequestDelegate>)delegate {
    _delegate = delegate;
    _customUserData.callback = delegate ? &messageOutputFromRequest : NULL;
}
- (void)setEcid:(TSSECID *)ecid {
    _ecid = ecid ? ecid : TSSECID.randomECID;
}
- (NSTimeInterval)timeout {
    return _customUserData.timeout;
}
- (void)setTimeout:(NSTimeInterval)timeout {
    if (timeout < 0) {
        timeout = 0;
    }
    _customUserData.timeout = (NSInteger)timeout;
}
#pragma mark - Methods
- (void)validateURLWithCompletionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL result = [self validateURLWithError:&error];
        completionHandler(result, error);
    });
}
- (BOOL)validateURLWithError:(NSError *__autoreleasing  _Nullable *)error {
    [self resetStatusData];
    if (self.firmwareVersion || self.currentBuildIdentity) {
        // firmwareVersion or buildIdentity has been loaded. The URL is valid.
        return YES;
    }
    TSSFirmwareVersion *firmwareVersion = [[TSSFirmwareVersion alloc] initWithFirmwareURLString:self.firmwareURL];
    if (!firmwareVersion) {
        SET_ERROR_CODE_LOCALIZED(-1, @"Invalid firmware URL");
        return NO;
    }
    if (self.deviceInfo == NULL) {
        plist_t buildManifest = NULL;
        if (![self downloadXMLBuildManifest:&buildManifest firmwareVersion:firmwareVersion]) {
            SET_ERROR_CODE_LOCALIZED(-1, [NSString stringWithCStringASCII:userData->errorMessage]);
            return NO;
        }
        plist_t buildIdentities = plist_dict_get_item(buildManifest, "BuildIdentities");
        const uint32_t buildIdentitiesSize = plist_array_get_size(buildIdentities);
        if (buildIdentitiesSize == 0) {
            plist_free(buildManifest);
            SET_ERROR_CODE_LOCALIZED(-125, @"\"BuildIdentities\" in buildmanifest is empty.");
            return NO;
        }
        CFMutableBagRef deviceModelBag = CFBagCreateMutable(kCFAllocatorDefault, 0, NULL);
//        NSCountedSet<NSString *> *deviceModelCountedSet = [NSCountedSet set];
        NSMutableSet<NSString *> *deviceBoardSet = [NSMutableSet set];

        NSMutableArray<NSValue *> *deviceInfoMutableArray = [NSMutableArray array];
        NSMutableArray<NSString *> *supportedDevicesArray = [NSMutableArray array];

        for (int index = 0; index < buildIdentitiesSize; index++) {
            plist_t deviceClass = plist_access_path(buildIdentities, 3, index, "Info", "DeviceClass");
            char *string = NULL;
            plist_get_string_val(deviceClass, &string);
            DeviceInfo_ptr foundDevice;
            if (string && (foundDevice = findDeviceInfoForSpecifiedConfiguration(string))) {
                NSString *deviceBoardObjcString = [NSString stringWithCStringASCII:foundDevice->deviceBoardConfiguration];
                if (![deviceBoardSet containsObject:deviceBoardObjcString]) {
                    NSValue *wrappedDeviceInfo = [NSValue valueWithPointer:foundDevice];
                    [deviceInfoMutableArray insertObject:wrappedDeviceInfo atIndex:[deviceInfoMutableArray indexOfObject:wrappedDeviceInfo inSortedRange:NSMakeRange(0, deviceInfoMutableArray.count) options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
                        DeviceInfo_ptr deviceInfo1 = obj1.pointerValue, deviceInfo2 = obj2.pointerValue;
                        int c = strcmp(deviceInfo1->deviceModel, deviceInfo2->deviceModel);
                        if (c == 0) {
                            c = strcmp(deviceInfo1->deviceBoardConfiguration, deviceInfo2->deviceBoardConfiguration);
                        }
                        return c < 0 ? NSOrderedAscending : NSOrderedDescending;
                    }]];
                    CFBagAddValue(deviceModelBag, foundDevice->deviceModel);
                    [deviceBoardSet addObject:deviceBoardObjcString];
                }
            }
            free(string);
        }
        [deviceInfoMutableArray enumerateObjectsUsingBlock:^(NSValue *obj, NSUInteger idx, BOOL *stop) {
            DeviceInfo_ptr deviceInfo = obj.pointerValue;
            if (CFBagGetCountOfValue(deviceModelBag, deviceInfo->deviceModel) > 1) {
                [supportedDevicesArray addObject:[NSString stringWithFormat:@"%s (%s)", deviceInfo->deviceModel, deviceInfo->deviceBoardConfiguration]];
            }
            else {
                [supportedDevicesArray addObject:[NSString stringWithCStringASCII:deviceInfo->deviceModel]];
            }
        }];
        CFRelease(deviceModelBag);
        if (firmwareVersion.isOTAFirmware && ![firmwareVersion updateFirmwareVersionWithBuildManifest:buildManifest error:error]) {
            plist_free(buildManifest);
            return NO;
        }
        self.supportedDeviceInfos = deviceInfoMutableArray;
        self.supportedDevices = supportedDevicesArray;
        self.loadedBuildManifest = buildManifest;
    }
    else {
        if (![self loadBuildIdentityFromFirmwareVersion:firmwareVersion error:error]) {
            return NO;
        }
    }
    self.firmwareVersion = firmwareVersion;
    return YES;
}
- (void) selectDeviceInSupportedListAtIndex: (NSUInteger) index {
    if (self.supportedDeviceInfos.count <= index || self.loadedBuildManifest == nil) {
        return;
    }
    self.deviceInfo = self.supportedDeviceInfos[index].pointerValue;
    self.supportedDevices = nil;
    self.supportedDeviceInfos = nil;
    [self loadBuildIdentityFromFirmwareVersion:self.firmwareVersion error:nil];
}
- (TSSFirmwareSigningStatus)checkSigningStatusWithError:(NSError *__autoreleasing  _Nullable *)error {
    return [self checkSigningStatusWithTSSResponseDataContainer:NULL error:error];
}
- (void) checkSigningStatusWithCompletionHandler:(nonnull void (^)(TSSFirmwareSigningStatus status, NSError *__nullable error))completionHandler {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil;
        TSSFirmwareSigningStatus status = [self checkSigningStatusWithError:&error];
        completionHandler(status, error);
    });
}

- (NSString *)downloadSHSHBlobsAtDirectory:(NSString *)directory error:(NSError *__autoreleasing  _Nullable *)error {
    if (![self validateURLWithError:error]) {
        return nil;
    }
    TSSDataBuffer shshDataContainer = {0};
    [self checkSigningStatusWithTSSResponseDataContainer:&shshDataContainer error:error];
    if (shshDataContainer.buffer == NULL || shshDataContainer.length == 0) {
        SET_ERROR_CODE_LOCALIZED(-2, @"An error has occurred when fetching shsh data.");
        return nil;
    }
    if (canceledSignal) {
        free(shshDataContainer.buffer);
        SET_ERROR_CODE_LOCALIZED(-99, @"User has canceled request.");
        return nil;
    }

    // fileName: ecid_model_board_version-buildid_apnonce.shsh2
    NSString *filePath = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%s_%s_%@-%@%@_%@.shsh2", self.ecid.ecidString, self.deviceInfo->deviceModel, self.deviceInfo->deviceBoardConfiguration, self.firmwareVersion.version, self.firmwareVersion.buildID, self.firmwareVersion.isOTAFirmware ? @"-OTA" : @"", self.apnonce.nonceString]];
    NSData *objcData = [NSData dataWithBytesNoCopy:shshDataContainer.buffer length:shshDataContainer.length];
    if (![objcData writeToFile:filePath atomically:YES]) {
        SET_ERROR_CODE_LOCALIZED(-3, @"An error has occurred when writing shsh data to destination.");
        return nil;
    }
    return filePath.lastPathComponent;
}
- (void)downloadSHSHBlobsAtDirectory:(NSString *)directory completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *filePath = [self downloadSHSHBlobsAtDirectory:directory error:&error];
        completionHandler(filePath, error);
    });
}

- (void) cancel {
    canceledSignal = 1;
}

#pragma mark - Private
- (void) resetStatusData {
    _customUserData.buffer[0] = _customUserData.errorMessage[0] = '\0';
    _customUserData.errorCode = 0;
    canceledSignal = 0;
}
- (BOOL) loadBuildIdentityFromFirmwareVersion: (TSSFirmwareVersion *) firmwareVersion error: (NSError * __autoreleasing *) error {
    if (self.currentBuildIdentity) {
        // if buildidentity is set, skip loading
        return YES;
    }
    // TODO: detect shareable buildmanifest and avoid cache
    NSAssert(self.deviceInfo != nil, @"DeviceInfo is nil!");
    NSString *destinationPath = nil;

    if (TSSRequest.buildManifestCacheDirectory) {
        // cache directory is set; check if the cached buildId is available
        destinationPath = [TSSRequest.buildManifestCacheDirectory stringByAppendingPathComponent:[TSSBuildIdentity buildIdentityCacheFileNameWithDeviceBoard:self.deviceBoardConfig version:firmwareVersion.version buildId:firmwareVersion.buildID]];
        NSData *cachedBuildManifestData = [NSData dataWithContentsOfFile:destinationPath];
        if (cachedBuildManifestData) {
            TSSBuildIdentity *identities = [[TSSBuildIdentity alloc] initWithBuildIdentitiesData:cachedBuildManifestData];
            if (identities) {
                self.currentBuildIdentity = identities;
                return YES;
            }
            error("Failed to open cached buildmanifest or buildmanifest does not match the current model. Continue to download a new one.\n");
        }
    }
    if (self.loadedBuildManifest) {
        // buildManifest is loaded when load supported device list; cache buildmanifest and load buildidentity
        TSSBuildIdentity *buildIdentity = [[TSSBuildIdentity alloc] initWithBuildManifestPlistDictNode:self.loadedBuildManifest deviceBoard:self.deviceBoardConfig];
        NSAssert(buildIdentity != nil, @"Failed to load buildIdentity");
        self.currentBuildIdentity = buildIdentity;
        if (destinationPath) {
            if ([buildIdentity writeBuildIdentitiesToFile:destinationPath error:nil]) {
                info("Successfully wrote buildmanifest to tmp.\n");
            }
            else {
                warning("Failed to write BuildManifest in temp folder. Maybe the path is not accessible? Continuing though...\n");
            }
        }
        plist_free(self.loadedBuildManifest);
        self.loadedBuildManifest = nil;
    }
    else {
        // failed to load buildmanifest from local or cache path is not set. Download now and cache it.
        plist_t downloadedBuildManifest = NULL;
        if (![self downloadXMLBuildManifest:&downloadedBuildManifest firmwareVersion:firmwareVersion]) {
            SET_ERROR_CODE_LOCALIZED(-1, @"Failed to download BuildManifest from remote.");
            return NO;
        }
        TSSBuildIdentity *buildIdentity = [[TSSBuildIdentity alloc] initWithBuildManifestPlistDictNode:downloadedBuildManifest deviceBoard:self.deviceBoardConfig];
        if (!buildIdentity) {
            plist_free(downloadedBuildManifest);
            SET_ERROR_CODE_LOCALIZED(-2, @"Downloaded Manifest does not match specified model.");
            return NO;
        }
        self.currentBuildIdentity = buildIdentity;
        if (destinationPath) {
            if ([buildIdentity writeBuildIdentitiesToFile:destinationPath error:nil]) {
                info("Successfully wrote buildmanifest to tmp.\n");
            }
            else {
                warning("Failed to write BuildManifest in temp folder. Maybe the path is not accessible? Continuing though...\n");
            }
        }
        plist_free(downloadedBuildManifest);
    }
    return YES;
}
- (BOOL) downloadXMLBuildManifest: (plist_t *) buildManifest firmwareVersion: (TSSFirmwareVersion *) firmwareVersion {
    TSSDataBuffer buffer;
    for (int downloadingTimes = 0; downloadingTimes < 3; downloadingTimes++) {
        buffer.length = 0;
        info("Downloading BuildManifest from destination URL...\n");
        const int result = downloadPartialzip(self.firmwareURL.asciiString, buildManifestPathFromArchive(firmwareVersion.isOTAFirmware), &buffer, userData);
        if (result == 0) {
            plist_t manifest = NULL;
            plist_from_xml(buffer.buffer, (uint32_t)buffer.length, &manifest);
            free(buffer.buffer);
            if (manifest) {
                *buildManifest = manifest;
                info("Successfully downloaded buildmanifest.\n");
                return YES;
            }
            error("Failed to parse buildmanifest. Retrying to download...\n");
        }
        else if (result == -1) {
            error("Cannot download BuildManifest from specified URL.\n");
            break;
        }
        else {
            free(buffer.buffer);
            if (downloadingTimes != 2) {
                warning("Failed to download BuildManifest.\n");
                info("Retrying to download...\n");
            }
            else {
                error("Failed to download BuildManifest.\n");
            }
        }
    }
    return NO;
}
- (TSSFirmwareSigningStatus) checkSigningStatusWithTSSResponseDataContainer: (TSSDataBuffer *) container error:(NSError *__autoreleasing *__nullable) error {
    if (![self validateURLWithError:error]) {
        return NO;
    }
    char generator[19];
    if (self.generator) {
        [self.generator.generatorString getCString:generator maxLength:sizeof(generator)/sizeof(char) encoding:NSASCIIStringEncoding];
    }
    else {
        generator[0] = '\0';
    }
    DeviceInfo_BridgedCStruct device = {
        self.deviceInfo->deviceModel,
        self.deviceInfo->deviceBoardConfiguration,
        self.ecid.numericECID,
        self.apnonce ? self.apnonce.internalNonceBufferCopy : (TSSDataBuffer) {NULL, 1},
        self.sepnonce ? self.sepnonce.internalNonceBufferCopy : (TSSDataBuffer) {NULL, 1},
        generator
    };
    BuildIdentity identity = {self.currentBuildIdentity.updateInstall, self.currentBuildIdentity.eraseInstall};
    const int ret = isBuildIdentitySignedForDevice(&identity, &device, container, userData);
    if (device.apnonce.buffer) {
        if (!self.apnonce) {
            // update apnonce if apnonce is not provided
            self.apnonce = [[TSSAPNonce alloc] initWithInternalNonceBuffer:device.apnonce.buffer length:device.apnonce.length];
        }
        free(device.apnonce.buffer);
    }
    if (device.sepnonce.buffer) {
        if (!self.sepnonce) {
            // update sepnonce if sepnonce is not provided
            self.sepnonce = [[TSSSEPNonce alloc] initWithInternalNonceBuffer:device.sepnonce.buffer length:device.sepnonce.length];
        }
        free(device.sepnonce.buffer);
    }
    if (ret < 0) {
        if (_customUserData.errorMessage[0]) {
            SET_ERROR_CODE_LOCALIZED(_customUserData.errorCode, [NSString stringWithCStringASCII:_customUserData.errorMessage]);
        }
        else {
            SET_ERROR_CODE_LOCALIZED(-99, @"An unknown error has occurred.");
        }
        return TSSFirmwareSigningStatusError;
    }
    return (ret ? TSSFirmwareSigningStatusSigned : TSSFirmwareSigningStatusNotSigned);
}
@end
