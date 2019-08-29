//
//  SHSHFile.m
//  MobileTSS
//
//  Created by User on 1/1/19.
//

#import "SHSHFile.h"
#import "img4tool.h"
#import "img4.h"
#import "validate.h"

#define SET_ERROR_CODE_LOCALIZED(errCode, msg) do {if (error){\
*error = [NSError errorWithDomain:TSSSHSHErrorDomain code:errCode userInfo:@{NSLocalizedDescriptionKey : msg}];\
}} while (0)
NSString *const TSSSHSHErrorDomain = @"TSSSHSHErrorDomain";

@interface SHSHFile () {
    TSSCustomUserData userData;
    plist_dict_t imageInfo;     // info for main ticket (at root)
    plist_dict_t img3Content;
}
@property (readonly, nonatomic) NSDictionary<NSString *, id> *manifestProperty;
@property (readonly, nonatomic) NSString *errorMessage;
@property (readwrite, nonatomic) SHSHImageType imageType;
@property (readwrite, nonatomic) NSString *generator;
@property (nonatomic) TSSDataBuffer rootTicketContent, updateTicket, noNonceTicket, updateNoNonce;
@property (nonatomic) NSDictionary<NSString *, id> *img4InfoDictionary;
@property (nonatomic) NSMutableString *logStorage;
@end

static void messageFromImg4tool(void *userData, const char *message) {
    SHSHFile *const self = (__bridge SHSHFile *)userData;
    [self.logStorage appendString:[NSString stringWithCString:message encoding:NSASCIIStringEncoding]];
}
@implementation SHSHFile

