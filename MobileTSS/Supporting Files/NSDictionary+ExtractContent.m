//
//  NSString+ExtractContent.m
//  MobileTSS
//
//  Created by User on 12/22/18.
//

#import "NSDictionary+ExtractContent.h"

@implementation NSDictionary (ExtractContent)

+ (nullable NSDictionary *) dictionaryWithContentsOfFile: (nonnull NSString *) path Head: (nonnull NSString *) head IncludedTail: (nonnull NSString *) tail
{
    FILE *f = fopen(path.UTF8String, "rb");
    if (!f) {
        return nil;
    }
    fseek(f, 0, SEEK_END);
    const size_t fileSize = ftell(f);
    rewind(f);
    char *fileContent = malloc(sizeof(char) * fileSize);
    if (!fileContent) {
        printf("Insufficient memory. Abort.\n");
        fclose(f);
        return NULL;
    }
    if (fileSize != fread(fileContent, sizeof(char), fileSize, f)) {
        printf("Failed to read the file.\n");
        fclose(f);
        free(fileContent);
        return NULL;
    }
    fclose(f);
    const char *headpos = memmem(fileContent, fileSize, [head cStringUsingEncoding:NSASCIIStringEncoding], head.length);
    if (!headpos) {
        free(fileContent);
        return nil;
    }
    const char *tailpos = memmem(headpos, fileSize - (headpos - fileContent), [tail cStringUsingEncoding:NSASCIIStringEncoding], tail.length) + tail.length;
    if (!tailpos) {
        free(fileContent);
        return nil;
    }
    id parsedDictionary = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytesNoCopy:(char *)headpos length:tailpos - headpos freeWhenDone:NO] options:0 format:nil error:nil];
    free(fileContent);
    if ([parsedDictionary isKindOfClass:[NSDictionary class]]) {
        return parsedDictionary;
    }
    return nil;
}

@end
