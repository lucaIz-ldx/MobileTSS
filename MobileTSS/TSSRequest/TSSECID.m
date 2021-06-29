//
//  TSSECID.m
//  MobileTSS
//
//  Created by User on 8/14/20.
//

#import "TSSECID.h"
#import "TSSHelper.h"
#import "NSString+ASCIIString.h"

static NSErrorDomain const TSSECIDErrorDomain = @"TSSECIDErrorDomain";

@interface TSSECID ()
@property (nonatomic) int64_t numericECID;

@end

@implementation TSSECID
static TSSECID *localStoredECID;
+ (TSSECID *)randomECID {
    char randomNumbers[17];
    for (int a = 0; a < sizeof(randomNumbers)/sizeof(char) - 1; a++) {
        randomNumbers[a] = '0' + arc4random_uniform(10);
    }
    randomNumbers[sizeof(randomNumbers)/sizeof(char) - 1] = '\0';
    TSSECID *obj = [[TSSECID alloc] initWithNumeric:atoll(randomNumbers)];
    return obj;
}
+ (TSSECID *) localECID {
    if (localStoredECID) {
        return localStoredECID;
    }
    NSString *ecid = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECID"];
    if ([ecid integerValue] <= 0) {
        return nil;
    }
    const int64_t parsedECID = parseECID(ecid.asciiString);
    if (!parsedECID) {
        TSSECID.localECID = nil;
    }
    else localStoredECID = [[TSSECID alloc] initWithNumeric:parsedECID];
    return localStoredECID;
}
+ (void)setLocalECID:(TSSECID *)localECID {
    if (localECID == nil) {
        localStoredECID = nil;
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"ECID"];
        return;
    }
    localStoredECID = localECID;
    [[NSUserDefaults standardUserDefaults] setObject:localECID.ecidString forKey:@"ECID"];
}
- (instancetype)init
{
    return [self initWithNumeric:0];
}
- (instancetype) initWithNumeric: (int64_t) num {
    self = [super init];
    self.numericECID = num;
    return self;
}
- (instancetype) initWithString:(NSString *)string {
    int64_t ret = parseECID(string.asciiString);
    if (ret == 0) {
        return nil;
    }
    return [self initWithNumeric:ret];
}
- (NSString *)ecidString {
    return [NSString stringWithFormat:@"%lld", self.numericECID];
}
@end
