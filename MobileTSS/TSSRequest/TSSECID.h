//
//  TSSECID.h
//  MobileTSS
//
//  Created by User on 8/14/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSSECID : NSObject
@property (class, nonatomic, nullable) TSSECID *localECID;
@property (class, readonly, nonatomic) TSSECID *randomECID;

@property (readonly, nonatomic) NSString *ecidString;
@property (readonly, nonatomic) int64_t numericECID;

- (instancetype) init NS_UNAVAILABLE;
- (nullable instancetype) initWithString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
