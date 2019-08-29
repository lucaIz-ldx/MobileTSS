//
//  SHSHFile.h
//  MobileTSS
//
//  Created by User on 1/1/19.
//

#import <Foundation/Foundation.h>
#import "TSSBuildIdentity.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, SHSHImageType) {
    SHSHImageTypeUnknown,
    SHSHImageTypeIMG3,    //
    SHSHImageTypeIM4M,    // Img4 manifest
//    SHSHImageTypeIMG4,    // Img4
//    SHSHImageTypeIM4R,    // Img4 restore?
//    SHSHImageTypeIM4P     // Img4 payload
};

@interface SHSHFile : NSObject

@property (readonly, nonatomic) SHSHImageType imageType;
@property (readonly, nonatomic) NSInteger version;
@property (readonly, nonatomic, getter=isVerificationSupported) BOOL verificationSupported;

@property (readonly, copy, nonatomic, nullable) NSString *ecid;
@property (readonly, copy, nonatomic, nullable) NSString *apnonce;
@property (readonly, copy, nonatomic, nullable) NSString *generator;
@property (readonly, copy, nonatomic, nullable) NSDictionary<NSString *, NSDictionary<NSString *, id> *> *manifestBody;

@property (readonly, copy, nonatomic, nullable) NSString *log;
@property (nonatomic) BOOL verifyGenerator; // set it to false if verify blobs for nonce entangling enabled devices

- (instancetype) init NS_UNAVAILABLE;
- (nullable instancetype) initWithContentsOfFile: (NSString *) path error: (NSError * _Nullable __autoreleasing * _Nullable) error NS_DESIGNATED_INITIALIZER;

- (BOOL) verifyWithBuildIdentity: (TSSBuildIdentity *) buildIdentity error: (NSError * _Nullable __autoreleasing *) error NS_SWIFT_NOTHROW;

@end
NS_ASSUME_NONNULL_END
