//
//  TSSFirmwareVersion.m
//  MobileTSS
//
//  Created by User on 8/12/20.
//

#import "TSSFirmwareVersion.h"
#import <plist/plist.h>

static NSErrorDomain const TSSFirmwareVersionErrorDomain = @"TSSFirmwareVersionErrorDomain";

@interface TSSFirmwareVersion ()
@property (readwrite, nonatomic) NSString *version, *buildID, *OTAIdentifier;
@end

@implementation TSSFirmwareVersion
- (instancetype)initWithVersion:(NSString *)version buildID:(NSString *)buildID otaIdentifier: (nullable NSString *) otaIdentifier {
    self = [super init];
    if (self) {
        self.buildID = buildID;
        self.version = version;
        self.OTAIdentifier = otaIdentifier;
    }
    return self;
}
- (instancetype) initWithFirmwareURLString : (NSString *) firmwareURLString {
    self = [super init];
    if (!self) {
        return nil;
    }
    NSString *destinationFirmwareName = firmwareURLString.lastPathComponent;
    // capture version_buildID
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"_(\\d+(?:\\.\\d+)+)_([a-z0-9A-Z]+)_(R|r)estore." options:(NSRegularExpressionOptions)0 error:nil];
    NSTextCheckingResult *matchedResult = [regex matchesInString:destinationFirmwareName options:(NSMatchingOptions)0 range:NSMakeRange(0, destinationFirmwareName.length)].firstObject;
    if (matchedResult.numberOfRanges == 4) {
        // whole name, version, buildid, (R|r)
        self.version = [destinationFirmwareName substringWithRange:[matchedResult rangeAtIndex:1]];
        self.buildID = [destinationFirmwareName substringWithRange:[matchedResult rangeAtIndex:2]];
        self.OTAIdentifier = nil;
    }
    else {
        regex = [NSRegularExpression regularExpressionWithPattern:@"(.+).zip" options:(NSRegularExpressionOptions)0 error:nil];
        matchedResult = [regex matchesInString:destinationFirmwareName options:(NSMatchingOptions)0 range:NSMakeRange(0, destinationFirmwareName.length)].firstObject;
        if (matchedResult.numberOfRanges == 2) {
            // OTA archive. Must download buildmanifest to set version and buildid
            self.OTAIdentifier = [destinationFirmwareName substringWithRange:[matchedResult rangeAtIndex:1]];
            self.version = self.buildID = TSSFirmwareVersionErrorDomain;
        }
        else return nil;//NSLog(@"Failed to parse url. Maybe it is an ota archive? Continue with original name. ");
    }
    return self;
}
- (BOOL) updateFirmwareVersionWithBuildManifest: (plist_t) buildManifest error: (NSError * __autoreleasing *) error {
    NSParameterAssert(buildManifest != NULL);
    plist_t pbuild = plist_dict_get_item(buildManifest, "ProductBuildVersion");
    plist_t pvers = plist_dict_get_item(buildManifest, "ProductVersion");
    if (pbuild == NULL || pvers == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:TSSFirmwareVersionErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"essential entries in buildmanifest are missing."}];
        }
        return NO;
    }
    char *buildID = NULL, *vers = NULL;
    plist_get_string_val(pbuild, &buildID);
    plist_get_string_val(pvers, &vers);
    if (buildID == NULL || vers == NULL) {
        free(buildID);
        free(vers);
        if (error) {
            *error = [NSError errorWithDomain:TSSFirmwareVersionErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey : @"Cannot read version or buildID in buildmanifest."}];
        }
        return NO;
    }
    self.buildID = [NSString stringWithCString:buildID encoding:NSASCIIStringEncoding];
    self.version = [NSString stringWithCString:vers encoding:NSASCIIStringEncoding];
    free(buildID);
    free(vers);
    return YES;
}
- (BOOL) isOTAFirmware {
    return self.OTAIdentifier != nil;
}
//- (NSString *) buildManifestName {
//    return self.isOTAFirmware ? self.OTAIdentifier : [NSString stringWithFormat:@"%@_%@", self.version, self.buildID];
//}
- (NSString *) description
{
    return [NSString stringWithFormat:@"TSSFirmwareVersion: %p; version: %@; buildID: %@; OTAId: %@", self, self.version, self.buildID, self.OTAIdentifier];
}
@end
