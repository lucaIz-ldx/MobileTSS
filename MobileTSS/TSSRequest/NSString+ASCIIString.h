//
//  NSString+ASCIIString.h
//  MobileTSS
//
//  Created by User on 8/14/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (ASCIIString)
@property (readonly, nonatomic, nullable) const char *asciiString;
+ (instancetype) stringWithCStringASCII:(const char *)cString;

@end

NS_ASSUME_NONNULL_END
