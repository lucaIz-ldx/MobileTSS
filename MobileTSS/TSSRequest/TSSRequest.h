//
//  TSSRequest.h
//  MobileTSS
//
//  Created by User on 7/8/18.
//  Copyright © 2018 User. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSSBuildIdentity.h"

typedef NS_ENUM(NSInteger, TSSFirmwareSigningStatus) {
    TSSFirmwareSigningStatusNotSigned = 0,
    TSSFirmwareSigningStatusSigned = 1,
    TSSFirmwareSigningStatusError = -1,
};
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *const TSSRequestErrorDomain;

@class TSSRequest;
@protocol TSSRequestDelegate <NSObject>
- (void) request: (TSSRequest *) request sendMessageOutput: (NSString *) output;
@end

@interface TSSRequest : NSObject
@property (class, readonly, copy, nonatomic, nullable) NSString *localECID;

@property (readonly, nonatomic, getter=isOTAVersion) BOOL otaVersion;

@property (weak, nonatomic) id<TSSRequestDelegate> delegate;
// nonnull only if valid firmware url and device board is nonnull when init, and a device is selected.
@property (readonly, copy, nonatomic, nullable) NSString *deviceModel, *deviceBoardConfig, *version, *buildID;
// nonnull if device board is undetermined (nil) when init.
@property (readonly, copy, nonatomic, nullable) NSArray<NSString *> *supportedDevices;
// set nil will generate a random ecid.
@property (copy, nonatomic, null_resettable) NSString *ecid;

@property (copy, nonatomic, nullable) NSString *apnonce, *sepnonce;
@property (copy, nonatomic, nullable) NSString *generator;

// block caller thread.
@property (readonly, nonatomic, nullable) NSError *firmwareURLError;
// download from internet if no cache found.
@property (readonly, nonatomic, nullable) TSSBuildIdentity *currentBuildIdentity;
// use class property
+ (BOOL) setECIDToPreferences: (nullable NSString *) ecid;

+ (int64_t) parseECIDInString: (NSString *) ecidInString;
+ (void) setBuildManifestStorageLocation: (NSString *) location;
+ (BOOL) parseNonceInString: (NSString *) apnonce error: (NSError *__autoreleasing *__nullable) error;
+ (BOOL) parseGeneratorInString: (NSString *) generator error: (NSError *__autoreleasing *__nullable) error;

- (instancetype) init NS_UNAVAILABLE;
// use nil for deviceBoard to indicate unknown machine model. A list of machine models will be fetched after validate URL.
- (instancetype) initWithFirmwareURL: (NSString *) urlInString;
- (instancetype) initWithFirmwareURL: (NSString *) urlInString DeviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration;
- (instancetype) initWithFirmwareURL: (NSString *) urlInString DeviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration Ecid: (nullable NSString *) ecid NS_DESIGNATED_INITIALIZER;

- (void) selectDeviceInSupportedList: (NSString *) device;
// block caller thread.
- (TSSFirmwareSigningStatus) checkSigningStatusWithError:(NSError *__autoreleasing *__nullable) error;
// Asynchronous
- (void) checkSigningStatusWithCompletionHandler:(nonnull void (^)(TSSFirmwareSigningStatus status, NSError *__nullable error))completionHandler;

// block caller thread
- (nullable NSString *) fetchSHSHBlobsWithError: (NSError *__autoreleasing *__nullable) error;

- (void) cancelGlobalConnection;

@end
NS_ASSUME_NONNULL_END
