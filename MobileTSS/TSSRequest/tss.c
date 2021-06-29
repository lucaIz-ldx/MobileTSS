/*
 * tss.c
 * Functions for communicating with Apple's TSS server
 *
 * Copyright (c) 2010-2013 Martin Szulecki. All Rights Reserved.
 * Copyright (c) 2012 Nikias Bassen. All Rights Reserved.
 * Copyright (c) 2010 Joshua Hill. All Rights Reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <curl/curl.h>
#include <plist/plist.h>

#include "tss.h"
#include "TSSIO_iOS.h"

//#include <sys/stat.h>
//#define __mkdir(path, mode) mkdir(path, mode)
#define FMT_qu "%qu"

//#ifdef HAVE_CONFIG_H
//#include "config.h"
//#endif

#define TSS_CLIENT_VERSION_STRING "libauthinstall-776.100.16"
#define ECID_STRSIZE 0x20
#define GET_RAND(min, max) ((rand() % (max - min)) + min)
#define debug(a...)

#define MAX_PRINT_LEN 64*1024

extern void debug_plist(plist_t plist);
#ifndef NO_GENERATE_GUID
static char *generate_guid(void)
{
    char *guid = (char *) malloc(sizeof(char) * 37);
    const char *chars = "ABCDEF0123456789";
    srand((unsigned int)time(NULL));
    int i = 0;

    for (i = 0; i < 36; i++) {
        if (i == 8 || i == 13 || i == 18 || i == 23) {
            guid[i] = '-';
            continue;
        } else {
            guid[i] = chars[GET_RAND(0, 16)];
        }
    }
    guid[36] = '\0';
    return guid;
}
#endif
static uint8_t _plist_dict_get_bool(plist_t dict, const char *key)
{
    uint8_t bval = 0;
    uint64_t uintval = 0;
    char *strval = NULL;
    uint64_t strsz = 0;
    plist_t node = plist_dict_get_item(dict, key);
    if (!node) {
        return 0;
    }
    switch (plist_get_node_type(node)) {
        case PLIST_BOOLEAN:
            plist_get_bool_val(node, &bval);
            break;
        case PLIST_UINT:
            plist_get_uint_val(node, &uintval);
            bval = (uint8_t)uintval;
            break;
        case PLIST_STRING:
            plist_get_string_val(node, &strval);
            if (strval) {
                if (strcmp(strval, "true") == 0) {
                    bval = 1;
                } else if (strcmp(strval, "false") == 0) {
                    bval = 0;
                }
                free(strval);
            }
            break;
        case PLIST_DATA:
            plist_get_data_val(node, &strval, &strsz);
            if (strval) {
                if (strsz == 1) {
                    bval = strval[0];
                } else {
                    printf("%s: ERROR: invalid size %llu for data to boolean conversion\n", __func__, strsz);
                }
                free(strval);
            }
            break;
        default:
            break;
    }
    return bval;
}
static int progress_callback(void *clientp, curl_off_t dltotal, curl_off_t dlnow, curl_off_t ultotal, curl_off_t ulnow) {
    return *((TSSCustomUserData *)clientp)->signal;
}
char *ecid_to_string(uint64_t ecid) {
    if (ecid == 0) {
        return NULL;
    }
    char *ecid_string = calloc(1, ECID_STRSIZE * sizeof(char));
    snprintf(ecid_string, ECID_STRSIZE, FMT_qu, (long long unsigned int)ecid);
    return ecid_string;
}

plist_t tss_request_new(plist_t overrides) {

    plist_t request = plist_new_dict();

    plist_dict_set_item(request, "@Locality", plist_new_string("en_US"));
    plist_dict_set_item(request, "@HostPlatformInfo", plist_new_string("mac"));

    plist_dict_set_item(request, "@VersionInfo", plist_new_string(TSS_CLIENT_VERSION_STRING));
    char* guid = generate_guid();
    if (guid) {
        plist_dict_set_item(request, "@UUID", plist_new_string(guid));
        free(guid);
    }

    /* apply overrides */
    if (overrides) {
        plist_dict_merge(&request, overrides);
    }

    return request;
}

