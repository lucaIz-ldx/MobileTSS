//
//  TSSHelper.c
//  TssTool
//
//  Created by User on 7/9/18.
//  Copyright © 2018 User. All rights reserved.
//

#include "TSSHelper.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int64_t parseECID(const char *ecid){
    if (!ecid) {
        return 0;
    }
    const char *ecidBK = ecid;
    int isHex = 0;
    int64_t ret = 0;
    
    //in case hex ecid only contains digits, specify with 0x1235
    if (strncmp(ecid, "0x", 2) == 0){
        isHex = 1;
        ecidBK = ecid+2;
    }
    while (*ecid && !isHex) {
        char c = *(ecid++);
        if (c >= '0' && c<='9') {
            ret *=10;
            ret += c - '0';
        }else{
            isHex = 1;
            ret = 0;
        }
    }
    if (isHex) {
        while (*ecidBK) {
            char c = *(ecidBK++);
            ret *=16;
            if (c >= '0' && c<='9') {
                ret += c - '0';
            }else if (c >= 'a' && c <= 'f'){
                ret += 10 + c - 'a';
            }else if (c >= 'A' && c <= 'F'){
                ret += 10 + c - 'A';
            }else{
                return 0; //ERROR parsing failed
            }
        }
    }
    return ret;
}
char *parseNonce(const char *nonce, size_t *parsedLen){
    char *ret = NULL;
    size_t retSize = 0;
    if (parseHex(nonce, parsedLen, NULL, &retSize))
        return NULL;
    ret = malloc(retSize);
    if (parseHex(nonce, parsedLen, ret, &retSize)) {
        free(ret);
        return NULL;
    }
    return ret;
}
int parseHex(const char *nonce, size_t *parsedLen, char *ret, size_t *retSize) {
    
    size_t nonceLen = strlen(nonce);
    nonceLen = nonceLen/2 + nonceLen%2; //one byte more if len is odd

    if (retSize) *retSize = (nonceLen+1)*sizeof(char);
    if (!ret) return 0;

    memset(ret, 0, nonceLen+1);
    unsigned int nlen = 0;

    int next = strlen(nonce)%2 == 0;
    char tmp = 0;
    while (*nonce) {
        char c = *(nonce++);

        tmp *=16;
        if (c >= '0' && c<='9') {
            tmp += c - '0';
        }else if (c >= 'a' && c <= 'f'){
            tmp += 10 + c - 'a';
        }else if (c >= 'A' && c <= 'F'){
            tmp += 10 + c - 'A';
        }else{
            return -1; //ERROR parsing failed
        }
        if ((next =! next) && nlen < nonceLen) {
            ret[nlen++] = tmp;
            tmp=0;
        }
    }

    if (parsedLen) *parsedLen = nlen;
    return 0;
}
