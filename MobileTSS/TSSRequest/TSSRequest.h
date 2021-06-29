//
//  TSSRequest.h
//  MobileTSS
//
//  Created by User on 7/8/18.
//  Copyright © 2018 User. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSSBuildIdentity.h"
#import "TSSFirmwareVersion.h"
#import "TSSNonce.h"
#import "TSSECID.h"

typedef NS_ENUM(NSInteger, TSSFirmwareSigningStatus) {
    TSSFirmwareSigningStatusNotSigned = 0,
    TSSFirmwareSigningStatusSigned = 1,
    TSSFirmwareSigningStatusError = -1,
};
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSErrorDomain const TSSRequestErrorDomain;

@class TSSRequest;
@protocol TSSRequestDelegate <NSObject>
- (void) request: (TSSRequest *) request verboseOutput: (NSString *) output;
@end

// concurrency is not supported; make sure call APIs on single thread 
@interface TSSRequest : NSObject
/// TSSRequest will cache downloaded buildmanifest to directory if not nil; default is nil
@property (class, copy, nonatomic, nullable) NSString *buildManifestCacheDirectory;

/// Connection timeout in seconds. TSSRequest will retry to connect after timeout expires. Default is 0 which is unlimited.
@property (nonatomic) NSTimeInterval timeout;
@property (weak, nonatomic) id<TSSRequestDelegate> delegate;

// nonnull only if a valid deviceboard is provided when init, or a device is selected after URL validation.
@property (readonly, copy, nonatomic, nullable) NSString *deviceModel, *deviceBoardConfig;

// nonnull if deviceboard is nil when init and URL validation succeeds.
@property (readonly, copy, nonatomic, nullable) NSArray<NSString *> *supportedDevices;

// firmwareVersion will be nonnull after URL validation succeeds
@property (readonly, nonatomic, nullable) TSSFirmwareVersion *firmwareVersion;
// buildIdentity will be nonnull after URL validation succeeds and deviceBoard is determined (nonnull)
@property (readonly, nonatomic, nullable) TSSBuildIdentity *currentBuildIdentity;

// By default TSSRequest will generate a random ECID if ecid is not provided when init; set to nil will generate a new random ecid.
@property (strong, nonatomic, null_resettable) TSSECID *ecid;

// these properties will be nonnull after checking signing status (depending on device, pre-A7 devices do not have sepnonce)
@property (strong, nonatomic, nullable) TSSAPNonce *apnonce;
@property (strong, nonatomic, nullable) TSSSEPNonce *sepnonce;
@property (strong, nonatomic, nullable) TSSGenerator *generator;

- (instancetype) init NS_UNAVAILABLE;
// use nil for deviceBoard to indicate unknown machine model. A list of machine models will be fetched after validate URL.
- (instancetype) initWithFirmwareURL: (NSString *) urlInString;
- (instancetype) initWithFirmwareURL: (NSString *) urlInString deviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration;
- (instancetype) initWithFirmwareURL: (NSString *) urlInString deviceBoardConfiguration: (nullable NSString *) deviceBoardConfiguration ecid: (nullable TSSECID *) ecid NS_DESIGNATED_INITIALIZER;

- (BOOL) validateURLWithError:(NSError *__autoreleasing  _Nullable *)error;
- (void) validateURLWithCompletionHandler: (void (^) (BOOL result, NSError *__nullable error)) completionHandler;

- (void) selectDeviceInSupportedListAtIndex: (NSUInteger) index;
// block caller thread.
- (TSSFirmwareSigningStatus) checkSigningStatusWithError:(NSError *__autoreleasing *__nullable) error;
// Asynchronous
- (void) checkSigningStatusWithCompletionHandler:(void (^)(TSSFirmwareSigningStatus status, NSError *__nullable error))completionHandler;

// block caller thread
- (nullable NSString *) downloadSHSHBlobsAtDirectory: (NSString *) directory error: (NSError *__autoreleasing *__nullable) error;
// completionHandler will be executed on a background thread
- (void) downloadSHSHBlobsAtDirectory: (NSString *) directory completionHandler: (void (^) (NSString *__nullable fileName, NSError *__nullable error)) completionHandler;

// use this method to cancel all connections (validation, signing status check, and download blobs)
// this method is safe to call on other threads if using thread-blocking methods above
- (void) cancel;

@end
NS_ASSUME_NONNULL_END
