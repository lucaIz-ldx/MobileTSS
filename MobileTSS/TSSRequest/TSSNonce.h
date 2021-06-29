//
//  TSSNonce.h
//  MobileTSS
//
//  Created by User on 8/14/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// abstract base class for apnonce and sepnonce; do not create instances directly.
@interface TSSNonce : NSObject
@property (readonly, nonatomic) NSString *nonceString;
+ (BOOL) isNonceEntanglingEnabledForDeviceModel: (NSString *) deviceModel;

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithInternalNonceBuffer:(const char *)internalNonceBuffer length: (size_t) length NS_SWIFT_UNAVAILABLE("Use NonceString Initializer"); 

- (nullable instancetype) initWithNonceString: (NSString *) nonceString deviceModel: (NSString *) deviceModel error: (NSError *__autoreleasing *__nullable) error;

@end

@interface TSSAPNonce : TSSNonce

+ (size_t) requiredAPNonceLengthForDeviceModel: (NSString *) deviceModel;
+ (BOOL) parseAPNonce: (NSString *) apnonce deviceModel: (NSString *) deviceModel error: (NSError *__autoreleasing *__nullable) error;

@end

@interface TSSSEPNonce : TSSNonce

+ (size_t) requiredSEPNonceLengthForDeviceModel: (NSString *) deviceModel;
+ (BOOL) parseSEPNonce: (NSString *) sepnonce deviceModel: (NSString *) deviceModel error: (NSError *__autoreleasing *__nullable) error;

@end


@interface TSSGenerator : NSObject
@property (readonly, nonatomic) NSString *generatorString;

- (instancetype) init NS_UNAVAILABLE;
+ (BOOL) parseGenerator: (NSString *) generator error: (NSError *__autoreleasing *__nullable) error;
- (nullable instancetype) initWithString: (NSString *) string error: (NSError *__autoreleasing *__nullable) error;

@end
NS_ASSUME_NONNULL_END