int tss_parameters_add_from_manifest(plist_t parameters, plist_t build_identity, TSSCustomUserData *userData)
{
    plist_t node = NULL;
    char* string = NULL;

    /* UniqueBuildID */
    node = plist_dict_get_item(build_identity, "UniqueBuildID");
    if (!node || plist_get_node_type(node) != PLIST_DATA) {
        error("ERROR: Unable to find UniqueBuildID node\n");
        return -1;
    }

    plist_dict_set_item(parameters, "UniqueBuildID", plist_copy(node));
    node = NULL;

    /* ApChipID */
    int chip_id = 0;
    node = plist_dict_get_item(build_identity, "ApChipID");
    if (!node || plist_get_node_type(node) != PLIST_STRING) {
        error("ERROR: Unable to find ApChipID node\n");
        return -1;
    }
    plist_get_string_val(node, &string);
    sscanf(string, "%x", &chip_id);
    plist_dict_set_item(parameters, "ApChipID", plist_new_uint(chip_id));
    free(string);
    string = NULL;
    node = NULL;

    /* ApBoardID */
    int board_id = 0;
    node = plist_dict_get_item(build_identity, "ApBoardID");
    if (!node || plist_get_node_type(node) != PLIST_STRING) {
        error("ERROR: Unable to find ApBoardID node\n");
        return -1;
    }
    plist_get_string_val(node, &string);
    sscanf(string, "%x", &board_id);
    plist_dict_set_item(parameters, "ApBoardID", plist_new_uint(board_id));
    free(string);
    string = NULL;
    node = NULL;

    /* ApSecurityDomain */
    int security_domain = 0;
    node = plist_dict_get_item(build_identity, "ApSecurityDomain");
    if (!node || plist_get_node_type(node) != PLIST_STRING) {
        error("ERROR: Unable to find ApSecurityDomain node\n");
        return -1;
    }
    plist_get_string_val(node, &string);
    sscanf(string, "%x", &security_domain);
    plist_dict_set_item(parameters, "ApSecurityDomain", plist_new_uint(security_domain));
    free(string);
    string = NULL;
    node = NULL;

    /* BbChipID */
    int bb_chip_id = 0;
    char* bb_chip_id_string = NULL;
    node = plist_dict_get_item(build_identity, "BbChipID");
    if (node && plist_get_node_type(node) == PLIST_STRING) {
        plist_get_string_val(node, &bb_chip_id_string);
        sscanf(bb_chip_id_string, "%x", &bb_chip_id);
        plist_dict_set_item(parameters, "BbChipID", plist_new_uint(bb_chip_id));
        free(bb_chip_id_string);
        bb_chip_id_string = NULL;
    }
    else {
        debug("NOTE: Unable to find BbChipID node\n");
    }
    node = NULL;

    /* BbProvisioningManifestKeyHash */
    node = plist_dict_get_item(build_identity, "BbProvisioningManifestKeyHash");
    if (node && plist_get_node_type(node) == PLIST_DATA) {
        plist_dict_set_item(parameters, "BbProvisioningManifestKeyHash", plist_copy(node));
    } else {
        debug("NOTE: Unable to find BbProvisioningManifestKeyHash node\n");
    }
    node = NULL;

    /* BbActivationManifestKeyHash - Used by Qualcomm MDM6610 */
    node = plist_dict_get_item(build_identity, "BbActivationManifestKeyHash");
    if (node && plist_get_node_type(node) == PLIST_DATA) {
        plist_dict_set_item(parameters, "BbActivationManifestKeyHash", plist_copy(node));
    } else {
        debug("NOTE: Unable to find BbActivationManifestKeyHash node\n");
    }
    node = NULL;

    node = plist_dict_get_item(build_identity, "BbCalibrationManifestKeyHash");
    if (node && plist_get_node_type(node) == PLIST_DATA) {
        plist_dict_set_item(parameters, "BbCalibrationManifestKeyHash", plist_copy(node));
    } else {
        debug("NOTE: Unable to find BbCalibrationManifestKeyHash node\n");
    }
    node = NULL;

    /* BbFactoryActivationManifestKeyHash */
    node = plist_dict_get_item(build_identity, "BbFactoryActivationManifestKeyHash");
    if (node && plist_get_node_type(node) == PLIST_DATA) {
        plist_dict_set_item(parameters, "BbFactoryActivationManifestKeyHash", plist_copy(node));
    } else {
        debug("NOTE: Unable to find BbFactoryActivationManifestKeyHash node\n");
    }
    node = NULL;

    /* BbFDRSecurityKeyHash */
    node = plist_dict_get_item(build_identity, "BbFDRSecurityKeyHash");
    if (node && plist_get_node_type(node) == PLIST_DATA) {
        plist_dict_set_item(parameters, "BbFDRSecurityKeyHash", plist_copy(node));
    } else {
        debug("NOTE: Unable to find BbFDRSecurityKeyHash node\n");
    }
    node = NULL;

    /* BbSkeyId - Used by XMM 6180/GSM */
    node = plist_dict_get_item(build_identity, "BbSkeyId");
    if (node && plist_get_node_type(node) == PLIST_DATA) {
        plist_dict_set_item(parameters, "BbSkeyId", plist_copy(node));
    }
    else {
        debug("NOTE: Unable to find BbSkeyId node\n");
    }
    node = NULL;

    /* SE,ChipID - Used for SE firmware request */
    node = plist_dict_get_item(build_identity, "SE,ChipID");
    if (node) {
        if (plist_get_node_type(node) == PLIST_STRING) {
            char *strval = NULL;
            int intval = 0;
            plist_get_string_val(node, &strval);
            sscanf(strval, "%x", &intval);
            plist_dict_set_item(parameters, "SE,ChipID", plist_new_uint(intval));
            free(strval);
        } else {
            plist_dict_set_item(parameters, "SE,ChipID", plist_copy(node));
        }
    }
    node = NULL;

    /* Savage,ChipID - Used for Savage firmware request */
    node = plist_dict_get_item(build_identity, "Savage,ChipID");
    if (node) {
        if (plist_get_node_type(node) == PLIST_STRING) {
            char *strval = NULL;
            int intval = 0;
            plist_get_string_val(node, &strval);
            sscanf(strval, "%x", &intval);
            plist_dict_set_item(parameters, "Savage,ChipID", plist_new_uint(intval));
            free(strval);
        } else {
            plist_dict_set_item(parameters, "Savage,ChipID", plist_copy(node));
        }
    }
    node = NULL;

    /* add Savage,PatchEpoch - Used for Savage firmware request */
    node = plist_dict_get_item(build_identity, "Savage,PatchEpoch");
    if (node) {
        if (plist_get_node_type(node) == PLIST_STRING) {
            char *strval = NULL;
            int intval = 0;
            plist_get_string_val(node, &strval);
            sscanf(strval, "%x", &intval);
            plist_dict_set_item(parameters, "Savage,PatchEpoch", plist_new_uint(intval));
            free(strval);
        } else {
            plist_dict_set_item(parameters, "Savage,PatchEpoch", plist_copy(node));
        }
    }
    node = NULL;

    /* Yonkers,BoardID - Used for Yonkers firmware request */
    node = plist_dict_get_item(build_identity, "Yonkers,BoardID");
    if (node) {
        if (plist_get_node_type(node) == PLIST_STRING) {
            char *strval = NULL;
            int intval = 0;
            plist_get_string_val(node, &strval);
            sscanf(strval, "%x", &intval);
            plist_dict_set_item(parameters, "Yonkers,BoardID", plist_new_uint(intval));
            free(strval);
        } else {
            plist_dict_set_item(parameters, "Yonkers,BoardID", plist_copy(node));
        }
    }
    node = NULL;

    /* Yonkers,ChipID - Used for Yonkers firmware request */
    node = plist_dict_get_item(build_identity, "Yonkers,ChipID");
    if (node) {
        if (plist_get_node_type(node) == PLIST_STRING) {
            char *strval = NULL;
            int intval = 0;
            plist_get_string_val(node, &strval);
            sscanf(strval, "%x", &intval);
            plist_dict_set_item(parameters, "Yonkers,ChipID", plist_new_uint(intval));
            free(strval);
        } else {
            plist_dict_set_item(parameters, "Yonkers,ChipID", plist_copy(node));
        }
    }
    node = NULL;

    /* add Yonkers,PatchEpoch - Used for Yonkers firmware request */
    node = plist_dict_get_item(build_identity, "Yonkers,PatchEpoch");
    if (node) {
        if (plist_get_node_type(node) == PLIST_STRING) {
            char *strval = NULL;
            int intval = 0;
            plist_get_string_val(node, &strval);
            sscanf(strval, "%x", &intval);
            plist_dict_set_item(parameters, "Yonkers,PatchEpoch", plist_new_uint(intval));
            free(strval);
        } else {
            plist_dict_set_item(parameters, "Yonkers,PatchEpoch", plist_copy(node));
        }
    }
    node = NULL;

    /* add Rap,BoardID */
    node = plist_dict_get_item(build_identity, "Rap,BoardID");
    if (node) {
        plist_dict_set_item(parameters, "Rap,BoardID", plist_copy(node));
    }
    node = NULL;

    /* add Rap,ChipID */
    node = plist_dict_get_item(build_identity, "Rap,ChipID");
    if (node) {
        plist_dict_set_item(parameters, "Rap,ChipID", plist_copy(node));
    }
    node = NULL;

    /* add Rap,SecurityDomain */
    node = plist_dict_get_item(build_identity, "Rap,SecurityDomain");
    if (node) {
        plist_dict_set_item(parameters, "Rap,SecurityDomain", plist_copy(node));
    }
    node = NULL;

    /* add eUICC,ChipID */
    node = plist_dict_get_item(build_identity, "eUICC,ChipID");
    if (node) {
        plist_dict_set_item(parameters, "eUICC,ChipID", plist_copy(node));
    }
    node = NULL;

    node = plist_dict_get_item(build_identity, "PearlCertificationRootPub");
    if (node) {
        plist_dict_set_item(parameters, "PearlCertificationRootPub", plist_copy(node));
    }
    node = NULL;

    /* add build identity manifest dictionary */
    node = plist_dict_get_item(build_identity, "Manifest");
    if (!node || plist_get_node_type(node) != PLIST_DICT) {
        error("ERROR: Unable to find Manifest node\n");
        return -1;
    }
    plist_dict_set_item(parameters, "Manifest", plist_copy(node));

    return 0;
}

