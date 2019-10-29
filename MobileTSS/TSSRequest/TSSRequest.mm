//
//  TSSRequest.mm
//  MobileTSS
//
//  Created by User on 7/8/18.
//  Copyright © 2018 User. All rights reserved.
//

#import "TSSRequest.h"
#import "TSSHelper.h"
#import "MobileGestalt.h"
#import "iDeviceTSSRequest.hpp"

#ifdef DEBIAN_PACKAGE
#include <UIKit/UIKit.h>
#include "MobileTSS-Swift.h"
#endif

#define SET_ERROR_CODE_LOCALIZED(errCode, msg) do {if (error){\
*error = [NSError errorWithDomain:TSSRequestErrorDomain code:errCode userInfo:@{NSLocalizedDescriptionKey : msg}];\
}} while (0)
@interface NSString (asciistring)
@property (readonly, nonatomic, nullable) const char *asciiString;
+ (instancetype) stringWithCStringASCII:(const char *)cString;
@end
@implementation NSString (asciistring)
+ (instancetype) stringWithCStringASCII:(const char *)cString {
    return [self stringWithCString:cString encoding:NSASCIIStringEncoding];
}
- (const char *) asciiString {
    return [self cStringUsingEncoding:NSASCIIStringEncoding];
}
@end

NSString *const TSSRequestErrorDomain = @"TSSRequestErrorDomain";
NSString *const TSSTimeoutPreferencesKey = @"Timeout";

static void messageOutputFromRequest(void *__nonnull userData, const char *message) {
    auto request = (__bridge TSSRequest *)userData;
    [request.delegate request:request sendMessageOutput:[NSString stringWithCStringASCII:message]];
}
@interface TSSRequest ()
@property (readwrite, nonatomic) NSString *firmwareURL;
@property (readwrite, copy, nonatomic, nullable) NSArray<NSString *> *supportedDevices;

