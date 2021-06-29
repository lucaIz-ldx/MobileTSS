//
//  NSString+ASCIIString.m
//  MobileTSS
//
//  Created by User on 8/14/20.
//

#import "NSString+ASCIIString.h"

@implementation NSString (ASCIIString)

+ (instancetype) stringWithCStringASCII:(const char *)cString {
    return [self stringWithCString:cString encoding:NSASCIIStringEncoding];
}
- (const char *) asciiString {
    return [self cStringUsingEncoding:NSASCIIStringEncoding];
}

@end
