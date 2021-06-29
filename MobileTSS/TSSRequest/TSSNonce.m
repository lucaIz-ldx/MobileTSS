//
//  TSSNonce.m
//  MobileTSS
//
//  Created by User on 8/14/20.
//

#import "TSSNonce.h"
#import "TSSHelper.h"
#import "NSString+ASCIIString.h"
#import "TSSC.h"

#define SET_ERROR_CODE_LOCALIZED(errCode, msg) do {if (error){\
*error = [NSError errorWithDomain:TSSNonceErrorDomain code:errCode userInfo:@{NSLocalizedDescriptionKey : (msg)}];\
}} while (0)

static NSErrorDomain const TSSNonceErrorDomain = @"TSSNonceErrorDomain";

@interface TSSNonce () {
    char internalNonce[100];
    char readableNonce[100];
}
@property (nonatomic) size_t internalNonceLength;
@end

@implementation TSSNonce
+ (BOOL)isNonceEntanglingEnabledForDeviceModel:(NSString *)deviceModel {
    NSArray<NSString *> *separated = [deviceModel componentsSeparatedByString:@","];
    if ([deviceModel containsString:@"iPhone"]) {
        // @"iphone".length = 6
        return [separated.firstObject substringFromIndex:6].integerValue >= 11;
    }
    if ([deviceModel containsString:@"iPad"]) {
        // @"ipad".length = 4
        return [separated.firstObject substringFromIndex:4].integerValue >= 8;
    }
    return NO;
}
+ (BOOL)parseNonce:(NSString *)nonceString expectedLength: (size_t) expectedLength error:(NSError *__autoreleasing  _Nullable *)error {
    size_t length = 0;
    char *nonce = parseNonce(nonceString.asciiString, &length);
    if (nonce) {
        free(nonce);
        if (length != expectedLength) {
            SET_ERROR_CODE_LOCALIZED(-50, ([NSString stringWithFormat:@"The parsed length should be %d but actual is %d", (int)expectedLength, (int)length]));
            return NO;
        }
        return YES;
    }
    SET_ERROR_CODE_LOCALIZED(-51, @"Failed to parse nonce.");
    return NO;
}
- (instancetype) initWithNonceString:(NSString *)nonceString expectedLength: (size_t) expectedLength error:(NSError *__autoreleasing  _Nullable *)error {
    self = [super init];
    if (self) {
        size_t length = 0;
        char *nonce = parseNonce(nonceString.asciiString, &length);
        if (!nonce) {
            SET_ERROR_CODE_LOCALIZED(-51, @"Failed to parse nonce.");
            return nil;
        }
        if (length != expectedLength) {
            free(nonce);
            SET_ERROR_CODE_LOCALIZED(-50, ([NSString stringWithFormat:@"The parsed length should be %d but actual is %d", (int)expectedLength, (int)length]));
            return nil;
        }
        memcpy(internalNonce, nonce, expectedLength);
        free(nonce);
        self.internalNonceLength = expectedLength;
        [nonceString getCString:readableNonce maxLength:sizeof(readableNonce)/sizeof(char) encoding:NSASCIIStringEncoding];
    }
    return self;
}
- (instancetype) initWithInternalNonceBuffer:(const char *)internalNonceBuffer length: (size_t) length {
    self = [super init];
    if (self) {
        const size_t noncelength = length * 2;
        NSAssert(length < sizeof(internalNonce)/sizeof(char), @"Internal nonce buffer overflow");
        NSAssert(noncelength + 2 < sizeof(readableNonce)/sizeof(char), @"readable nonce buffer overflow");
        self.internalNonceLength = length;
        memcpy(internalNonce, internalNonceBuffer, length);
        for (int i = 0; i < noncelength; i += 2) {
            snprintf(&readableNonce[i], noncelength - i + 1, "%02x", ((const unsigned char *)internalNonceBuffer)[i / 2]);
        }
    }
    return self;
}
- (instancetype) initWithNonceString:(NSString *)nonceString deviceModel:(NSString *)deviceModel error:(NSError *__autoreleasing  _Nullable *)error {
    self = [super init];
    return self;
}
- (NSString *)nonceString {
    return [NSString stringWithCStringASCII:readableNonce];
}
- (TSSDataBuffer) internalNonceBufferCopy {
    TSSDataBuffer dataBuffer = {malloc(self.internalNonceLength), self.internalNonceLength};
    memcpy(dataBuffer.buffer, internalNonce, self.internalNonceLength);
    return dataBuffer;
}
@end

