//
//  main.c
//  img4tool
//
//  Created by tihmstar on 15.06.16.
//  Copyright © 2016 tihmstar. All rights reserved.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "img4.h"
#include "img4tool.h"
#include "TSSHelper.h"

#include <CommonCrypto/CommonDigest.h>
#define SHA1(d, n, md) CC_SHA1(d, n, md)
#define SHA384(d, n, md) CC_SHA384(d, n, md)
#define swapchar(a,b) ((a) ^= (b),(b) ^= (a),(a) ^= (b)) //swaps a and b, unless they are the same variable

TSSDataBuffer readDataBufferFromFile(const char *filePath) {
    TSSDataBuffer buffer = {0};
    FILE *f = fopen(filePath, "r");
    if (f) {
        fseek(f, 0, SEEK_END);
        buffer.length = ftell(f);
        fseek(f, 0, SEEK_SET);
        buffer.buffer = malloc(buffer.length);
        if (!buffer.buffer || buffer.length * sizeof(char) != fread(buffer.buffer, sizeof(char), buffer.length, f)) {
            free(buffer.buffer);
            buffer.buffer = NULL;
            buffer.length = 0;
        }
        fclose(f);
    }
    return buffer;
}
int verifyGenerator(const char *im4mBuffer, const char *generator, TSSCustomUserData *userData) {
    unsigned char genHash[48]; //SHA384 digest length
    size_t bnchSize = 0;
    const char *bnch = getBNCHFromIM4M(im4mBuffer, &bnchSize, userData);
    if (bnch && strlen(generator) == 18 && generator[0] == '0' && generator[1] == 'x') {
        unsigned char zz[9] = {0};
        parseHex(generator+2, NULL, (char*)zz, NULL);
        swapchar(zz[0], zz[7]);
        swapchar(zz[1], zz[6]);
        swapchar(zz[2], zz[5]);
        swapchar(zz[3], zz[4]);

        if (bnchSize == 32)
            SHA384(zz, 8, genHash);
        else
            SHA1(zz, 8, genHash);
        char bnchStr[bnchSize * 2 + 1];
        char *write = bnchStr;
        for (int i = 0; i < bnchSize; i++, write += 2) {
            sprintf(write, "%02x",*(unsigned char *)(bnch + i));
        }
        if (memcmp(genHash, bnch, bnchSize) == 0) {
            log_console("[OK] verified generator \"%s\" to be valid for BNCH \"%s\"\n", generator, bnchStr);
        }
        else {
            error("[Error] generator does not generate same nonce as inside IM4M, but instead it'll generate \"%s\".", bnchStr);
            writeErrorMsg("Generator does not generate same nonce as inside IM4M.");
            userData->errorCode = -15;
        }
    } else if (bnch) {
        error("[Error] generator \"%s\" is invalid\n", generator);
        writeErrorMsg("Generator is invalid.");
        userData->errorCode = -16;
    } else {
        error("[Error] Failed to validate generator.\n");
        writeErrorMsg("Failed to validate generator.");
        userData->errorCode = -17;
    }
    return userData->errorCode != 0;
}