- (instancetype)init
{
    return [self initWithContentsOfFile:(NSString *_Nonnull)nil error:nil];
}
- (nullable instancetype)initWithContentsOfFile:(nonnull NSString *)path error:(NSError * _Nullable __autoreleasing * _Nullable)error { 
    self = [super init];
    if (self) {
        TSSDataBuffer shshFileContent = readDataBufferFromFile(path.UTF8String);
        if (!shshFileContent.buffer || shshFileContent.length == 0) {
            SET_ERROR_CODE_LOCALIZED(-128, @"Failed to open file.");
            return nil;
        }
        plist_dict_t shshPlist = NULL;
        plist_from_memory(shshFileContent.buffer, (uint32_t)shshFileContent.length, &shshPlist);
        if (!shshPlist) {
            free(shshFileContent.buffer);
            SET_ERROR_CODE_LOCALIZED(-127, @"Failed to read plist from file.");
            return nil;
        }
        {
            plist_t stringPlist = plist_dict_get_item(shshPlist, "generator");
            if (PLIST_IS_STRING(stringPlist)) {
                char *generator = NULL;
                plist_get_string_val(stringPlist, &generator);
                self.generator = [NSString stringWithCString:generator encoding:NSASCIIStringEncoding];
                free(generator);
            }
        }
        plist_dict_t mainTicketPlist = plist_dict_get_item(shshPlist, "ApImg4Ticket");
        if (mainTicketPlist) {
            plist_get_data_val(mainTicketPlist, &_rootTicketContent.buffer, (uint64_t *)&_rootTicketContent.length);
            if (!self.rootTicketContent.buffer || self.rootTicketContent.length == 0) {
                free(shshFileContent.buffer);
                plist_free(shshPlist);
                SET_ERROR_CODE_LOCALIZED(-127, @"Failed to read image from file.");
                return nil;
            }
        }
        else if ((mainTicketPlist = plist_dict_get_item(shshPlist, "APTicket"))) {
            img3Content = shshPlist;
            shshPlist = NULL;
            self.imageType = SHSHImageTypeIMG3;
            goto finish;
        }
        if (*(unsigned char *)self.rootTicketContent.buffer != 0x30) {
            SET_ERROR_CODE_LOCALIZED(-126, @"Invalid SHSH file.");
            return nil;
        }
        if (sequenceHasName(self.rootTicketContent.buffer, "IM4M")) {
            self.imageType = SHSHImageTypeIM4M;
            imageInfo = getIM4MInfoDict(self.rootTicketContent.buffer, &userData);
        }
        //        else if (sequenceHasName(self.shshFileContent.buffer, "IMG4")) {
        //            self.imageType = SOSHSHImageTypeIMG4;
        //            printElemsInIMG4(self.shshFileContent.buffer, 1);
        //        }
        //        else if (sequenceHasName(self.shshFileContent.buffer, "IM4P")) {
        //            self.imageType = SOSHSHImageTypeIM4P;
        //            printIM4P(self.shshFileContent.buffer);
        //        }
        //        else if (sequenceHasName(self.shshFileContent.buffer, "IM4R")) {
        //            self.imageType = SOSHSHImageTypeIM4R;
        //            printIM4R(self.shshFileContent.buffer);
        //        }
        else {
            SET_ERROR_CODE_LOCALIZED(-125, @"Unknown image type.");
            return nil;
        }
        memset(&userData, 0, sizeof(userData));
    finish:
        if (userData.errorMessage[0]) {
            SET_ERROR_CODE_LOCALIZED(-124, self.errorMessage);
            free(shshFileContent.buffer);
            plist_free(shshPlist);
            return nil;
        }
        userData.userData = (__bridge void *)self;
        userData.messageCall = &messageFromImg4tool;
        plist_t updateTicket = plist_dict_get_item(shshPlist, "updateInstall");

        if (updateTicket && PLIST_IS_DICT(updateTicket)) {
            plist_t ticketData = plist_dict_get_item(shshPlist, "ApImg4Ticket");
            if (PLIST_IS_DATA(ticketData)) {
                plist_get_data_val(ticketData, &_updateTicket.buffer, (uint64_t *)&_updateTicket.length);
            }
        }
//        if (PLIST_IS_DATA((ticketData = plist_dict_get_item(shshPlist, "noNonce")))) {
//            plist_get_data_val(ticketData, &_noNonceTicket.buffer, (uint64_t *)&_noNonceTicket.length);
//        }
//        if (PLIST_IS_DATA((ticketData = plist_dict_get_item(shshPlist, "updateInstallNoNonce")))) {
//            plist_get_data_val(ticketData, &_updateNoNonce.buffer, (uint64_t *)&_updateNoNonce.length);
//        }
        free(shshFileContent.buffer);
        plist_free(shshPlist);
        self.verifyGenerator = YES;
    }
    return self;
}
- (NSString *) log {
    return [self.logStorage copy];
}
- (NSString *) errorMessage {
    return userData.errorMessage[0] ? [NSString stringWithCString:userData.errorMessage encoding:NSASCIIStringEncoding] : nil;
}
- (NSDictionary<NSString *, id> *) img4InfoDictionary {
    if (!_img4InfoDictionary && imageInfo) {
        char *xml = NULL;
        uint32_t length = 0;
        plist_to_xml(imageInfo, &xml, &length);
        _img4InfoDictionary = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytesNoCopy:xml length:length] options:0 format:nil error:nil];
    }
    return _img4InfoDictionary;
}
- (NSInteger) version {
    return [self.img4InfoDictionary[@"Version"] integerValue];
}
- (NSDictionary<NSString *, NSDictionary<NSString *, id>*> *) manifestBody {
    return self.img4InfoDictionary[@"MANB"];
}
- (NSDictionary *) manifestProperty {
    return self.manifestBody[@"MANP"];
}
- (NSString *) apnonce {
    return self.manifestProperty[@"BNCH"];
}
- (NSString *) ecid {
    return self.manifestProperty[@"ECID"];
}
- (BOOL) isVerificationSupported {
    return self.imageType == SHSHImageTypeIM4M || self.imageType == SHSHImageTypeIMG3/* || self.imageType == SHSHImageTypeIMG4*/;
}
- (BOOL) verifyWithBuildIdentity: (TSSBuildIdentity *) buildIdentity error: (NSError * _Nullable __autoreleasing *) error {
    userData.errorMessage[0] = userData.buffer[0] = '\0';
    userData.errorCode = 0;
    self.logStorage = [NSMutableString string];
    if (!self.verificationSupported) {
        SET_ERROR_CODE_LOCALIZED(-128, @"Verification is not supported on current type.");
        return NO;
    }
    if (self.imageType == SHSHImageTypeIMG3) {
        return [self verifyIMG3WithBuildIdentity:buildIdentity error:error];
    }
    if (self.verifyGenerator) {
        if (self.generator && verifyGenerator(self.rootTicketContent.buffer, [self.generator cStringUsingEncoding:NSASCIIStringEncoding], &userData)) {
            SET_ERROR_CODE_LOCALIZED(userData.errorCode, self.errorMessage);
            return NO;
        }
    }
    if (verifyIM4MSignature(self.rootTicketContent.buffer, &userData)) {
        SET_ERROR_CODE_LOCALIZED(userData.errorCode, self.errorMessage);
        return NO;
    }
    // TODO: Verify multiple blobs (if exists).
    if (buildIdentity.eraseInstall) {
        if (verifyIM4MWithIdentity(self.rootTicketContent.buffer, buildIdentity.eraseInstall, &userData)) {
            SET_ERROR_CODE_LOCALIZED(userData.errorCode, self.errorMessage);
            return NO;
        }
    }
    else {
        // check update ticket
        if (verifyIM4MWithIdentity(self.updateTicket.buffer ? self.updateTicket.buffer : self.rootTicketContent.buffer, buildIdentity.updateInstall, &userData)) {
            SET_ERROR_CODE_LOCALIZED(userData.errorCode, self.errorMessage);
            return NO;
        }
    }
    return YES;
}
- (BOOL) verifyIMG3WithBuildIdentity: (TSSBuildIdentity *) buildIdentity error: (NSError * _Nullable __autoreleasing *) error {
    extern int verifyIMG3WithIdentity(plist_t shshDict, plist_t buildIdentity, TSSCustomUserData *userData);
    if (verifyIMG3WithIdentity(img3Content, buildIdentity.eraseInstall, &userData)) {
        SET_ERROR_CODE_LOCALIZED(-1, self.errorMessage);
        return NO;
    }
    return YES;
}
- (void)dealloc
{
    free(self.rootTicketContent.buffer);
    free(self.updateTicket.buffer);
    free(self.updateNoNonce.buffer);
    free(self.noNonceTicket.buffer);
    plist_free(imageInfo);
    plist_free(img3Content);
}
@end