@implementation TSSAPNonce
+ (size_t)requiredAPNonceLengthForDeviceModel:(NSString *)deviceModel {
    return apNonceLengthForDeviceModel(deviceModel.asciiString);
}
+ (BOOL)parseAPNonce:(NSString *)apnonce deviceModel:(NSString *)deviceModel error:(NSError *__autoreleasing  _Nullable *)error {
    return [self parseNonce:apnonce expectedLength:apNonceLengthForDeviceModel(deviceModel.asciiString) error:error];
}
- (instancetype)initWithNonceString:(NSString *)nonceString deviceModel:(NSString *)deviceModel error:(NSError *__autoreleasing  _Nullable *)error {
    return [super initWithNonceString:nonceString expectedLength:apNonceLengthForDeviceModel(deviceModel.asciiString) error:error];
}
@end

@implementation TSSSEPNonce
+ (size_t)requiredSEPNonceLengthForDeviceModel:(NSString *)deviceModel {
    return requiredSepNonceLengthForModel(deviceModel.asciiString);
}
+ (BOOL)parseSEPNonce:(NSString *)sepnonce deviceModel:(NSString *)deviceModel error:(NSError *__autoreleasing  _Nullable *)error {
    return [self parseNonce:sepnonce expectedLength:requiredSepNonceLengthForModel(deviceModel.asciiString) error:error];
}
- (instancetype)initWithNonceString:(NSString *)nonceString deviceModel:(NSString *)deviceModel error:(NSError *__autoreleasing  _Nullable *)error {
    return [super initWithNonceString:nonceString expectedLength:requiredSepNonceLengthForModel(deviceModel.asciiString) error:error];
}

@end

@interface TSSGenerator () {
    char rawBytes[19];
}
@end
@implementation TSSGenerator
+ (BOOL) parseGenerator: (NSString *) generator error: (NSError *__autoreleasing *__nullable) error {
    const char *str = generator.asciiString;
    if (str[0] != '0' || str[1] != 'x') {
        SET_ERROR_CODE_LOCALIZED(-100, @"Generator value must begin with \"0x\".");
        return NO;
    }
    if (generator.length != 18) {
        SET_ERROR_CODE_LOCALIZED(-101, ([NSString stringWithFormat:@"Generator value must have length 18. Actual: %d", (int)generator.length]));
        return NO;
    }
    for (const char *ptr = str + 2; *ptr != '\0'; ptr++) {
        if (isdigit(*ptr)) {
            continue;
        }
        if (*ptr < 'a' || *ptr > 'f') {
            SET_ERROR_CODE_LOCALIZED(-102, ([NSString stringWithFormat:@"Invalid character '%c' in generator at index %d.", *ptr, (int)(ptr - str)]));
            return NO;
        }
    }
    return YES;
}
- (instancetype)initWithRawBytes: (const char *) generatorRawBytes {
    self = [super init];
    if (self) {
        memcpy(rawBytes, generatorRawBytes, sizeof(rawBytes)/sizeof(char) - 1);
        rawBytes[generatorBufferSize - 1] = 0;
    }
    return self;
}
- (instancetype)initWithString:(NSString *)string error:(NSError *__autoreleasing  _Nullable *)error {
    if ([TSSGenerator parseGenerator:string error:error]) {
        return [self initWithRawBytes:string.asciiString];
    }
    return nil;
}
- (NSString *)generatorString {
    return [NSString stringWithCStringASCII:rawBytes];
}
@end