//@property (nonatomic) DeviceInfo_ptr deviceInfo;
@property (nonatomic) iDeviceTSSRequest *deviceRequest;
@property (nonatomic) DeviceVersion *parsedDeviceVersion;   // internal use
@property (nonatomic) DeviceVersion *OTADeviceVersion;  // ota version
@end
static int64_t localECID = 0;
@implementation TSSRequest
+ (void) setBuildManifestStorageLocation: (NSString *) location {
    iDeviceTSSRequest::temporaryDirectoryPath = location.UTF8String;
}
+ (NSString *) localECID {
    // Read from preferences first (nil if first launch); then attempt to load from device; the last resort is to ask from user.
#ifdef DEBIAN_PACKAGE
    NSString *ecid = PreferencesManager.shared.ecidString;
#else
    NSString *ecid = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECID"];
#endif
    if (!ecid) {
        CFStringRef uniqueChipID_Key = CFStringCreateWithCString(kCFAllocatorDefault, "UniqueChipID", kCFStringEncodingASCII);
        NSNumber *ecidFetchedFromDevice = (__bridge_transfer NSNumber *)MGCopyAnswer(uniqueChipID_Key);
        CFRelease(uniqueChipID_Key);
        if (ecidFetchedFromDevice) {
            ecid = ecidFetchedFromDevice.stringValue;
            if ([self setECIDToPreferences:ecid])
                return ecid;
        }
        return nil;
    }
    if ([ecid integerValue] <= 0) {
        localECID = -1;
        return @"";  // user do not want to set.
    }
    const int64_t parsedECID = parseECID(ecid.asciiString);
    if (!parsedECID) {
        [self setECIDToPreferences:nil];
    }
    localECID = parsedECID;
#ifdef DEBUG
    NSLog(@"Get ecid from local: %lld", localECID);
#endif
    return ecid;
}
+ (BOOL) setECIDToPreferences: (NSString *) ecid {
    if (ecid) {
        // if ecid is provided, check its validity.
        int64_t parsed = parseECID(ecid.asciiString);
        if (!parsed) {
            return NO;
        }
        localECID = parsed;
    }
    else {
        localECID = -1; // ignored any further requests for setting ecid if user prefers to provide it later.
    }
#ifdef DEBIAN_PACKAGE
    PreferencesManager.shared.ecidString = @(localECID).stringValue;
#else
    [[NSUserDefaults standardUserDefaults] setObject:@(localECID).stringValue forKey:@"ECID"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
    return YES;
}
+ (int64_t) parseECIDInString:(NSString *)ecidInString {
    return parseECID(ecidInString.asciiString);
}
extern "C" size_t apNonceLengthForDeviceModel(const char *);
+ (BOOL) parseNonceInString: (NSString *) apnonce error: (NSError *__autoreleasing *) error
{
    size_t length = 0;
    char *nonce = parseNonce(apnonce.asciiString, &length);
    if (nonce) {
        free(nonce);
        if (length != apNonceLengthForDeviceModel(getLocalDeviceInfo()->deviceModel)) {
            SET_ERROR_CODE_LOCALIZED(-50, ([NSString stringWithFormat:@"The parsed length should be %d but actual is %d", (int)apNonceLengthForDeviceModel(getLocalDeviceInfo()->deviceModel), (int)length]));
            return NO;
        }
        return YES;
    }
    SET_ERROR_CODE_LOCALIZED(-50, @"Failed to parse nonce.");
    return NO;
}
+ (BOOL) parseGeneratorInString: (NSString *) generator error: (NSError *__autoreleasing *__nullable) error {
    const char *str = generator.asciiString;
    if (str[0] != '0' || str[1] != 'x') {
        SET_ERROR_CODE_LOCALIZED(-50, @"Generator value must begin with \"0x\".");
        return NO;
    }
    if (generator.length != 18) {
        SET_ERROR_CODE_LOCALIZED(-50, ([NSString stringWithFormat:@"Generator value must have length 18. Actual: %d", (int)generator.length]));
        return NO;
    }
    for (const char *ptr = str + 2; *ptr != '\0'; ptr++) {
        if (isdigit(*ptr)) {
            continue;
        }
        if (*ptr < 'a' || *ptr > 'f') {
            SET_ERROR_CODE_LOCALIZED(-50, ([NSString stringWithFormat:@"Invalid character '%c' in generator at index %d.", *ptr, (int)(ptr - str)]));
            return NO;
        }
    }
    return YES;
}
static NSString *path;
+ (NSString *) savingDestination {
    return path;
}
+ (void) setSavingDestination:(NSString *)savingDestination {
    path = savingDestination;
}
#pragma mark - Init
- (instancetype) initWithFirmwareURL: (NSString *) urlInString {
    return [self initWithFirmwareURL:urlInString DeviceBoardConfiguration:nil Ecid:nil];
}
- (instancetype) initWithFirmwareURL: (NSString *) urlInString DeviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration {
    return [self initWithFirmwareURL:urlInString DeviceBoardConfiguration:deviceBoardConfiguration Ecid:nil];
}
- (instancetype) initWithFirmwareURL: (NSString *) urlInString DeviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration Ecid: (nullable NSString *) ecid {
    self = [super init];
    if (self) {
        self.firmwareURL = urlInString;
        auto deviceInfo = deviceBoardConfiguration ? findDeviceInfoForSpecifiedConfiguration(deviceBoardConfiguration.asciiString) : nullptr;
        self.deviceRequest = new iDeviceTSSRequest(urlInString.asciiString, deviceInfo, parseECID(ecid.asciiString));
        id obj = [NSUserDefaults.standardUserDefaults objectForKey:@"Timeout"];
        self.timeout = [obj isKindOfClass:[NSNumber class]] ? [obj integerValue] : 7;
    }
    return self;
}
#pragma mark - Getter & Setter
- (NSString *) deviceModel {
    return self.deviceRequest->getDeviceInfo() ? [NSString stringWithCStringASCII:self.deviceRequest->getDeviceInfo()->deviceModel] : nil;
}
- (NSString *) deviceBoardConfig {
    return self.deviceRequest->getDeviceInfo() ? [NSString stringWithCStringASCII:self.deviceRequest->getDeviceInfo()->deviceBoardConfiguration] : nil;
}
- (BOOL) isOTAVersion {
    return self.OTADeviceVersion != nullptr;
}
- (NSString *) version {
    if (self.otaVersion) {
        return [NSString stringWithCStringASCII:self.OTADeviceVersion->getVersion().c_str()];
    }
    if (self.parsedDeviceVersion) {
        return [NSString stringWithCStringASCII:self.parsedDeviceVersion->getVersion().c_str()];
    }
    return nil;
}
- (NSString *) buildID {
    auto buildid = (self.OTADeviceVersion ? self.OTADeviceVersion : self.parsedDeviceVersion)->getBuildID();
    if (buildid.empty()) {
        return nil;
    }
    return [NSString stringWithCStringASCII:buildid.c_str()];
}
- (DeviceVersion *) parsedDeviceVersion {
    if (_parsedDeviceVersion == nullptr) {
        NSString *destinationFirmwareName = self.firmwareURL.lastPathComponent;
        // capture version_buildID
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"_(\\d+(?:\\.\\d+)+)_([a-z0-9A-Z]+)_(R|r)estore." options:(NSRegularExpressionOptions)0 error:nil];
        NSTextCheckingResult *matchedResult = [regex matchesInString:destinationFirmwareName options:(NSMatchingOptions)0 range:NSMakeRange(0, destinationFirmwareName.length)].firstObject;
        NSString *parsedVersion = destinationFirmwareName;  // if fails, use default.
        NSString *parsedBuildID = nil;
        bool isOTA = false;
        if (matchedResult.numberOfRanges == 4) {
            // whole name, version, buildid, (R|r)
            parsedVersion = [destinationFirmwareName substringWithRange:[matchedResult rangeAtIndex:1]];
            parsedBuildID = [destinationFirmwareName substringWithRange:[matchedResult rangeAtIndex:2]];
        }
        else {
            regex = [NSRegularExpression regularExpressionWithPattern:@"(.+).zip" options:(NSRegularExpressionOptions)0 error:nil];
            matchedResult = [regex matchesInString:destinationFirmwareName options:(NSMatchingOptions)0 range:NSMakeRange(0, destinationFirmwareName.length)].firstObject;
            if (matchedResult.numberOfRanges == 2) {
                isOTA = true;
                // OTA archive. Must download buildmanifest to fill deviceversion.
                parsedVersion = [destinationFirmwareName substringWithRange:[matchedResult rangeAtIndex:1]];
                delete self.OTADeviceVersion;
                self.OTADeviceVersion = new DeviceVersion;  // need to be filled.
            }
            else NSLog(@"Failed to parse url. Maybe it is an ota archive? Continue with original name. ");
        }
        _parsedDeviceVersion = new DeviceVersion(parsedVersion.asciiString, parsedBuildID ? parsedBuildID.asciiString : "", isOTA);
    }
    return _parsedDeviceVersion;
}
- (NSError *) firmwareURLError {
    const auto status = self.deviceRequest->validateFirmwareURL(*self.parsedDeviceVersion);
    if (self.OTADeviceVersion && self.OTADeviceVersion->isOTAFirmware() == false) {
        self.deviceRequest->fillDeviceVersionWithCurrentBuildManifest(*self.OTADeviceVersion);
        self.OTADeviceVersion->setOTAFirmware(true);
    }
    return status.code ? [NSError errorWithDomain:TSSRequestErrorDomain code:status.code userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithCStringASCII:status.reason.c_str()]}] : nil;
}
- (NSString *) ecid {
    return @(self.deviceRequest->getECID()).stringValue;
}
- (void) setEcid:(NSString *) ecid {
    if (ecid) {
        const auto parsedECID = parseECID(ecid.asciiString);
        if (!parsedECID) {
            return;
        }
        self.deviceRequest->setECID(parsedECID);
    }
    else {
        self.deviceRequest->setECID(0);
    }
}
- (NSArray<NSString *> *) supportedDevices {
    if (!self.deviceRequest->supportedDevice()) {
        return nil;
    }
    const auto &supportedList = *self.deviceRequest->supportedDevice();
    if (supportedList.empty()) {
        return (_supportedDevices = @[]);
    }
    if (supportedList.size() == 1) {
        return (_supportedDevices = @[[NSString stringWithCStringASCII:supportedList[0]->deviceModel]]);
    }
    NSMutableDictionary<NSString *, NSString *> *itemPair = [NSMutableDictionary dictionary];
    for (auto &deviceInfo : supportedList) {
        itemPair[[NSString stringWithCStringASCII:deviceInfo->deviceBoardConfiguration]] = [NSString stringWithCStringASCII:deviceInfo->deviceModel];
    }
    NSCountedSet<NSString *> *deviceModelSet = [NSCountedSet setWithArray:itemPair.allValues];
    [[itemPair copy] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull deviceBoard, NSString * _Nonnull deviceModel, BOOL * _Nonnull stop) {
        if ([deviceModelSet countForObject:deviceModel] > 1) {
            itemPair[deviceBoard] = [NSString stringWithFormat:@"%@ (%@)", deviceModel, deviceBoard];
        }
    }];
    NSMutableCharacterSet *customSet = [NSMutableCharacterSet characterSetWithCharactersInString:@",("];
    [customSet formUnionWithCharacterSet:NSCharacterSet.letterCharacterSet];
    return (_supportedDevices = [itemPair.allValues sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull obj1, NSString * _Nonnull obj2) {
        NSArray<NSString *> * (^split) (NSString *) = ^NSArray<NSString *> * (NSString *string) {
            auto array = [string componentsSeparatedByCharactersInSet:customSet];
            NSMutableArray<NSString *> *mutableArray = [array mutableCopy];
            [array enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString * _Nonnull obj, NSUInteger index, BOOL * _Nonnull stop) {
                if (obj.length == 0) {
                    [mutableArray removeObjectAtIndex:index];
                }
            }];
            return [mutableArray subarrayWithRange:NSMakeRange(0, 2)];
        };
        auto c1 = split(obj1), c2 = split(obj2);
        for (int a = 0; a < 2; a++) {
            NSInteger num1 = c1[a].integerValue, num2 = c2[a].integerValue;
            if (num1 < num2) {
                return NSOrderedAscending;
            }
            if (num1 > num2) {
                return NSOrderedDescending;
            }
        }
        return NSOrderedSame;
    }]);
}
- (void) setDelegate:(id<TSSRequestDelegate>)delegate {
    _delegate = delegate;
    if (delegate) {
        self.deviceRequest->setDelegate((__bridge void *)self, &messageOutputFromRequest);
    }
    else self.deviceRequest->setDelegate(nullptr, nullptr);
}
- (NSString *) generator {
    return self.deviceRequest->getGenerator()[0] ? [NSString stringWithCStringASCII:self.deviceRequest->getGenerator()] : nil;
}
- (void) setGenerator:(NSString *)generator {
    self.deviceRequest->setGenerator(generator.asciiString);
}
- (nullable TSSBuildIdentity *) currentBuildIdentity {
    auto container = self.deviceRequest->getEraseUpdateBuildIdentityForCurrentModel(*self.parsedDeviceVersion);
    TSSBuildIdentity *buildIdentity = [[TSSBuildIdentity alloc] initWithUpdate:container.second ? container.second->buffer : nil EraseRestore:container.first ? container.first->buffer : nil];
    delete container.first;
    delete container.second;
    return buildIdentity;
}
- (NSString *) apnonce {
    return self.deviceRequest->getApNonce() ? [NSString stringWithCStringASCII:self.deviceRequest->getApNonce()] : nil;
}
- (NSString *) sepnonce {
    return self.deviceRequest->getSepNonce() ? [NSString stringWithCStringASCII:self.deviceRequest->getSepNonce()] : nil;
}
- (void) setApnonce:(NSString *)apnonce {
    self.deviceRequest->setApNonce(apnonce.asciiString);
}
- (void) setSepnonce:(NSString *)sepnonce {
    self.deviceRequest->setSepNonce(sepnonce.asciiString);
}
- (NSTimeInterval) timeout {
    return self.deviceRequest->getTimeout();
}
- (void) setTimeout:(NSTimeInterval)timeout {
    self.deviceRequest->setTimeout(timeout);
}
#pragma mark - Methods
- (void) selectDeviceInSupportedList: (NSString *) device {
    if (!_supportedDevices) {
        return;
    }
    NSMutableArray<NSString *> *splitted = [[device componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"() "]] mutableCopy];
    [(NSArray *)[splitted copy] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.length == 0) {
            [splitted removeObjectAtIndex:idx];
        }
    }];
    const auto func = splitted.count == 1 ? &findDeviceInfoForSpecifiedModel : &findDeviceInfoForSpecifiedConfiguration;
    NSAssert1(splitted.count == 2 || splitted.count == 1, @"Expected only 1 or 2 elements in array. Actual: %@", @(splitted.count));
    self.deviceRequest->setDeviceInfo(func(splitted.lastObject.asciiString));
    self.deviceRequest->writeBuildManifestToFile(*self.parsedDeviceVersion);
    _supportedDevices = nil;
}
- (nullable NSString *) fetchSHSHBlobsWithError: (NSError *__autoreleasing *__nullable) error {
    const auto connectionError = self.firmwareURLError;
    if (connectionError) {
        if (error) {
            *error = connectionError;
        }
        return nil;
    }
    auto shshDataInBufferContainer = self.deviceRequest->getShshblobsData(*self.parsedDeviceVersion);
    if (shshDataInBufferContainer.buffer == nullptr || shshDataInBufferContainer.length == 0) {
        SET_ERROR_CODE_LOCALIZED(-2, @"An error has occurred when fetching shsh data.");
        return nil;
    }
    if (self.deviceRequest->isRequestConnectionCanceled()) {
        shshDataInBufferContainer.freeBuffer();
        SET_ERROR_CODE_LOCALIZED(-99, @"User has canceled request.");
        return nil;
    }
    NSAssert(TSSRequest.savingDestination != nil, @"Destination is not set.");
    // fileName: ecid_model_board_version-buildid_apnonce.shsh2
    NSString *filePath = [TSSRequest.savingDestination stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@_%@_%s_%s.shsh2", self.ecid, self.deviceModel, self.deviceBoardConfig, (self.OTADeviceVersion ? self.OTADeviceVersion : self.parsedDeviceVersion)->description().c_str(), self.deviceRequest->getApNonce()]];
    FILE *f = fopen(filePath.asciiString, "w");
    if (!f || fwrite(shshDataInBufferContainer.buffer, sizeof(char), shshDataInBufferContainer.length, f) != shshDataInBufferContainer.length * sizeof(char)) {
        SET_ERROR_CODE_LOCALIZED(-3, @"An error has occurred when writing shsh data to destination.");
        filePath = nil;
    }
    fclose(f);
    shshDataInBufferContainer.freeBuffer();
    return filePath;
}
- (TSSFirmwareSigningStatus) checkSigningStatusWithError:(NSError *__autoreleasing *__nullable) error {
    BOOL isSigned = NO;
    try {
        isSigned = self.deviceRequest->isCurrentBuildManifestSigned(*self.parsedDeviceVersion);
    } catch (const iDeviceTSSRequest::TSSRequestError &tssError) {
        SET_ERROR_CODE_LOCALIZED(tssError.code, [NSString stringWithCStringASCII:tssError.reason.c_str()]);
        return TSSFirmwareSigningStatusError;
    }
    return (isSigned ? TSSFirmwareSigningStatusSigned : TSSFirmwareSigningStatusNotSigned);
}
- (void) checkSigningStatusWithCompletionHandler:(nonnull void (^)(TSSFirmwareSigningStatus status, NSError *__nullable error))completionHandler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        TSSFirmwareSigningStatus status = [self checkSigningStatusWithError:&error];
        completionHandler(status, error);
    });
}
- (void) cancelGlobalConnection {
    self.deviceRequest->cancelConnection();
}
- (void)dealloc
{
    delete self.deviceRequest;
    delete self.parsedDeviceVersion;
    delete self.OTADeviceVersion;
}
@end
