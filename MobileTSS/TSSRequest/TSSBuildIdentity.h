//
//  TSSBuildIdentity.h
//  MobileTSS
//
//  Created by User on 1/15/19.
//

#import <Foundation/Foundation.h>
#import "TSSFirmwareVersion.h"

NS_ASSUME_NONNULL_BEGIN
@interface TSSBuildIdentity : NSObject
@property (readonly, nonatomic, nullable) void *updateInstall NS_SWIFT_UNAVAILABLE("Accessing raw pointer of buildId is not supported.");
@property (readonly, nonatomic, nullable) void *eraseInstall NS_SWIFT_UNAVAILABLE("Accessing raw pointer of buildId is not supported.");

@property (readonly, copy, nonatomic) NSString *deviceBoardConfiguration;

+ (nullable NSArray<TSSBuildIdentity *> *) buildIdentitiesInBuildManifestData: (NSData *) buildManifestData forDeviceModel: (NSString *) deviceModel;
+ (NSString *) buildIdentityCacheFileNameWithDeviceBoard: (NSString *) deviceBoard version: (NSString *) version buildId: (NSString *) buildId;

- (instancetype) init NS_UNAVAILABLE;
- (nullable instancetype) initWithUpdateInstall: (nullable void *) updateInstall eraseInstall: (nullable void *) eraseInstall NS_DESIGNATED_INITIALIZER NS_SWIFT_UNAVAILABLE("Use BuildIdentitiesData Initializer.");
- (nullable instancetype) initWithBuildManifestPlistDictNode: (void *) plistDictNode deviceBoard: (NSString *) deviceBoard NS_SWIFT_UNAVAILABLE("Use BuildManifestData Initializer.");

- (nullable instancetype) initWithBuildManifestData: (NSData *) buildManifestData deviceBoard: (NSString *) deviceBoard;

- (nullable instancetype) initWithBuildIdentitiesData: (NSData *) buildIdentityData;
- (BOOL) writeBuildIdentitiesToFile: (NSString *) filePath error: (NSError **) error;

@end
NS_ASSUME_NONNULL_END
