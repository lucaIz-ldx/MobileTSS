//
//  TSSBuildIdentity.h
//  MobileTSS
//
//  Created by User on 1/15/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface TSSBuildIdentity : NSObject
@property (readonly, nonatomic, nullable) void *updateInstall NS_SWIFT_UNAVAILABLE("");
@property (readonly, nonatomic, nullable) void *eraseInstall NS_SWIFT_UNAVAILABLE("");

@property (readonly, copy, nonatomic) NSString *deviceBoardConfiguration;

+ (nullable NSArray<TSSBuildIdentity *> *) buildIdentitiesInBuildManifest: (NSDictionary<NSString *, id> *) buildManifest forDeviceModel: (NSString *) deviceModel;

- (instancetype) init NS_UNAVAILABLE;
- (nullable instancetype) initWithUpdate: (nullable void *) update EraseRestore: (nullable void *) erase NS_DESIGNATED_INITIALIZER NS_SWIFT_UNAVAILABLE("Use BuildManifest Initializer.");

- (nullable instancetype) initWithBuildManifest: (NSDictionary<NSString *, id> *) buildManifest DeviceBoard: (NSString *) deviceBoard;

@end
NS_ASSUME_NONNULL_END