int tss_request_add_ap_img4_tags(plist_t request, plist_t parameters, TSSCustomUserData *userData) {
    plist_t node = NULL;

    if (!parameters) {
        error("ERROR: Missing required AP parameters\n");
        return -1;
    }

    /* ApNonce */
    node = plist_dict_get_item(parameters, "ApNonce");
    // no nonce blobs.
    if (node) {
        if (plist_get_node_type(node) != PLIST_DATA) {
            error("ERROR: Unable to find required ApNonce in parameters\n");
            return -1;
        }
        plist_dict_set_item(request, "ApNonce", plist_copy(node));
    }else
        plist_dict_set_item(request, "ApNonce", plist_new_data(NULL, 0));
    node = NULL;

    plist_dict_set_item(request, "@ApImg4Ticket", plist_new_bool(1));

    /* ApSecurityMode */
    node = plist_dict_get_item(request, "ApSecurityMode");
    if (!node) {
        /* copy from parameters if available */
        node = plist_dict_get_item(parameters, "ApSecurityMode");
        if (!node || plist_get_node_type(node) != PLIST_BOOLEAN) {
            error("ERROR: Unable to find required ApSecurityMode in parameters\n");
            return -1;
        }
        plist_dict_set_item(request, "ApSecurityMode", plist_copy(node));
        node = NULL;
    }

    node = plist_dict_get_item(request, "ApProductionMode");
    if (!node) {
        /* ApProductionMode */
        node = plist_dict_get_item(parameters, "ApProductionMode");
        if (!node || plist_get_node_type(node) != PLIST_BOOLEAN) {
            error("ERROR: Unable to find required ApProductionMode in parameters\n");
            return -1;
        }
        plist_dict_set_item(request, "ApProductionMode", plist_copy(node));
        node = NULL;
    }

    /* ApSepNonce */
    node = plist_dict_get_item(parameters, "ApSepNonce");
    if (!node || plist_get_node_type(node) != PLIST_DATA) {
        error("ERROR: Unable to find required ApSepNonce in parameters\n");
        return -1;
    }

    plist_dict_set_item(request, "SepNonce", plist_copy(node));
    node = NULL;

    /* PearlCertificationRootPub */
    node = plist_dict_get_item(parameters, "PearlCertificationRootPub");
    if (node) {
        plist_dict_set_item(request, "PearlCertificationRootPub", plist_copy(node));
    }

    return 0;
}

