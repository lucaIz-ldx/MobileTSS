//
//  TSSFirmwareVersion.h
//  MobileTSS
//
//  Created by User on 8/12/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSSFirmwareVersion : NSObject
@property (readonly, nonatomic) BOOL isOTAFirmware;

@property (readonly, nonatomic) NSString *version, *buildID;
@property (readonly, nonatomic, nullable) NSString *OTAIdentifier;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithVersion: (NSString *) version buildID: (NSString *) buildID otaIdentifier: (nullable NSString *) otaIdentifier;
- (nullable instancetype) initWithFirmwareURLString : (NSString *) firmwareURLString;

- (BOOL) updateFirmwareVersionWithBuildManifest: (void *) buildManifest error: (NSError * __autoreleasing *) error;

@end

NS_ASSUME_NONNULL_END
