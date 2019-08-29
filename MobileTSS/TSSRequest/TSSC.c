//
//  TSSC.c
//  TssTool-test
//
//  Created by User on 7/14/18.
//  Copyright © 2018 User. All rights reserved.
//

#include "TSSC.h"
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <CommonCrypto/CommonDigest.h>
#include <time.h>

#include "tss.h"
#include "libfragmentzip.h"
#include "TSSHelper.h"

#define SHA1(d, n, md) CC_SHA1(d, n, md)
#define SHA384(d, n, md) CC_SHA384(d, n, md)
#define swapchar(a,b) ((a) ^= (b),(b) ^= (a),(a) ^= (b)) //swaps a and b, unless they are the same variable

int downloadPartialzip(const char *url, const char *file, TSSDataBuffer *dst, TSSCustomUserData *userData) {
    log_console("[LFZP] downloading %s from %s\n",file,url);
//    int error = 0;
    fragmentzip_t *info = fragmentzip_open(url, userData);
    if (!info) {
        error("[LFZP] failed to open url\n");
        return -1;
    }
    //    int ret = fragmentzip_download_file(info, file, dst, fragmentzip_callback);
    int ret = fragmentzip_download_file(info, file, dst, NULL, userData);

    if (ret) {
        userData->errorCode = ret;
        log_console("[LFZP] Bad return code: %d.\n", ret);
        log_console("[LFZP] failed to download file %s\n", file);
    }
    fragmentzip_close(info);
    return ret;
}

void debug_plist(plist_t plist) {
    uint32_t size = 0;
    char* data = NULL;
    plist_to_xml(plist, &data, &size);
    if (size <= 64*1024)
        printf("%s:printing %i bytes plist:\n%s", __FILE__, size, data);
    else
        printf("%s:supressed printing %i bytes plist...\n", __FILE__, size);
    free(data);
}
void write_plist(plist_t plist, const char *path) {
    uint32_t size = 0;
    char* data = NULL;
    plist_to_xml(plist, &data, &size);
    FILE *f = fopen(path, "w");
    fwrite(data, 1, size, f);
//    printf("%s:supressed printing %i bytes plist...\n", __FILE__, size);
    free(data);
    fclose(f);
}
static void getRandNum(char *dst, size_t size, int base) {
    srand((unsigned int)time(NULL));
    for (int i=0; i<size; i++) {
        int j;
        if (base == 256) dst[i] = rand() % base;
        else dst[i] = ((j = rand() % base) < 10) ? '0' + j : 'a' + j-10;
    }
}