int tss_request_add_ap_img3_tags(plist_t request, plist_t parameters, TSSCustomUserData *userData) {
    plist_t node = NULL;

    if (!parameters) {
        error("ERROR: Missing required AP parameters\n");
        return -1;
    }

    /* ApNonce */
    node = plist_dict_get_item(parameters, "ApNonce");
    if (node) {
        if (plist_get_node_type(node) != PLIST_DATA) {
            error("ERROR: Unable to find required ApNonce in parameters\n");
            return -1;
        }
        plist_dict_set_item(request, "ApNonce", plist_copy(node));
        node = NULL;
    }

    /* @APTicket */
    plist_dict_set_item(request, "@APTicket", plist_new_bool(1));

    /* ApBoardID */
    node = plist_dict_get_item(request, "ApBoardID");
    if (!node || plist_get_node_type(node) != PLIST_UINT) {
        error("ERROR: Unable to find required ApBoardID in request\n");
        return -1;
    }
    node = NULL;

    /* ApChipID */
    node = plist_dict_get_item(request, "ApChipID");
    if (!node || plist_get_node_type(node) != PLIST_UINT) {
        error("ERROR: Unable to find required ApChipID in request\n");
        return -1;
    }
    node = NULL;

    /* ApSecurityDomain */
    node = plist_dict_get_item(request, "ApSecurityDomain");
    if (!node || plist_get_node_type(node) != PLIST_UINT) {
        error("ERROR: Unable to find required ApSecurityDomain in request\n");
        return -1;
    }
    node = NULL;

    /* ApProductionMode */
    node = plist_dict_get_item(parameters, "ApProductionMode");
    if (!node || plist_get_node_type(node) != PLIST_BOOLEAN) {
        error("ERROR: Unable to find required ApProductionMode in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "ApProductionMode", plist_copy(node));
    node = NULL;

    return 0;
}

int tss_request_add_common_tags(plist_t request, plist_t parameters, plist_t overrides, TSSCustomUserData *userData) {
    plist_t node = NULL;

    /* ApECID */
    node = plist_dict_get_item(parameters, "ApECID");
    if (!node || plist_get_node_type(node) != PLIST_UINT) {
        error("ERROR: Unable to find required ApECID in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "ApECID", plist_copy(node));

    node = NULL;

    /* UniqueBuildID */
    node = plist_dict_get_item(parameters, "UniqueBuildID");
    if (node) {
        plist_dict_set_item(request, "UniqueBuildID", plist_copy(node));
    }
    node = NULL;

    /* ApChipID */
    node = plist_dict_get_item(parameters, "ApChipID");
    if (node) {
        plist_dict_set_item(request, "ApChipID", plist_copy(node));
    }
    node = NULL;

    /* ApBoardID */
    node = plist_dict_get_item(parameters, "ApBoardID");
    if (node) {
        plist_dict_set_item(request, "ApBoardID", plist_copy(node));
    }
    node = NULL;

    /* ApSecurityDomain */
    node = plist_dict_get_item(parameters, "ApSecurityDomain");
    if (node) {
        plist_dict_set_item(request, "ApSecurityDomain", plist_copy(node));
    }
    node = NULL;

    /* apply overrides */
    if (overrides) {
        plist_dict_merge(&request, overrides);
    }

    return 0;
}

static void tss_entry_apply_restore_request_rules(plist_t tss_entry, plist_t parameters, plist_t rules, TSSCustomUserData *userData)
{
    if (!tss_entry || !rules) {
        return;
    }
    if (plist_get_node_type(tss_entry) != PLIST_DICT) {
        return;
    }
    if (plist_get_node_type(rules) != PLIST_ARRAY) {
        return;
    }

    uint32_t i;
    for (i = 0; i < plist_array_get_size(rules); i++) {
        plist_t rule = plist_array_get_item(rules, i);
        plist_t conditions = plist_dict_get_item(rule, "Conditions");
        plist_dict_iter iter = NULL;
        plist_dict_new_iter(conditions, &iter);
        char* key = NULL;
        plist_t value = NULL;
        plist_t value2 = NULL;
        int conditions_fulfilled = 1;
        while (conditions_fulfilled) {
            plist_dict_next_item(conditions, iter, &key, &value);
            if (key == NULL)
                break;
            if (!strcmp(key, "ApRawProductionMode")) {
                value2 = plist_dict_get_item(parameters, "ApProductionMode");
            } else if (!strcmp(key, "ApCurrentProductionMode")) {
                value2 = plist_dict_get_item(parameters, "ApProductionMode");
            } else if (!strcmp(key, "ApRawSecurityMode")) {
                value2 = plist_dict_get_item(parameters, "ApSecurityMode");
            } else if (!strcmp(key, "ApRequiresImage4")) {
                value2 = plist_dict_get_item(parameters, "ApSupportsImg4");
            } else if (!strcmp(key, "ApDemotionPolicyOverride")) {
                value2 = plist_dict_get_item(parameters, "DemotionPolicy");
            } else if (!strcmp(key, "ApInRomDFU")) {
                value2 = plist_dict_get_item(parameters, "ApInRomDFU");
            } else {
                warning("WARNING: Unhandled condition '%s' while parsing RestoreRequestRules\n", key);
                value2 = NULL;
            }
            if (value2) {
                conditions_fulfilled = plist_compare_node_value(value, value2);
            } else {
                conditions_fulfilled = 0;
            }
            free(key);
        }
        free(iter);
        iter = NULL;

        if (!conditions_fulfilled) {
            continue;
        }

        plist_t actions = plist_dict_get_item(rule, "Actions");
        plist_dict_new_iter(actions, &iter);
        while (1) {
            plist_dict_next_item(actions, iter, &key, &value);
            if (key == NULL)
                break;
            uint8_t bv = 255;
            plist_get_bool_val(value, &bv);
            if (bv != 255) {
                value2 = plist_dict_get_item(tss_entry, key);
                if (value2) {
                    plist_dict_remove_item(tss_entry, key);
                }
                debug("DEBUG: Adding %s=%s to TSS entry\n", key, (bv) ? "true" : "false");
                plist_dict_set_item(tss_entry, key, plist_new_bool(bv));
            }
            free(key);
        }
        free(iter);
    }
}

int tss_request_add_ap_tags(plist_t request, plist_t parameters, plist_t overrides, TSSCustomUserData *userData) {
    /* loop over components from build manifest */
    plist_t manifest_node = plist_dict_get_item(parameters, "Manifest");
    if (!manifest_node || plist_get_node_type(manifest_node) != PLIST_DICT) {
        error("ERROR: Unable to find restore manifest\n");
        return -1;
    }

    /* add components to request */
    char* key = NULL;
    plist_t manifest_entry = NULL;
    plist_dict_iter iter = NULL;
    plist_dict_new_iter(manifest_node, &iter);
    while (1) {
        plist_dict_next_item(manifest_node, iter, &key, &manifest_entry);
        if (key == NULL)
            break;
        if (!manifest_entry || plist_get_node_type(manifest_entry) != PLIST_DICT) {
            error("ERROR: Unable to fetch BuildManifest entry\n");
            return -1;
        }

        /* do not populate BaseBandFirmware, only in basebaseband request */
        if ((strcmp(key, "BasebandFirmware") == 0)) {
            free(key);
            continue;
        }

        /* FIXME: only used with diagnostics firmware */
        if (strcmp(key, "Diags") == 0) {
            free(key);
            continue;
        }

        if (_plist_dict_get_bool(parameters, "_OnlyFWComponents")) {
            plist_t info_dict = plist_dict_get_item(manifest_entry, "Info");
            if (!_plist_dict_get_bool(manifest_entry, "Trusted") && !_plist_dict_get_bool(info_dict, "IsFirmwarePayload") && !_plist_dict_get_bool(info_dict, "IsSecondaryFirmwarePayload") && !_plist_dict_get_bool(info_dict, "IsFUDFirmware")) {
                debug("DEBUG: %s: Skipping '%s' as it is neither firmware nor secondary firmware payload\n", __func__, key);
                continue;
            }
        }

        /* copy this entry */
        plist_t tss_entry = plist_copy(manifest_entry);

        /* remove obsolete Info node */
        plist_dict_remove_item(tss_entry, "Info");

        /* handle RestoreRequestRules */
        plist_t rules = plist_access_path(manifest_entry, 2, "Info", "RestoreRequestRules");
        if (rules) {
            debug("DEBUG: Applying restore request rules for entry %s\n", key);
            tss_entry_apply_restore_request_rules(tss_entry, parameters, rules, userData);
        }

        /* Make sure we have a Digest key for Trusted items even if empty */
        plist_t node = plist_dict_get_item(manifest_entry, "Trusted");
        if (node && plist_get_node_type(node) == PLIST_BOOLEAN) {
            uint8_t trusted;
            plist_get_bool_val(node, &trusted);
            if (trusted && !plist_access_path(manifest_entry, 1, "Digest")) {
                debug("DEBUG: No Digest data, using empty value for entry %s\n", key);
                plist_dict_set_item(tss_entry, "Digest", plist_new_data(NULL, 0));
            }
        }

        /* finally add entry to request */
        plist_dict_set_item(request, key, tss_entry);

        free(key);
    }
    free(iter);

    /* apply overrides */
    if (overrides) {
        plist_dict_merge(&request, overrides);
    }

    return 0;
}

int tss_request_add_baseband_tags(plist_t request, plist_t parameters, plist_t overrides, TSSCustomUserData *userData) {
    plist_t node = NULL;

    /* BbChipID */
    node = plist_dict_get_item(parameters, "BbChipID");
    if (node) {
        plist_dict_set_item(request, "BbChipID", plist_copy(node));
    }
    node = NULL;

    /* BbProvisioningManifestKeyHash */
    node = plist_dict_get_item(parameters, "BbProvisioningManifestKeyHash");
    if (node) {
        plist_dict_set_item(request, "BbProvisioningManifestKeyHash", plist_copy(node));
    }
    node = NULL;

    /* BbActivationManifestKeyHash - Used by Qualcomm MDM6610 */
    node = plist_dict_get_item(parameters, "BbActivationManifestKeyHash");
    if (node) {
        plist_dict_set_item(request, "BbActivationManifestKeyHash", plist_copy(node));
    }
    node = NULL;

    node = plist_dict_get_item(parameters, "BbCalibrationManifestKeyHash");
    if (node) {
        plist_dict_set_item(request, "BbCalibrationManifestKeyHash", plist_copy(node));
    }
    node = NULL;

    /* BbFactoryActivationManifestKeyHash */
    node = plist_dict_get_item(parameters, "BbFactoryActivationManifestKeyHash");
    if (node) {
        plist_dict_set_item(request, "BbFactoryActivationManifestKeyHash", plist_copy(node));
    }
    node = NULL;

    /* BbFDRSecurityKeyHash */
    node = plist_dict_get_item(parameters, "BbFDRSecurityKeyHash");
    if (node) {
        plist_dict_set_item(request, "BbFDRSecurityKeyHash", plist_copy(node));
    }
    node = NULL;

    /* BbSkeyId - Used by XMM 6180/GSM */
    node = plist_dict_get_item(parameters, "BbSkeyId");
    if (node) {
        plist_dict_set_item(request, "BbSkeyId", plist_copy(node));
    }
    node = NULL;

    /* BbNonce */
    node = plist_dict_get_item(parameters, "BbNonce");
    if (node) {
        plist_dict_set_item(request, "BbNonce", plist_copy(node));
    }
    node = NULL;

    /* @BBTicket */
    plist_dict_set_item(request, "@BBTicket", plist_new_bool(1));

    /* BbGoldCertId */
    node = plist_dict_get_item(parameters, "BbGoldCertId");
    if (!node || plist_get_node_type(node) != PLIST_UINT) {
//        error("ERROR: Unable to find required BbGoldCertId in parameters\n");
        return -1;
    }
    node = plist_copy(node);
    uint64_t val;
    plist_get_uint_val(node, &val);
    plist_set_uint_val(node, (int32_t)val);
    plist_dict_set_item(request, "BbGoldCertId", node);
    node = NULL;

    /* BbSNUM */
    node = plist_dict_get_item(parameters, "BbSNUM");
    if (!node || plist_get_node_type(node) != PLIST_DATA) {
//        error("ERROR: Unable to find required BbSNUM in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "BbSNUM", plist_copy(node));
    node = NULL;

    /* BasebandFirmware */
    node = plist_access_path(parameters, 2, "Manifest", "BasebandFirmware");
    if (!node || plist_get_node_type(node) != PLIST_DICT) {
//        error("ERROR: Unable to get BasebandFirmware node\n");
        return -1;
    }
    plist_t bbfwdict = plist_copy(node);
    node = NULL;
    if (plist_dict_get_item(bbfwdict, "Info")) {
        plist_dict_remove_item(bbfwdict, "Info");
    }
    plist_dict_set_item(request, "BasebandFirmware", bbfwdict);

    /* apply overrides */
    if (overrides) {
        plist_dict_merge(&request, overrides);
    }

    return 0;
}

int tss_request_add_se_tags(plist_t request, plist_t parameters, plist_t overrides, TSSCustomUserData *userData)
{
    plist_t node = NULL;

    plist_t manifest_node = plist_dict_get_item(parameters, "Manifest");
    if (!manifest_node || plist_get_node_type(manifest_node) != PLIST_DICT) {
        error("ERROR: %s: Unable to get restore manifest from parameters\n", __func__);
        return -1;
    }

    /* add tags indicating we want to get the SE,Ticket */
    plist_dict_set_item(request, "@BBTicket", plist_new_bool(1));
    plist_dict_set_item(request, "@SE,Ticket", plist_new_bool(1));

    /* add SE,ChipID */
    node = plist_dict_get_item(parameters, "SE,ChipID");
    if (!node || plist_get_node_type(node) != PLIST_UINT) {
        error("ERROR: %s: Unable to find required SE,ChipID in parameters\n", __func__);
        return -1;
    }
    plist_dict_set_item(request, "SE,ChipID", plist_copy(node));
    node = NULL;

    /* add SE,ID */
    node = plist_dict_get_item(parameters, "SE,ID");
    if (!node) {
        error("ERROR: %s: Unable to find required SE,ID in parameters\n", __func__);
        return -1;
    }
    plist_dict_set_item(request, "SE,ID", plist_copy(node));
    node = NULL;

    /* add SE,Nonce */
    node = plist_dict_get_item(parameters, "SE,Nonce");
    if (!node) {
        error("ERROR: %s: Unable to find required SE,Nonce in parameters\n", __func__);
        return -1;
    }
    plist_dict_set_item(request, "SE,Nonce", plist_copy(node));
    node = NULL;

    /* add SE,RootKeyIdentifier */
    node = plist_dict_get_item(parameters, "SE,RootKeyIdentifier");
    if (!node) {
        error("ERROR: %s: Unable to find required SE,RootKeyIdentifier in parameters\n", __func__);
        return -1;
    }
    plist_dict_set_item(request, "SE,RootKeyIdentifier", plist_copy(node));
    node = NULL;

    /* 'IsDev' determines whether we have Production or Development */
    uint8_t is_dev = 0;
    node = plist_dict_get_item(parameters, "SE,IsDev");
    if (node && plist_get_node_type(node) == PLIST_BOOLEAN) {
        plist_get_bool_val(node, &is_dev);
    }

    /* add SE,* components from build manifest to request */
    char* key = NULL;
    plist_t manifest_entry = NULL;
    plist_dict_iter iter = NULL;
    plist_dict_new_iter(manifest_node, &iter);
    while (1) {
        key = NULL;
        plist_dict_next_item(manifest_node, iter, &key, &manifest_entry);
        if (key == NULL)
            break;
        if (!manifest_entry || plist_get_node_type(manifest_entry) != PLIST_DICT) {
            free(key);
            error("ERROR: Unable to fetch BuildManifest entry\n");
            return -1;
        }

        if (strncmp(key, "SE,", 3)) {
            free(key);
            continue;
        }

        /* copy this entry */
        plist_t tss_entry = plist_copy(manifest_entry);

        /* remove Info node */
        plist_dict_remove_item(tss_entry, "Info");

        /* remove Development or Production key/hash node */
        if (is_dev) {
            if (plist_dict_get_item(tss_entry, "ProductionCMAC"))
                plist_dict_remove_item(tss_entry, "ProductionCMAC");
            if (plist_dict_get_item(tss_entry, "ProductionUpdatePayloadHash"))
                plist_dict_remove_item(tss_entry, "ProductionUpdatePayloadHash");
        } else {
            if (plist_dict_get_item(tss_entry, "DevelopmentCMAC"))
                plist_dict_remove_item(tss_entry, "DevelopmentCMAC");
            if (plist_dict_get_item(tss_entry, "DevelopmentUpdatePayloadHash"))
                plist_dict_remove_item(tss_entry, "DevelopmentUpdatePayloadHash");
        }

        /* add entry to request */
        plist_dict_set_item(request, key, tss_entry);

        free(key);
    }
    free(iter);

    /* apply overrides */
    if (overrides) {
        plist_dict_merge(&request, overrides);
    }

    return 0;
}

int tss_request_add_savage_tags(plist_t request, plist_t parameters, plist_t overrides, TSSCustomUserData *userData) 
{
    plist_t node = NULL;

    plist_t manifest_node = plist_dict_get_item(parameters, "Manifest");
    if (!manifest_node || plist_get_node_type(manifest_node) != PLIST_DICT) {
        error("ERROR: Unable to get restore manifest from parameters\n");
        return -1;
    }

    /* add tags indicating we want to get the Savage,Ticket */
    plist_dict_set_item(request, "@BBTicket", plist_new_bool(1));
    plist_dict_set_item(request, "@Savage,Ticket", plist_new_bool(1));

    /* add Savage,UID */
    node = plist_dict_get_item(parameters, "Savage,UID");
    if (!node) {
        error("ERROR: Unable to find required Savage,UID in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,UID", plist_copy(node));
    node = NULL;

    /* add SEP */
    node = plist_access_path(manifest_node, 2, "SEP", "Digest");
    if (!node) {
        error("ERROR: Unable to get SEP digest from manifest\n");
        return -1;
    }
    plist_t dict = plist_new_dict();
    plist_dict_set_item(dict, "Digest", plist_copy(node));
    plist_dict_set_item(request, "SEP", dict);

    /* add Savage,PatchEpoch */
    node = plist_dict_get_item(parameters, "Savage,PatchEpoch");
    if (!node) {
        error("ERROR: Unable to find required Savage,PatchEpoch in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,PatchEpoch", plist_copy(node));
    node = NULL;

    /* add Savage,ChipID */
    node = plist_dict_get_item(parameters, "Savage,ChipID");
    if (!node) {
        error("ERROR: Unable to find required Savage,ChipID in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,ChipID", plist_copy(node));
    node = NULL;

    /* add Savage,AllowOfflineBoot */
    node = plist_dict_get_item(parameters, "Savage,AllowOfflineBoot");
    if (!node) {
        error("ERROR: Unable to find required Savage,AllowOfflineBoot in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,AllowOfflineBoot", plist_copy(node));
    node = NULL;

    /* add Savage,ReadFWKey */
    node = plist_dict_get_item(parameters, "Savage,ReadFWKey");
    if (!node) {
        error("ERROR: Unable to find required Savage,ReadFWKey in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,ReadFWKey", plist_copy(node));
    node = NULL;

    /* add Savage,ProductionMode */
    node = plist_dict_get_item(parameters, "Savage,ProductionMode");
    if (!node) {
        error("ERROR: Unable to find required Savage,ProductionMode in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,ProductionMode", plist_copy(node));
    const char *comp_name = NULL;
    uint8_t isprod = 0;
    plist_get_bool_val(node, &isprod);
    node = NULL;

    /* add Savage,B2-*-Patch */
    if (isprod) {
        comp_name = "Savage,B2-Prod-Patch";
    } else {
        comp_name = "Savage,B2-Dev-Patch";
    }
    node = plist_access_path(manifest_node, 2, comp_name, "Digest");
    if (!node) {
        error("ERROR: Unable to get %s digest from manifest\n", comp_name);
        return -1;
    }
    dict = plist_new_dict();
    plist_dict_set_item(dict, "Digest", plist_copy(node));
    plist_dict_set_item(request, comp_name, dict);

    /* add Savage,Nonce */
    node = plist_dict_get_item(parameters, "Savage,Nonce");
    if (!node) {
        error("ERROR: Unable to find required Savage,Nonce in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,Nonce", plist_copy(node));
    node = NULL;

    /* add Savage,ReadECKey */
    node = plist_dict_get_item(parameters, "Savage,ReadECKey");
    if (!node) {
        error("ERROR: Unable to find required Savage,ReadECKey in parameters\n");
        return -1;
    }
    plist_dict_set_item(request, "Savage,ReadECKey", plist_copy(node));
    node = NULL;

    /* apply overrides */
    if (overrides) {
        plist_dict_merge(&request, overrides);
    }

    return 0;
}

static size_t tss_write_callback(char* data, size_t size, size_t nmemb, TSSDataBuffer *response) {
    size_t total = size * nmemb;
    if (total != 0) {
        response->buffer = realloc(response->buffer, response->length + total + 1);
        memcpy(response->buffer + response->length, data, total);
        response->buffer[response->length + total] = '\0';
        response->length += total;
    }

    return total;
}

static int tss_request_send_raw(const char *request, const char* server_url_string, TSSDataBuffer *tss_response, TSSCustomUserData *userData) {
    int status_code = -1;
    int retry = 0;
    const int max_retries = 15;
    char curl_error_message[CURL_ERROR_SIZE] = {0};
    const char* urls[] = {
        "https://gs.apple.com/TSS/controller?action=2",
        "https://17.111.103.65/TSS/controller?action=2",
        "https://17.111.103.15/TSS/controller?action=2",
        "http://gs.apple.com/TSS/controller?action=2",
        "http://17.111.103.65/TSS/controller?action=2",
        "http://17.111.103.15/TSS/controller?action=2"
    };

    TSSDataBuffer response = {0};

    while (retry++ < max_retries) {
        CURL *handle = curl_easy_init();
        if (handle == NULL) {
            return -1;
        }
        struct curl_slist* header = NULL;
        header = curl_slist_append(header, "Cache-Control: no-cache");
        header = curl_slist_append(header, "Content-type: text/xml; charset=\"utf-8\"");
        header = curl_slist_append(header, "Expect:");

        response.buffer = malloc(1);
        response.buffer[0] = '\0';

        /* disable SSL verification to allow download from untrusted https locations */
        curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, 0);

        curl_easy_setopt(handle, CURLOPT_ERRORBUFFER, curl_error_message);
        curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, &tss_write_callback);
        curl_easy_setopt(handle, CURLOPT_WRITEDATA, &response);
        curl_easy_setopt(handle, CURLOPT_HTTPHEADER, header);
        curl_easy_setopt(handle, CURLOPT_POSTFIELDS, request);
        curl_easy_setopt(handle, CURLOPT_USERAGENT, "InetURL/1.0");
        curl_easy_setopt(handle, CURLOPT_POSTFIELDSIZE, strlen(request));
        curl_easy_setopt(handle, CURLOPT_XFERINFOFUNCTION, progress_callback);
        curl_easy_setopt(handle, CURLOPT_NOPROGRESS, 0);
        curl_easy_setopt(handle, CURLOPT_PROGRESSDATA, userData);
        if (userData->timeout != 0) {
            const long connection_timeout = userData->timeout;
            const long total_transfer_timeout = 3 + userData->timeout;

            curl_easy_setopt(handle, CURLOPT_CONNECTTIMEOUT, connection_timeout);
            curl_easy_setopt(handle, CURLOPT_TIMEOUT, total_transfer_timeout);
        }
        if (server_url_string) {
            curl_easy_setopt(handle, CURLOPT_URL, server_url_string);
        } else {
            int url_index = (retry - 1) % (sizeof(urls)/sizeof(const char *));
            curl_easy_setopt(handle, CURLOPT_URL, urls[url_index]);
            info("[TSSR] Request URL set to %s\n", urls[url_index]);
        }

        info("[TSSR] Sending TSS request attempt %d...\n", retry);

        const CURLcode resultCode = curl_easy_perform(handle);
        curl_slist_free_all(header);
        curl_easy_cleanup(handle);

        if (strstr(response.buffer, "MESSAGE=SUCCESS")) {
            status_code = 0;
            log_console("Success\n");
            break;
        }
        else {
            log_console("Failure\n");
        }
        if (response.length > 0) {
            warning("TSS server returned: %s\n", response.buffer);
        }
        const char *status = strstr(response.buffer, "STATUS=");
        if (status) {
            sscanf(status+7, "%d&%*s", &status_code);
        }
        if (resultCode != CURLE_OK) {
            if (resultCode == CURLE_ABORTED_BY_CALLBACK) {
                // abort by user.
                free(response.buffer);
                writeErrorMsg("Abort by caller.");
                return Abort_By_User;
            }
            error("Bad Request Code: %d. %s\n", resultCode, curl_error_message);
            writeErrorMsg("%s", *curl_error_message == '\0' ? curl_easy_strerror(resultCode) : curl_error_message);
            // no status code in response. retry
            free(response.buffer);
            memset(&response, 0, sizeof(response));
            sleep(1);
            if (resultCode != CURLE_OPERATION_TIMEDOUT) {
                // most likely unrecoverable error.
                return -resultCode;
            }
            info("Retrying to connect...\n");
            continue;
        } else if (status_code == 8) {
            // server error (invalid bb request?)
            break;
        } else if (status_code == 49) {
            // server error (invalid bb data, e.g. BbSNUM?)
            break;
        } else if (status_code == 69 || status_code == 94) {
            // This device isn't eligible for the requested build.
            break;
        } else if (status_code == 100) {
            // server error, most likely the request was malformed
            break;
        } else if (status_code == 126) {
            // An internal error occured, most likely the request was malformed
            break;
        } else if (status_code == 128) {
            // An internal error occured; apnonce is not provided but it is required. (only occurs when device is 5s, 6/+;)
            break;
        } else {
            log_console("ERROR: tss_send_request: Unhandled status code %d\n", status_code);
            writeErrorMsg("Unhandled status code: %d.", status_code);
        }
    }

    if (status_code != 0) {
        if (response.buffer) {
            if (strstr(response.buffer, "MESSAGE=") != NULL) {
                char* message = strstr(response.buffer, "MESSAGE=") + strlen("MESSAGE=");
                log_console("ERROR: TSS request failed (status=%d, message=%s)\n", status_code, message);
            } else {
                log_console("ERROR: TSS request failed: %s (status=%d)\n", curl_error_message, status_code);
            }
            free(response.buffer);
        }
        return 0;
    }
    tss_response->buffer = response.buffer;
    tss_response->length = response.length;
    return 1;
}
//plist_t tss_request_send(plist_t tss_request, const char* server_url_string) {
int tss_request_send(plist_t tss_request, const char* server_url_string, plist_t *tss_response, TSSCustomUserData *userData) {
//    debug_plist(tss_request);
    char* request = NULL;
    uint32_t size = 0;

    plist_to_xml(tss_request, &request, &size);
    TSSDataBuffer response = {0};

    const int responseCode = tss_request_send_raw(request, server_url_string, &response, userData);
    free(request);
    if (response.buffer) {
        char *tss_data = strstr(response.buffer, "<?xml");
        if (tss_data == NULL) {
            error("ERROR: Incorrectly formatted TSS response\n");
            free(response.buffer);
            return -1;
        }
        uint32_t tss_size = 0;
        tss_size = (uint32_t)(response.length - (tss_data - response.buffer));
        plist_from_xml(tss_data, tss_size, tss_response);
        free(response.buffer);
//#ifdef DEBUG
//        debug_plist(tss_response);
//#endif
    }
    return responseCode;
}

static int tss_response_get_data_by_key(plist_t response, const char* name, unsigned char** buffer, unsigned int* length, TSSCustomUserData *userData) {

    plist_t node = plist_dict_get_item(response, name);
    if (!node || plist_get_node_type(node) != PLIST_DATA) {
        debug("DEBUG: %s: No entry '%s' in TSS response\n", __func__, name);
        return -1;
    }

    char *data = NULL;
    uint64_t len = 0;
    plist_get_data_val(node, &data, &len);
    if (data) {
        *length = (unsigned int)len;
        *buffer = (unsigned char*)data;
        return 0;
    } else {
        error("ERROR: Unable to get %s data from TSS response\n", name);
        return -1;
    }
}

int tss_response_get_ap_img4_ticket(plist_t response, unsigned char** ticket, unsigned int* length, TSSCustomUserData *userData) {
    return tss_response_get_data_by_key(response, "ApImg4Ticket", ticket, length, userData);
}

int tss_response_get_ap_ticket(plist_t response, unsigned char** ticket, unsigned int* length, TSSCustomUserData *userData) {
    return tss_response_get_data_by_key(response, "APTicket", ticket, length, userData);
}

int tss_response_get_baseband_ticket(plist_t response, unsigned char** ticket, unsigned int* length, TSSCustomUserData *userData) {
    return tss_response_get_data_by_key(response, "BBTicket", ticket, length, userData);
}

int tss_response_get_path_by_entry(plist_t response, const char* entry, char** path) {
    char* path_string = NULL;
    plist_t path_node = NULL;
    plist_t entry_node = NULL;

    *path = NULL;

    entry_node = plist_dict_get_item(response, entry);
    if (!entry_node || plist_get_node_type(entry_node) != PLIST_DICT) {
        debug("DEBUG: %s: No entry '%s' in TSS response\n", __func__, entry);
        return -1;
    }

    path_node = plist_dict_get_item(entry_node, "Path");
    if (!path_node || plist_get_node_type(path_node) != PLIST_STRING) {
        debug("NOTE: Unable to find %s path in TSS entry\n", entry);
        return -1;
    }
    plist_get_string_val(path_node, &path_string);

    *path = path_string;
    return 0;
}

int tss_response_get_blob_by_path(plist_t tss, const char* path, unsigned char** blob, TSSCustomUserData *userData) {
    uint32_t i = 0;
    uint32_t tss_size = 0;
    uint64_t blob_size = 0;
    char* entry_key = NULL;
    char* blob_data = NULL;
    char* entry_path = NULL;
    plist_t tss_entry = NULL;
    plist_t blob_node = NULL;
    plist_t path_node = NULL;
    plist_dict_iter iter = NULL;

    *blob = NULL;

    plist_dict_new_iter(tss, &iter);
    tss_size = plist_dict_get_size(tss);
    for (i = 0; i < tss_size; i++) {
        plist_dict_next_item(tss, iter, &entry_key, &tss_entry);
        if (entry_key == NULL)
            break;

        if (!tss_entry || plist_get_node_type(tss_entry) != PLIST_DICT) {
            continue;
        }

        path_node = plist_dict_get_item(tss_entry, "Path");
        if (!path_node || plist_get_node_type(path_node) != PLIST_STRING) {
            error("ERROR: Unable to find TSS path node in entry %s\n", entry_key);
            free(iter);
            return -1;
        }

        plist_get_string_val(path_node, &entry_path);
        if (strcmp(path, entry_path) == 0) {
            blob_node = plist_dict_get_item(tss_entry, "Blob");
            if (!blob_node || plist_get_node_type(blob_node) != PLIST_DATA) {
                error("ERROR: Unable to find TSS blob node in entry %s\n", entry_key);
                free(iter);
                return -1;
            }
            plist_get_data_val(blob_node, &blob_data, &blob_size);
            break;
        }

        free(entry_key);
    }
    free(iter);

    if (blob_data == NULL || blob_size <= 0) {
        return -1;
    }

    *blob = (unsigned char*)blob_data;
    return 0;
}

int tss_response_get_blob_by_entry(plist_t response, const char* entry, unsigned char** blob, TSSCustomUserData *userData) {
    uint64_t blob_size = 0;
    char* blob_data = NULL;
    plist_t blob_node = NULL;
    plist_t tss_entry = NULL;

    *blob = NULL;

    tss_entry = plist_dict_get_item(response, entry);
    if (!tss_entry || plist_get_node_type(tss_entry) != PLIST_DICT) {
        debug("DEBUG: %s: No entry '%s' in TSS response\n", __func__, entry);
        return -1;
    }

    blob_node = plist_dict_get_item(tss_entry, "Blob");
    if (!blob_node || plist_get_node_type(blob_node) != PLIST_DATA) {
        error("ERROR: Unable to find blob in %s entry\n", entry);
        return -1;
    }
    plist_get_data_val(blob_node, &blob_data, &blob_size);

    *blob = (unsigned char*)blob_data;
    return 0;
}
