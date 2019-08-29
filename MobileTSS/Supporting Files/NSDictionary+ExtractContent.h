//
//  NSString+ExtractContent.h
//  MobileTSS
//
//  Created by User on 12/22/18.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (ExtractContent)

+ (nullable NSDictionary *) dictionaryWithContentsOfFile: (nonnull NSString *) path Head: (nonnull NSString *) head IncludedTail: (nonnull NSString *) tail;

@end