static int tss_populate_devicevals(plist_t tssreq, uint64_t ecid, const char *nonce, size_t nonce_size, const char *sep_nonce, size_t sep_nonce_size, int image4supported) {

    plist_dict_set_item(tssreq, "ApECID", plist_new_uint(ecid));
    if (nonce) {
        plist_dict_set_item(tssreq, "ApNonce", plist_new_data(nonce, nonce_size));//aa aa aa aa bb cc dd ee ff 00 11 22 33 44 55 66 77 88 99 aa
    }

    if (sep_nonce) {//aa aa aa aa bb cc dd ee ff 00 11 22 33 44 55 66 77 88 99 aa
        plist_dict_set_item(tssreq, "ApSepNonce", plist_new_data(sep_nonce, sep_nonce_size));
    }

    plist_dict_set_item(tssreq, "ApProductionMode", plist_new_bool(1));

    if (image4supported) {
        plist_dict_set_item(tssreq, "ApSecurityMode", plist_new_bool(1));
        plist_dict_set_item(tssreq, "ApSupportsImg4", plist_new_bool(1));
    } else {
        plist_dict_set_item(tssreq, "ApSupportsImg4", plist_new_bool(0));
    }

    return 0;
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
static int tss_populate_basebandvals(plist_t tssreq, plist_t tssparameters, DeviceInfo_BridgedCStruct *device, TSSCustomUserData *userData) {

    plist_t parameters = plist_new_dict();
//    static const size_t NONCELEN_BASEBAND = 20;
//    char bbnonce[NONCELEN_BASEBAND+1];
    // MARK: why random chipID ???
    int64_t BbChipID = 0;

//    getRandNum(bbnonce, NONCELEN_BASEBAND, 256);
    srand((unsigned int)time(NULL));
    int n=0; for (int i=1; i<7; i++) BbChipID += (rand() % 10) * pow(10, ++n);

    char bbsnum[device->bbsnumSize];
    getRandNum(bbsnum, device->bbsnumSize, 256);

    /* BasebandNonce not required */
    //    plist_dict_set_item(parameters, "BbNonce", plist_new_data(bbnonce, NONCELEN_BASEBAND));

    plist_dict_set_item(parameters, "BbChipID", plist_new_uint(BbChipID));
    plist_dict_set_item(parameters, "BbGoldCertId", plist_new_uint(device->basebandCertID));
    plist_dict_set_item(parameters, "BbSNUM", plist_new_data(bbsnum, device->bbsnumSize));

    plist_t BasebandFirmware = plist_access_path(tssparameters, 2, "Manifest", "BasebandFirmware");
    if (!BasebandFirmware || plist_get_node_type(BasebandFirmware) != PLIST_DICT) {
        error("ERROR: Unable to get BasebandFirmware node.\n");
        return -1;
    }
    plist_t manifest = plist_new_dict();
    plist_dict_set_item(manifest, "BasebandFirmware", plist_copy(BasebandFirmware));
    plist_dict_set_item(parameters, "Manifest", manifest);
    tss_request_add_baseband_tags(tssreq, parameters, NULL, userData);
    plist_free(parameters);

//    if (< 0) {
//        error("[TSSR] Error: Failed to add baseband tags to TSS request.\n");
//        return -1;
//    }

    return 0;
}
#pragma clang diagnostic pop
static const size_t apNonceLengthPreiPhone7 = 20;
static const size_t apNonceLengthNew = 32;
size_t apNonceLengthForDeviceModel(const char *deviceModel) {
    char deviceModelNumber[5] = {0};
    if (strstr(deviceModel, "iPhone") == deviceModel) {
        strcpy(deviceModelNumber, deviceModel + 6);
        *index(deviceModelNumber, ',') = '\0';
        return atoi(deviceModelNumber) >= 9 ? apNonceLengthNew : apNonceLengthPreiPhone7;
    }
    if (strstr(deviceModel, "iPad") == deviceModel) {
        strcpy(deviceModelNumber, deviceModel + 4);
        *index(deviceModelNumber, ',') = '\0';
        return atoi(deviceModelNumber) >= 7 ? apNonceLengthNew : apNonceLengthPreiPhone7;
    }
    if (strstr(deviceModel, "iPod") == deviceModel) {
        // iPod 7th??!!
        // iPod 6-gen -- iPod7,1
        // iPod 7-gen -- iPod9,1  <- to be confirmed.
        strcpy(deviceModelNumber, deviceModel + 4);
        *index(deviceModelNumber, ',') = '\0';
        return atoi(deviceModelNumber) > 7 ? apNonceLengthNew : apNonceLengthPreiPhone7;
    }
//    if (strstr(deviceModel, "AppleTV") == deviceModel) {
//        strcpy(deviceModelNumber, deviceModel + 7);
//        return atoi(deviceModelNumber) >= 6 ? apNonceLengthNew : apNonceLengthPreiPhone7;
//    }
    return 0;   // unidentified device;
}
size_t requiredSepNonceLengthForModel(const char *deviceModel) {
    return 20;  // Parameter is not used here; Apple might change that.
}
static int tss_populate_random(plist_t tssreq, int is64bit, DeviceInfo_BridgedCStruct *device, TSSCustomUserData *userData) {
    const size_t requiredApNonceLength = apNonceLengthForDeviceModel(device->deviceModel); //valid for all devices up to iPhone7
    if (!requiredApNonceLength) {
        error("Unidentified Device: %s\n",device->deviceModel);
        return -1;
    }
    // verify apnonce length if user-specified.
    if (device->apnonce.buffer && requiredApNonceLength != device->apnonce.length) {
        error("parsed APNoncelen != requiredAPNoncelen (%lu != %zu)\n",device->apnonce.length,requiredApNonceLength);
        return -1;
    }
    if (!device->apnonce.buffer && device->apnonce.length) {
        // generate a random apnonce if requested.
        device->apnonce.buffer = malloc(requiredApNonceLength + 1);
        if (!device->apnonce.buffer) {
            error("Cannot alloc memory for apnonce.\n");
            return -1;
        }
        device->apnonce.length = requiredApNonceLength;
        unsigned char zz[9] = {0};
        if (device->generator[0] != '\0') {
            // generator is provided.
            parseHex(device->generator+2, NULL, (char*)zz, NULL);
            swapchar(zz[0], zz[7]);
            swapchar(zz[1], zz[6]);
            swapchar(zz[2], zz[5]);
            swapchar(zz[3], zz[4]);
        }
        else {
            // get a random generator.
            getRandNum((char *)zz, 8, 256);
            snprintf(device->generator, generatorBufferSize, "0x%02x%02x%02x%02x%02x%02x%02x%02x",zz[7],zz[6],zz[5],zz[4],zz[3],zz[2],zz[1],zz[0]);
        }
        if (requiredApNonceLength == apNonceLengthPreiPhone7) {
            //nonce is derived from generator with SHA1
            SHA1(zz, 8, (unsigned char *)device->apnonce.buffer);
        }
        else if (requiredApNonceLength == apNonceLengthNew) {
            unsigned char genHash[CC_SHA384_DIGEST_LENGTH]; // SHA384 digest length
            SHA384(zz, 8, genHash);
            memcpy(device->apnonce.buffer, genHash, apNonceLengthNew);
        }
        else {
            error("[TSSR] Automatic generator->nonce calculation failed. Unknown device with noncelen=%zu\n",requiredApNonceLength);
            device->apnonce.buffer = NULL;
            return -1;
        }
        device->apnonce.buffer[requiredApNonceLength] = '\0';
    }

    const size_t requiredSepNonceLength = requiredSepNonceLengthForModel(device->deviceModel);
    const TSSBoolean sepnonceRequired = device->sepnonce.length & 1;
    device->sepnonce.length >>= 1;
    if (sepnonceRequired) {
        // sepnonce is required.
        // MARK: SEP nonce is actually never used during a restore but now used for request a ticket from tss.
        if (device->sepnonce.buffer && device->sepnonce.length != requiredSepNonceLength) {
            error("parsed SEPNoncelen != requiredSEPNoncelen (%lu != %zu)",device->sepnonce.length, requiredSepNonceLength);
            return -1;
        }
        if (!device->sepnonce.buffer && device->sepnonce.length) {
            device->sepnonce.buffer = malloc(requiredSepNonceLength + 1);
            device->sepnonce.length = requiredSepNonceLength;
            getRandNum(device->sepnonce.buffer, requiredSepNonceLength, 256);
            device->sepnonce.buffer[requiredSepNonceLength] = '\0';
        }
    }
    return tss_populate_devicevals(tssreq, device->ecid, device->apnonce.buffer, device->apnonce.length, device->sepnonce.buffer, device->sepnonce.length, is64bit);
}
/*
static plist_t getBuildidentityWithBoardconfig(plist_t buildManifest, const char *boardconfig, TSSBoolean isUpdateInstall, TSSCustomUserData *userData) {
    plist_t rt = NULL;
#define reterror(a ... ) {error(a); rt = NULL; goto error;}

    plist_t buildidentities = plist_dict_get_item(buildManifest, "BuildIdentities");
    if (!buildidentities || plist_get_node_type(buildidentities) != PLIST_ARRAY){
        reterror("[TSSR] Error: could not get BuildIdentities\n");
    }
    for (int i=0; i<plist_array_get_size(buildidentities); i++) {
        rt = plist_array_get_item(buildidentities, i);
        if (!rt || plist_get_node_type(rt) != PLIST_DICT){
            reterror("[TSSR] Error: could not get id%d\n",i);
        }
        plist_t infodict = plist_dict_get_item(rt, "Info");
        if (!infodict || plist_get_node_type(infodict) != PLIST_DICT){
            reterror("[TSSR] Error: could not get infodict\n");
        }
        plist_t RestoreBehavior = plist_dict_get_item(infodict, "RestoreBehavior");
        if (!RestoreBehavior || plist_get_node_type(RestoreBehavior) != PLIST_STRING){
            reterror("[TSSR] Error: could not get RestoreBehavior\n");
        }
        char *string = NULL;
        plist_get_string_val(RestoreBehavior, &string);
        //assuming there are only Erase and Update. If it's not Erase it must be Update
        //also converting isUpdateInstall to bool (1 or 0)
        if ((strncmp(string, "Erase", strlen(string)) != 0) == !isUpdateInstall){
            //continue when Erase found but isUpdateInstall is true
            //or Update found and isUpdateInstall is false
            rt = NULL;
            free(string);
            continue;
        }
        free(string);
        plist_t DeviceClass = plist_dict_get_item(infodict, "DeviceClass");
        if (!DeviceClass || plist_get_node_type(DeviceClass) != PLIST_STRING){
            reterror("[TSSR] Error: could not get DeviceClass\n");
        }
        plist_get_string_val(DeviceClass, &string);
        TSSBoolean matches = strcasecmp(string, boardconfig) == 0;
        free(string);
        if (!matches)
            rt = NULL;
        else
            break;
    }

error:
    return rt;
#undef reterror
}
*/
static int tssrequest(plist_t *tssrequest, plist_t buildIdentity, DeviceInfo_BridgedCStruct *device, TSSCustomUserData *userData) {
#define reterror(a...) do {error(a); error = -1; goto error;} while(0)

    int error = 0;
    plist_t tssparameter = NULL;
    plist_t tssreq = NULL;

    plist_t manifestdict = plist_dict_get_item(buildIdentity, "Manifest");
    if (!manifestdict || plist_get_node_type(manifestdict) != PLIST_DICT){
        reterror("[TSSR] Error: could not get manifest\n");
    }

    plist_t sep = plist_dict_get_item(manifestdict, "SEP");
    const int is64Bit = (sep && plist_get_node_type(sep) == PLIST_DICT);
    // internally store one bit to indicate if sepnonce is required.
    // this should not cause an error as length will not be large.
    device->sepnonce.length <<= 1;
    device->sepnonce.length |= is64Bit ? 1 : 0;

    tssparameter = plist_new_dict();
    tssreq = tss_request_new(NULL);

    if (tss_populate_random(tssparameter, is64Bit, device, userData)) {
        reterror("[TSSR] failed to populate tss request\n");
    }
    if (tss_parameters_add_from_manifest(tssparameter, buildIdentity, userData) < 0) {
        reterror("[TSSR] ERROR: Unable to add parameters to TSS request from manifest.\n");
    }
    if (tss_request_add_common_tags(tssreq, tssparameter, NULL, userData) < 0) {
        reterror("[TSSR] ERROR: Unable to add common tags to TSS request\n");
    }
    if (tss_request_add_ap_tags(tssreq, tssparameter, NULL, userData) < 0) {
        reterror("[TSSR] ERROR: Unable to add common tags to TSS request\n");
    }
    if (is64Bit) {
        if (tss_request_add_ap_img4_tags(tssreq, tssparameter, userData) < 0) {
            reterror("[TSSR] ERROR: Unable to add img4 tags to TSS request\n");
        }
    } else {
        if (tss_request_add_ap_img3_tags(tssreq, tssparameter, userData) < 0) {
            reterror("[TSSR] ERROR: Unable to add img3 tags to TSS request\n");
        }
    }

//    char *key = NULL;
//    plist_dict_iter iterator = NULL;
//    plist_t node = NULL;
//    plist_dict_new_iter(manifestdict, &iterator);
//    plist_dict_next_item(manifestdict, iterator, &key, &node);
//    for (; key; plist_dict_next_item(manifestdict, iterator, &key, &node)) {
//        if (strncmp(key, "SE,", 3) == 0 && plist_get_node_type(plist_dict_get_item(plist_dict_get_item(manifestdict, key), "Digest")) == PLIST_DATA) {
//            free(key);
//            tss_request_add_se_tags(<#plist_t request#>, <#plist_t parameters#>, <#plist_t overrides#>, <#TSSCustomUserData *userData#>)
//            break;
//        }
//        free(key);
//    }
//    free(iterator);

    // !!!: baseband ticket cannot be saved since mobiletss cannot get essential baseband info from device.
    info("[TSSR] skip request for Baseband ticket.\n");


//    if (device->basebandCertID && device->bbsnumSize) {
//        // ???: Why adding baseband tags twice works
//        if (tss_populate_basebandvals(tssreq, tssparameter, device, userData) < 0) {
//            reterror("[TSSR] Error: Failed to populate baseband values\n");
//        }
//        tss_request_add_baseband_tags(tssreq, tssparameter, NULL, userData);
//    }
//    else {
//        info("[TSSR] skip request for Baseband ticket.\n");
//    }
    *tssrequest = tssreq;
error:
    plist_free(tssparameter);
    if (error) {
        plist_free(tssreq);
        *tssrequest = NULL;
    }
    return error;
#undef reterror
}
int isBuildIdentitySignedForDevice(const BuildIdentity *buildIdentity, DeviceInfo_BridgedCStruct *device, TSSDataBuffer *__nullable shshDataBuffer, TSSCustomUserData *__nullable userData) {

#define reterror(retcode, msg...) {error(msg); isSigned = retcode; goto error;}
    TSSBoolean isSigned = 0;
    plist_t tssreq = NULL;
    plist_t apticket_Erase = NULL;
    plist_t apticket_Update = NULL;
    plist_t apticket_Erase_NoNonce = NULL;
    plist_t apticket_Update_NoNonce = NULL;
    if (!buildIdentity->eraseInstall && !buildIdentity->updateInstall) {
        reterror(-1, "Neither erase nor update ticket is available. Abort.\n");
    }
    
    if (buildIdentity->eraseInstall && tssrequest(&tssreq, buildIdentity->eraseInstall, device, userData) == 0) {
        info("Requesting apticket for Erase type...(1/%d)\n", buildIdentity->updateInstall ? 4 : 2);
        isSigned = tss_request_send(tssreq, NULL, &apticket_Erase, userData);
        if (isSigned > 0 && shshDataBuffer) {
            // user did not cancel.
            const TSSDataBuffer apnonce = device->apnonce;
            device->apnonce = (TSSDataBuffer) {NULL, 0};
            plist_free(tssreq);
            tssreq = NULL;
            if (tssrequest(&tssreq, buildIdentity->eraseInstall, device, userData) == 0) {
                if (userData && *userData->signal) {
                    device->apnonce = apnonce;
                    goto error;
                }
                info("Requesting apticket for Erase type without nonce...(2/%d)\n", buildIdentity->updateInstall ? 4 : 2);
                tss_request_send(tssreq, NULL, &apticket_Erase_NoNonce, userData);
            }
            if (buildIdentity->updateInstall) {
                plist_free(tssreq);
                tssreq = NULL;
                if (tssrequest(&tssreq, buildIdentity->updateInstall, device, userData) != 0) {
                    device->apnonce = apnonce;
                    warning("Failed to build request for Update type.\n");
                }
                else {
                    if (userData && *userData->signal) {
                        device->apnonce = apnonce;
                        goto error;
                    }
                    info("Requesting apticket for Update type without nonce...(3/4)\n");
                    tss_request_send(tssreq, NULL, &apticket_Update_NoNonce, userData);
                    plist_free(tssreq);
                    tssreq = NULL;
                    device->apnonce = apnonce;
                    if (tssrequest(&tssreq, buildIdentity->eraseInstall, device, userData) == 0) {
                        if (userData && *userData->signal) {
                            goto error;
                        }
                        info("Requesting apticket for Update type...(4/4)\n");
                        tss_request_send(tssreq, NULL, &apticket_Update, userData);
                    }
                }
            }
            else device->apnonce = apnonce;

        }
        else goto error;
    }
    else if (buildIdentity->updateInstall && tssrequest(&tssreq, buildIdentity->updateInstall, device, userData) == 0) {
        info("Requesting apticket for Update type...(1/2)\n");
        isSigned = tss_request_send(tssreq, NULL, &apticket_Update, userData);
        if (isSigned > 0 && shshDataBuffer) {
            const TSSDataBuffer apnonce = device->apnonce;
            device->apnonce = (TSSDataBuffer) {NULL, 0};
            plist_free(tssreq);
            tssreq = NULL;
            if (tssrequest(&tssreq, buildIdentity->updateInstall, device, userData) == 0) {
                if (userData && *userData->signal) {
                    device->apnonce = apnonce;
                    goto error;
                }
                info("Requesting apticket for Update type without nonce...(2/2)\n");
                tss_request_send(tssreq, NULL, &apticket_Update_NoNonce, userData);
            }
            device->apnonce = apnonce;
        }
        else goto error;
    }
    else {
        reterror(-1, "Cannot build TSS requests for either type.\n")
    }
    if (!apticket_Erase) {
        apticket_Erase = apticket_Update;
        apticket_Update = NULL;
    }
    if (*device->generator)
        plist_dict_set_item(apticket_Erase, "generator", plist_new_string(device->generator));
    if (apticket_Update) {
        plist_dict_set_item(apticket_Erase, "updateInstall", apticket_Update);
        apticket_Update = NULL;
    }
    if (apticket_Erase_NoNonce) {
        plist_dict_set_item(apticket_Erase, "noNonce", apticket_Erase_NoNonce);
        apticket_Erase_NoNonce = NULL;
    }
    if (apticket_Update_NoNonce) {
        plist_dict_set_item(apticket_Erase, "updateInstallNoNonce", apticket_Update_NoNonce);
        apticket_Update_NoNonce = NULL;
    }


    uint32_t size = 0;
    char *data = NULL;
    plist_to_xml(apticket_Erase, &data, &size);

    shshDataBuffer->buffer = malloc(size + 1);
    memcpy(shshDataBuffer->buffer, data, size);
    shshDataBuffer->buffer[size] = '\0';
    shshDataBuffer->length = size;
    free(data);

error:
    plist_free(tssreq);
    plist_free(apticket_Erase);
    plist_free(apticket_Update);
    plist_free(apticket_Erase_NoNonce);
    plist_free(apticket_Update_NoNonce);
    return isSigned;
#undef reterror
}
