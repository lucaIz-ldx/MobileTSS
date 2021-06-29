//
//  img4.c
//  img4tool
//
//  Created by tihmstar on 15.06.16.
//  Copyright © 2016 tihmstar. All rights reserved.
//

#include "img4.h"
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <stdint.h>
//#include <compression.h>

//#define lzfse_decode_buffer(src, src_size, dst, dst_size, scratch) \
compression_decode_buffer(src, src_size, dst, dst_size, scratch, COMPRESSION_LZFSE)

#include <openssl/x509.h>
//#include <CommonCrypto/CommonDigest.h>
//#define SHA1(d, n, md) CC_SHA1(d, n, md)
//#define SHA_DIGEST_LENGTH CC_SHA1_DIGEST_LENGTH

#define LEN_XTND  0x80        /* Indefinite or long form */
typedef unsigned char byte;

//#define putStr(s,l) printf("%.*s",(int)l,s)

//TagClass
#define kASN1TagClassUniversal       0
#define kASN1TagClassApplication     1
#define kASN1TagClassContextSpecific 2
#define kASN1TagClassPrivate        3

//primitive
#define kASN1Primitive  0
#define kASN1Contructed 1

//tagNumber
#define kASN1TagEnd_of_Content    0
#define kASN1TagBOOLEAN         1
#define kASN1TagINTEGER         2
#define kASN1TagBIT             3
#define kASN1TagOCTET           4
#define kASN1TagNULL            5
#define kASN1TagOBJECT          6
#define kASN1TagObject          7
#define kASN1TagEXTERNAL        8
#define kASN1TagREAL            9
#define kASN1TagENUMERATED      10 //0x0A
#define kASN1TagEMBEDDED        11 //0x0B
#define kASN1TagUTF8String      12 //0x0C
#define kASN1TagRELATIVE_OID    13 //0x0D
#define kASN1TagReserved        (14 | 15) //(0x0E | 0x0F)
#define kASN1TagSEQUENCE        16 //0x10
#define kASN1TagSET             17 //0x11
#define kASN1TagNumericString    18 //0x12
#define kASN1TagPrintableString    19 //0x13
#define kASN1TagT61String       20 //0x14
#define kASN1TagVideotexString    21 //0x15
#define kASN1TagIA5String       22 //0x16
#define kASN1TagUTCTime         23 //0x17
#define kASN1TagGeneralizedTime    24 //0x18
#define kASN1TagGraphicString    25 //0x19
#define kASN1TagVisibleString    26 //0x1A
#define kASN1TagGeneralString    27 //0x1B
#define kASN1TagUniversalString    28 //0x1C
#define kASN1TagCHARACTER       29 //0x1D
#define kASN1TagBMPString       30 //0x1E
#define kASN1TagPrivate   (char)0xff

typedef struct{
    byte tagNumber : 5;
    byte isConstructed : 1;
    byte tagClass : 2;
}t_asn1Tag;

typedef struct{
    byte len : 7;
    byte isLong : 1;
}t_asn1Length;

typedef struct{
    size_t dataLen;
    size_t sizeBytes;
} t_asn1ElemLen;

typedef struct{
    byte num : 7;
    byte more : 1;
} t_asn1PrivateTag;

typedef struct {
    plist_t rt;
    plist_t identities;
} RT_Identity;


#define safeFree(buf) do {free(buf); buf = NULL;} while (0)
#define assure(a) do{ if ((a) == 0){err=1; goto error;} } while(0)
#define retassure(retcode, a) do{ if ((a) == 0){err=retcode; goto error;} }while(0)
#define asn1Tag(a) ((t_asn1Tag*)a)


static inline plist_t createPlistStringTransferOwnership(char *string) {
    plist_t str = plist_new_string(string);
    free(string);
    return str;
}

t_asn1ElemLen asn1Len(const char buf[4]){
    t_asn1Length *sTmp = (t_asn1Length *)buf;
    size_t outSize = 0;
    int sizeBytes_ = 0;
    
    unsigned char *sbuf = (unsigned char *)buf;
    
    if (!sTmp->isLong) outSize = sTmp->len;
    else{
        sizeBytes_ = sTmp->len;
        for (int i=0; i<sizeBytes_; i++) {
            outSize *= 0x100;
            outSize += sbuf[1+i];
        }
    }
    
    t_asn1ElemLen ret;
    ret.dataLen = outSize;
    ret.sizeBytes = sizeBytes_+1;
    return ret;
}

char *ans1GetString(char *buf, char **outString, size_t *strlen){
    
    t_asn1Tag *tag = (t_asn1Tag *)buf;
    
    if (!(tag->tagNumber | kASN1TagIA5String)) {
//        error("not a string\n");
        return 0;
    }
    
    t_asn1ElemLen len = asn1Len(++buf);
    *strlen = len.dataLen;
    buf+=len.sizeBytes;
    if (outString) *outString = buf;
    
    return buf+*strlen;
}
static size_t asn1GetPrivateTagnum(t_asn1Tag *tag, size_t *sizebytes){
    if (*(unsigned char*)tag != 0xff) {
//        error("not a private TAG 0x%02x\n",*(unsigned int*)tag);
        return 0;
    }
    size_t sb = 1;
    t_asn1ElemLen taglen = asn1Len((char*)++tag);
    taglen.sizeBytes-=1;
    if (taglen.sizeBytes != 4){
        /*
         WARNING: seems like apple's private tag is always 4 bytes long
         i first assumed 0x84 can be parsed as long size with 4 bytes,
         but 0x86 also seems to be 4 bytes size even if one would assume it means 6 bytes size.
         This opens the question what the 4 or 6 nibble means.
         */
        taglen.sizeBytes = 4;
    }
    size_t tagname =0;
    do {
        tagname *=0x100;
        tagname>>=1;
        tagname += ((t_asn1PrivateTag*)tag)->num;
        sb++;
    } while (((t_asn1PrivateTag*)tag++)->more);
    if (sizebytes) *sizebytes = sb;
    return tagname;
}
int asn1ElementAtIndexWithCounter(const char *buf, int index, t_asn1Tag **tagret) {
    int ret = 0;
    
    if (!((t_asn1Tag *)buf)->isConstructed) return 0;
    t_asn1ElemLen len = asn1Len(++buf);
    
    buf +=len.sizeBytes;
    
    // TODO: add length and range checks
    while (len.dataLen) {
        if (ret == index && tagret){
            *tagret = (t_asn1Tag*)buf;
            return ret;
        }
        
        if (*buf == kASN1TagPrivate) {
            size_t sb = 0;
            asn1GetPrivateTagnum((t_asn1Tag*)buf,&sb);
            buf+=sb;
            len.dataLen-=sb;
        }
        else if (*buf == (char)0x9F){
            //buf is element in set and it's value is encoded in the next byte
            t_asn1ElemLen l = asn1Len(++buf);
            if (l.sizeBytes > 1) l.dataLen += 0x80;
            buf += l.sizeBytes;
            len.dataLen -= 1 + l.sizeBytes;
        }
        else {
            buf++;
            len.dataLen--;
        }
        
        t_asn1ElemLen sublen = asn1Len(buf);
        size_t toadd =sublen.dataLen + sublen.sizeBytes;
        len.dataLen -=toadd;
        buf +=toadd;
        ret ++;
    }
    
    return ret;
}

int asn1ElementsInObject(const char *buf){
    return asn1ElementAtIndexWithCounter(buf, -1, NULL);
}

const char *asn1ElementAtIndex(const char *buf, int index) {
    t_asn1Tag *ret = NULL;
    asn1ElementAtIndexWithCounter(buf, index, &ret);
    return (const char *)ret;
}

int getSequenceName(const char *buf,char **name, size_t *nameLen, TSSCustomUserData *__nonnull userData) {
#define reterror(a ...){error(a); err = -1; goto error;}
    int err = 0;
    if (((t_asn1Tag*)buf)->tagNumber != kASN1TagSEQUENCE)
        reterror("not a SEQUENCE\n");
    int elems = asn1ElementsInObject(buf);
    if (!elems)
        reterror("no elements in SEQUENCE\n");
    size_t len = 0;
    ans1GetString((char*)asn1ElementAtIndex(buf,0),name,&len);
    if (nameLen) *nameLen = len;
error:
    return err;
#undef reterror
}

uint64_t ans1GetNumberFromTag(t_asn1Tag *tag){
    if (tag->tagNumber != kASN1TagINTEGER) {
//        error("not an INTEGER\n");
        return 0;
    }
    uint64_t ret = 0;
    t_asn1ElemLen len = asn1Len((char*)++tag);
    unsigned char *data = (unsigned char*)tag+len.sizeBytes;
    while (len.dataLen--) {
        ret *= 0x100;
        ret+= *data++;
    }
    
    return ret;
}

//void printStringWithKey(char*key, t_asn1Tag *string){
//    char *str = 0;
//    size_t strlen;
//    ans1GetString((char*)string,&str,&strlen);
//    printf("%s",key);
//    putStr(str, strlen);
//}

static char *getPrivtag(size_t privTag) {
    char *ptag = (char *)&privTag;
    int len = 0;
    while (*ptag) {
        ptag++;
        len++;
    }
    char *str = malloc(len + 1);
    char *tmp = str;
    while (len--) *tmp++ = *--ptag;
    *tmp = '\0';
    return str;
}

char *getHexString(t_asn1Tag *str){
    if (str->tagNumber != kASN1TagOCTET){
        return NULL;
    }

    t_asn1ElemLen len = asn1Len((char*)str+1);

    unsigned char *string = (unsigned char*)str + len.sizeBytes +1;
    size_t length = len.dataLen * 2 + 1;
    char *hexStr = malloc(length);
    char *tmp = hexStr;
    while (len.dataLen) {
        sprintf(tmp, "%02x",*string++);
        tmp += 2;
        len.dataLen--;
    }
    return hexStr;
}

char *I5AStringFromTag(t_asn1Tag *str){
    if (str->tagNumber != kASN1TagIA5String){
//        error("not an I5A string\n");
        return NULL;
    }
    
    t_asn1ElemLen len = asn1Len((char*)++str);
    char *i5aStr = malloc(len.dataLen + 1);
    strncpy(i5aStr, ((char*)str)+len.sizeBytes, len.dataLen);
    i5aStr[len.dataLen] = '\0';
    return i5aStr;
}

plist_t getKBAGOctetArray(char *octet, TSSCustomUserData *userData){
    if (((t_asn1Tag*)octet)->tagNumber != kASN1TagOCTET) {
        error("not an OCTET\n");
        return NULL;
    }
    plist_t array = plist_new_array();
    t_asn1ElemLen octetlen = asn1Len(++octet);
    octet +=octetlen.sizeBytes;
    //main seq
    int subseqs = asn1ElementsInObject(octet);
    for (int i=0; i<subseqs; i++) {
        char *s = (char*)asn1ElementAtIndex(octet, i);
        int elems = asn1ElementsInObject(s);
        
        if (elems--){
            //integer (currently unknown?)
            t_asn1Tag *num = (t_asn1Tag*)asn1ElementAtIndex(s, 0);
            if (num->tagNumber != kASN1TagINTEGER) warning("skipping unexpected tag\n");
            else{
                char n = *(char*)(num+2);
//                printf("num: %d\n",n);
                plist_array_append_item(array, plist_new_uint(n));
            }
        }
        if (elems--) {
            plist_array_append_item(array, createPlistStringTransferOwnership(getHexString((t_asn1Tag*)asn1ElementAtIndex(s, 1))));
        }
        if (elems--) {
            plist_array_append_item(array, createPlistStringTransferOwnership(getHexString((t_asn1Tag*)asn1ElementAtIndex(s, 2))));
        }
    }
    return array;
}

static uint32_t getNumberFromTag(t_asn1Tag *tag) {
    if (tag->tagNumber != kASN1TagINTEGER) {
        printf("tag not an INTEGER\n");
        return 0;
    }
    t_asn1ElemLen len = asn1Len((char*)++tag);
    uint32_t num = 0;
    while (len.sizeBytes) {
        num *=0x100;
        num += *(unsigned char*)++tag;
        len.sizeBytes--;
    }
    return num;
}
/*
void printIM4P(char *buf, TSSCustomUserData *userData) {
    char *magic;
    size_t l;
    getSequenceName(buf, &magic, &l, userData);
    if (strncmp("IM4P", magic, l)) {
        error("unexpected \"%.*s\", expected \"IM4P\"\n",(int)l,magic);
        return;
    }
    
    int elems = asn1ElementsInObject(buf);
    if (--elems>0) printStringWithKey("type: ",(t_asn1Tag*)asn1ElementAtIndex(buf, 1));
    if (--elems>0) printStringWithKey("desc: ",(t_asn1Tag*)asn1ElementAtIndex(buf, 2));
    if (--elems>0) {
        //data
        t_asn1Tag *data = (t_asn1Tag*)asn1ElementAtIndex(buf, 3);
        if (data->tagNumber != kASN1TagOCTET) warning("skipped an unexpected tag where OCTETSTING was expected\n");
        else printf("size: 0x%08zx\n",asn1Len((char*)data+1).dataLen);
    }
    if (--elems>0) {
        //kbag values
        printf("\nKBAG\n");
        printKBAGOctet((char*)asn1ElementAtIndex(buf, 4), userData);
    }else{
        printf("\nIM4P does not contain KBAG values\n");
    }

}

char* extractPayloadFromIM4P(const char* buf, const char** compname, size_t *len) {
    int elems = asn1ElementsInObject(buf);
    if (elems < 4) {
        error("not enough elements in SEQUENCE: %d", elems);
        return NULL;
    }

    char *dataTag = asn1ElementAtIndex(buf, 3)+1;
    t_asn1ElemLen dlen = asn1Len(dataTag);
    char *data = dataTag+dlen.sizeBytes;

    char *kernel = NULL;
    const char* comp = NULL;

    if (strncmp(data, "complzss", 8) == 0) {
        comp = "lzss";
        kernel = tryLZSS(data, len);
    } else if (strncmp(data, "bvx2", 4) == 0) {
        comp = "lzfse";
#ifndef IMG4TOOL_NOLZFSE
        char *compTag = data + dlen.dataLen;
        char *fakeCompSizeTag = asn1ElementAtIndex(compTag, 0);
        char *uncompSizeTag = asn1ElementAtIndex(compTag, 1);

        size_t fake_src_size = ans1GetNumberFromTag(asn1Tag(fakeCompSizeTag));
        size_t dst_size = ans1GetNumberFromTag(asn1Tag(uncompSizeTag));

        size_t src_size = dlen.dataLen;

        if (fake_src_size != 1) {
            printf("fake_src_size not 1 but 0x%zx!\n", fake_src_size);
        }

        kernel = malloc(dst_size);

        size_t uncomp_size = lzfse_decode_buffer(
                (uint8_t*) kernel, dst_size,
                (uint8_t*) data, src_size,
                NULL);

        if (uncomp_size != dst_size) {
            printf("expected to decompress %zu bytes but only got %zu\n", dst_size, uncomp_size);
            free(kernel);
            kernel = NULL;
        } else {
            *len = dst_size;
        }
#else
        printf("Can't unpack data because img4tool was compiled without lzfse!\n");
#endif
    }

    *compname = comp;
    return kernel;
}
*/
/*
int extractFileFromIM4P(char *buf, const char *dstFilename){
    int elems = asn1ElementsInObject(buf);
    if (elems < 4){
        error("not enough elements in SEQUENCE %d\n",elems);
        return -2;
    }


    char *dataTag = asn1ElementAtIndex(buf, 3)+1;
    t_asn1ElemLen dlen = asn1Len(dataTag);
    char *data = dataTag+dlen.sizeBytes;

    char* kernel = NULL;
    {
        size_t kernel_len = 0;
        const char* compname = NULL;
        kernel = extractPayloadFromIM4P(buf, &compname, &kernel_len);

        if (compname != NULL) {
            printf("Kernelcache detected, uncompressing (%s): %s\n", compname, kernel ? "ok" : "failure");
        }

        if (kernel != NULL) {
            data = kernel;
            dlen.dataLen = kernel_len;
        }
    }

    FILE *f = fopen(dstFilename, "wb");
    if (!f) {
        error("can't open file %s\n",dstFilename);
        return -1;
    }
    fwrite(data, dlen.dataLen, 1, f);
    fclose(f);
    
    if (kernel)
        free(kernel);
    
    return 0;
}
*/
int sequenceHasName(const char *buf, const char *name, TSSCustomUserData *userData) {
    char *magic = NULL;
    size_t l = 0;
    int err = getSequenceName(buf, &magic, &l, userData);
    return !err && magic && strncmp(name, magic, l) == 0;
}

//static char *getElementFromIMG4(const char *buf, const char *element, TSSCustomUserData *userData) {
//    if (!sequenceHasName(buf, "IMG4")) {
////        error("not img4 sequcence\n");
//        return NULL;
//    }
//    
//    int elems = asn1ElementsInObject(buf);
//    for (int i=0; i<elems; i++) {
//        
//        const char *elemen = asn1ElementAtIndex(buf, i);
//        
//        if (asn1Tag(elemen)->tagNumber != kASN1TagSEQUENCE && asn1Tag(elemen)->tagClass == kASN1TagClassContextSpecific) {
//            //assuming we found a "subcontainer"
//            elemen += asn1Len((char*)elemen+1).sizeBytes+1;
//        }
//        
//        if (asn1Tag(elemen)->tagNumber == kASN1TagSEQUENCE && sequenceHasName(elemen, element)) {
//            return (char *)elemen;
//        }
//    }
//    error("element %s not found in IMG4\n", element);
//    return NULL;
//}

//int extractElementFromIMG4(char *buf, char* element, const char *dstFilename){
//#define reterror(a ...) return (error(a),-1)
//    
//    char *elemen = getElementFromIMG4(buf, element);
//    if (!elemen) return -1;
//    FILE *f = fopen(dstFilename, "wb");
//    if (!f) {
//        error("can't open file %s\n",dstFilename);
//        return -1;
//    }
//    
//    t_asn1ElemLen len = asn1Len((char*)elemen+1);
//    size_t flen = len.dataLen + len.sizeBytes +1;
//    fwrite(elemen, flen, 1, f);
//    fclose(f);
//    
//    return 0;
//#undef reterror
//}

int asn1MakeSize(char *sizeBytesDst, size_t size){
    int off = 0;
    if (size >= 0x1000000) {
        // 1+4 bytes length
        sizeBytesDst[off++] = 0x84;
        sizeBytesDst[off++] = (size >> 24) & 0xFF;
        sizeBytesDst[off++] = (size >> 16) & 0xFF;
        sizeBytesDst[off++] = (size >> 8) & 0xFF;
        sizeBytesDst[off++] = size & 0xFF;
    } else if (size >= 0x10000) {
        // 1+3 bytes length
        sizeBytesDst[off++] = 0x83;
        sizeBytesDst[off++] = (size >> 16) & 0xFF;
        sizeBytesDst[off++] = (size >> 8) & 0xFF;
        sizeBytesDst[off++] = size & 0xFF;
    } else if (size >= 0x100) {
        // 1+2 bytes length
        sizeBytesDst[off++] = 0x82;
        sizeBytesDst[off++] = (size >> 8) & 0xFF;
        sizeBytesDst[off++] = (size & 0xFF);
    } else if (size >= 0x80) {
        // 1+1 byte length
        sizeBytesDst[off++] = 0x81;
        sizeBytesDst[off++] = (size & 0xFF);
    } else {
        // 1 byte length
        sizeBytesDst[off++] = size & 0xFF;
    }
    return off;
}

//char *asn1PrepandTag(char *buf, t_asn1Tag tag){
//    t_asn1ElemLen len = asn1Len(buf+1);
//
//    //alloc mem for oldTag+oldSizebytes+oldData  + newTag + newTagSizebytesMax
//    char *ret = malloc(len.sizeBytes + len.dataLen +1 +1+4);
//    ret[0] = *(char*)&tag;
//    int nSizeBytes = asn1MakeSize(ret+1, len.sizeBytes + len.dataLen +1);
//    memcpy(ret + nSizeBytes+1, buf, len.sizeBytes + len.dataLen +1);
//    return ret;
//}

//char *asn1AppendToTag(char *buf, char *toappend){
//    t_asn1ElemLen buflen = asn1Len(buf+1);
//    t_asn1ElemLen apndLen = asn1Len(toappend+1);
//
//    //alloc memory for bufdata + buftag + apndData + apndSizebytes + apndTag + maxSizeBytesForBuf
//    size_t containerLen;
//    char *ret = malloc(1 +(containerLen = buflen.dataLen +apndLen.sizeBytes + apndLen.dataLen +1) +4);
//
//    ret[0] = buf[0];
//    int nSizeBytes = asn1MakeSize(ret+1, containerLen);
//    //copy old data
//    memcpy(ret + nSizeBytes+1, buf+1+buflen.sizeBytes, buflen.dataLen);
//
//
//    memcpy(ret +nSizeBytes+1+ buflen.dataLen, toappend, apndLen.sizeBytes +apndLen.dataLen +1);
//    free(buf);
//
//    return ret;
//}

const char *getValueForTagInSet(const char *set, uint32_t tag){

    if (((t_asn1Tag*)set)->tagNumber != kASN1TagSET) {
//        error("not a SET\n");
        return NULL;
    }
    t_asn1ElemLen setlen = asn1Len(++set);
    
    for (const char *setelems = set+setlen.sizeBytes; setelems<set+setlen.dataLen;) {
        
        if (*(const unsigned char *)setelems == 0xff) {
            //priv tag
            size_t sb;
            size_t ptag = asn1GetPrivateTagnum((t_asn1Tag*)setelems,&sb);
            setelems += sb;
            t_asn1ElemLen len = asn1Len(setelems);
            setelems += len.sizeBytes;
            if (tag == ptag) return setelems;
            setelems +=len.dataLen;
        }else{
            //normal tag
            t_asn1ElemLen len = asn1Len(setelems);
            setelems += len.sizeBytes + 1;
            if (((t_asn1Tag*)setelems)->tagNumber == tag) return setelems;
            setelems += len.dataLen;
        }
    }
    return 0;
}

static plist_dict_t getMANBInfoDict(const char *buf, TSSCustomUserData *userData);

plist_dict_t getIM4MInfoDict(const char *buf, TSSCustomUserData *userData){
    plist_dict_t im4mInfoDict = NULL;
    char *magic = NULL;
    size_t l = 0;
    getSequenceName(buf, &magic, &l, userData);
    if (magic && strncmp("IM4M", magic, l)) {
        error("unexpected \"%.*s\", expected \"IM4M\"\n",(int)l,magic);
        goto error;
    }
    
    int elems = asn1ElementsInObject(buf);
    if (elems < 2) {
        error("expecting at least 2 elements\n");
        goto error;
    }
    im4mInfoDict = plist_new_dict();
    if (--elems>0) {
        //    plist_new_uint(num);
        //    userData->subcontentValues
        plist_dict_set_item(im4mInfoDict, "Version", plist_new_uint(getNumberFromTag((t_asn1Tag*)asn1ElementAtIndex(buf, 1))));
        ;
    }
    if (--elems>0) {
        t_asn1Tag *manbset = (t_asn1Tag*)asn1ElementAtIndex(buf, 2);
        if (manbset->tagNumber != kASN1TagSET) {
            error("expecting SET\n");
            plist_free(im4mInfoDict);
            im4mInfoDict = NULL;
            goto error;
        }
        
        t_asn1Tag *privtag = manbset + asn1Len((char*)manbset+1).sizeBytes+1;
        size_t sb;
        char *tag = getPrivtag(asn1GetPrivateTagnum(privtag++,&sb));
        char *manbseq = (char*)privtag+sb;
        manbseq+= asn1Len(manbseq).sizeBytes+1;
        plist_dict_set_item(im4mInfoDict, tag, getMANBInfoDict(manbseq, userData));
        free(tag);
    }
    
error:
    return im4mInfoDict;
#undef reterror
}

static plist_t asn1GetValue(t_asn1Tag *tag, TSSCustomUserData *userData){
    if (tag->tagNumber == kASN1TagIA5String) {
        return createPlistStringTransferOwnership(I5AStringFromTag(tag));
    }
    if (tag->tagNumber == kASN1TagOCTET) {
        return createPlistStringTransferOwnership(getHexString(tag));
    }
    if (tag->tagNumber == kASN1TagINTEGER) {
        t_asn1ElemLen len = asn1Len((char *)tag+1);
        unsigned char *num = (unsigned char *)tag + 1 + len.sizeBytes;
        uint64_t pnum = 0;
        while (len.dataLen) {
            pnum *= 0x100;
            pnum += *num++;
            len.dataLen--;
        }
        return plist_new_uint(pnum);
    }
    if (tag->tagNumber == kASN1TagBOOLEAN) {
        return plist_new_bool((*(char*)tag+2 == 0) ? 0 : 1);
    }
    error("can't print unknown tag %02x\n",*(unsigned char*)tag);
    return NULL;
}
extern void debug_plist(plist_t plist);
static plist_t removeRedundantFirstNode_ArrayTransferred(plist_array_t array, const char *tag) {
    plist_t tagPlist = plist_new_string(tag);
    if (plist_compare_node_value(tagPlist, plist_array_get_item(array, 0))) {
        plist_free(tagPlist);
        plist_array_remove_item(array, 0);
        if (plist_array_get_size(array) == 1) {
            plist_t item = plist_copy(plist_array_get_item(array, 0));
            plist_free(array);
            return item;
        }
    }
    else plist_free(tagPlist);
    return array;
}

void asn1AddRecKeyValInArray(const char *buf, TSSCustomUserData *userData, plist_array_t valueArray) {
    if (((t_asn1Tag*)buf)->tagNumber == kASN1TagSEQUENCE) {
        int i = asn1ElementsInObject(buf);
        if (i != 2){
            error("expecting 2 elements found but contains %d\n", i);
            return;
        }
        plist_array_append_item(valueArray, createPlistStringTransferOwnership(I5AStringFromTag((t_asn1Tag*)asn1ElementAtIndex(buf, 0))));
        asn1AddRecKeyValInArray(asn1ElementAtIndex(buf, 1), userData, valueArray);
        return;
    }
    if (((t_asn1Tag*)buf)->tagNumber != kASN1TagSET){
        plist_array_append_item(valueArray, asn1GetValue((t_asn1Tag *)buf, userData));
        return;
    }
    plist_dict_t dict = plist_new_dict();
    plist_array_append_item(valueArray, dict);

    //must be a SET
//    printf("------------------------------\n");
    const int total = asn1ElementsInObject(buf);
    for (int i = 0; i < total; i++) {
        char *elem = (char *)asn1ElementAtIndex(buf, i);
        size_t sb;
        char *tag = getPrivtag(asn1GetPrivateTagnum((t_asn1Tag*)elem,&sb));
        elem+=sb;
        elem += asn1Len(elem+1).sizeBytes;
        plist_array_t array = plist_new_array();
        asn1AddRecKeyValInArray(elem, userData, array);
        plist_dict_set_item(dict, tag, removeRedundantFirstNode_ArrayTransferred(array, tag));
        free(tag);
    }
    
}
static plist_dict_t getMANBInfoDict(const char *buf, TSSCustomUserData *userData){
#define reterror(a ...){error(a);goto error;}
    
    char *magic = NULL;
    size_t l = 0;
    getSequenceName(buf, &magic, &l, userData);
    plist_dict_t dict = NULL;
    if (!magic) {
        reterror("no tag found. \n");
    }
    if (strncmp("MANB", magic, l)) reterror("unexpected \"%.*s\", expected \"MANB\"\n",(int)l,magic);
    
    int manbElemsCnt = asn1ElementsInObject(buf);
    if (manbElemsCnt < 2) reterror("not enough elements in MANB\n");
    char *manbSeq = (char*)asn1ElementAtIndex(buf, 1);

    dict = plist_new_dict();
    for (int i=0; i<asn1ElementsInObject(manbSeq); i++) {
        t_asn1Tag *manbElem = (t_asn1Tag*)asn1ElementAtIndex(manbSeq, i);
        char *tag = NULL;
        if (*(char*)manbElem == kASN1TagPrivate) {
            size_t privTag = 0, sb = 0;
            privTag = asn1GetPrivateTagnum(manbElem,&sb);
            tag = getPrivtag(privTag);
            manbElem+=sb;
        }
        else manbElem++;
        
        manbElem += asn1Len((char*)manbElem).sizeBytes;
        plist_array_t array = plist_new_array();
        asn1AddRecKeyValInArray((char*)manbElem, userData, array);
        plist_dict_set_item(dict, tag ? tag : "UNKNOWN TAG", removeRedundantFirstNode_ArrayTransferred(array, tag));
        free(tag);
    }
error:
    return dict;
#undef reterror
}


//char *getSHA1ofSqeuence(char * buf){
//    if (((t_asn1Tag*)buf)->tagNumber != kASN1TagSEQUENCE){
////        error("tag not seuqnece");
//        return 0;
//    }
//    t_asn1ElemLen bLen = asn1Len(buf+1);
//    size_t buflen = 1 + bLen.dataLen + bLen.sizeBytes;
//    char *ret = malloc(SHA_DIGEST_LENGTH);
//    if (ret)
//        SHA1((unsigned char*)buf, (unsigned int)buflen, (unsigned char *)ret);
//
//    return ret;
//}

int hasBuildidentityElementWithHash(plist_t identity, const char *hash, uint64_t hashSize, TSSCustomUserData *userData){
#define reterror(a ...){rt=0;error(a);goto error;}
#define skipelem(e) if (strcmp(key, e) == 0) {/*warning("skipping element=%s\n",key);*/goto skip;} //seems to work as it is, we don't need to see that warning anymore

    int rt = 0;
    plist_dict_iter dictIterator = NULL;
    
    plist_t manifest = plist_dict_get_item(identity, "Manifest");
    if (!manifest)
        reterror("can't find Manifest\n");
    
    plist_t node = NULL;
    char *key = NULL;
    plist_dict_new_iter(manifest, &dictIterator);
    plist_dict_next_item(manifest, dictIterator, &key, &node);
    do {
        skipelem("BasebandFirmware")
        skipelem("ftap")
        skipelem("ftsp")
        skipelem("rfta")
        skipelem("rfts")
        skipelem("SE,Bootloader")
        skipelem("SE,Firmware")
        skipelem("SE,MigrationOS")
        skipelem("SE,OS")
        skipelem("SE,UpdatePayload")
        
        plist_t digest = plist_dict_get_item(node, "Digest");
        if (!digest) {
            goto skip;
        }
        if (plist_get_node_type(digest) != PLIST_DATA)
            reterror("can't find digest for key=%s\n",key);
        
        char *dgstData = NULL;
        uint64_t len = 0;
        plist_get_data_val(digest, &dgstData, &len);
        if (!dgstData)
            reterror("can't get dgstData for key=%s.\n",key);
        
        if (len == hashSize && memcmp(dgstData, hash, (size_t)len) == 0)
            rt = 1;
        
        free(dgstData);
    skip:
        plist_dict_next_item(manifest, dictIterator, &key, &node);
    } while (!rt && node);
error:
    free(dictIterator);
    dictIterator = NULL;
    return rt;
#undef skipelem
#undef reterror
}

plist_t findAnyBuildidentityForFilehash(plist_t identities, const char *hash, uint64_t hashSize, TSSCustomUserData *userData){
#define skipelem(e) if (strcmp(key, e) == 0) {/*warning("skipping element=%s\n",key);*/goto skip;} //seems to work as it is, we don't need to see that warning anymore
#define reterror(a ...){rt=NULL;error(a);goto error;}
    plist_t rt = NULL;
    plist_dict_iter dictIterator = NULL;
    
    for (int i=0; !rt && i<plist_array_get_size(identities); i++) {
        plist_t idi = plist_array_get_item(identities, i);if (i == 1) abort();
        
        plist_t manifest = plist_dict_get_item(idi, "Manifest");
        if (!manifest)
            reterror("can't find Manifest. i=%d\n",i);
        
        plist_t node = NULL;
        char *key = NULL;
        plist_dict_new_iter(manifest, &dictIterator);
        plist_dict_next_item(manifest, dictIterator, &key, &node);
        do {
            skipelem("BasebandFirmware")
            skipelem("ftap")
            skipelem("ftsp")
            skipelem("rfta")
            skipelem("rfts")
            
            plist_t digest = plist_dict_get_item(node, "Digest");
            if (!digest || plist_get_node_type(digest) != PLIST_DATA)
                reterror("can't find digest for key=%s. i=%d\n",key,i);
            
            char *dgstData = NULL;
            uint64_t len = 0;
            plist_get_data_val(digest, &dgstData, &len);
            if (!dgstData)
                reterror("can't get dgstData for key=%s. i=%d\n",key,i);
            
            if (len == hashSize && memcmp(dgstData, hash, (size_t)len) == 0)
                rt = idi;
            
            free(dgstData);
        skip:
            free(key);
            plist_dict_next_item(manifest, dictIterator, &key, &node);
        } while (!rt && node);
        
        free(dictIterator);
        dictIterator = NULL;
    }
    
error:
    free(dictIterator);
    return rt;
#undef reterror
#undef skipelem
}

static int doForDGSTinIM4M(const char *im4m, RT_Identity *state, int (*loop_cb)(const char elemNameStr[4], const char *dgstData, size_t dgstDataLen, RT_Identity *state, TSSCustomUserData *userData), TSSCustomUserData *userData){
    int err = 0;
#define reterror(code, msg ...) do {error(msg);err=code;goto error;}while(0)

    char *im4mset = (char *)asn1ElementAtIndex(im4m, 2);
    if (!im4mset)
        reterror(-2,"can't find im4mset\n");
    const char *manbSeq = getValueForTagInSet(im4mset, *(uint32_t*)"BNAM");
    if (!manbSeq)
        reterror(-3,"can't find manbSeq\n");
    
    char *manbSet = (char*)asn1ElementAtIndex(manbSeq, 1);
    if (!manbSet)
        reterror(-4,"can't find manbSet\n");
    const int total = asn1ElementsInObject(manbSet);
    for (int i = 0; i < total; i++) {
        const char *curr = asn1ElementAtIndex(manbSet, i);
        
        size_t sb = 0;
        if (asn1GetPrivateTagnum((t_asn1Tag *)curr, &sb) == *(uint32_t*)"PNAM")
            continue;
        const char *cSeq = curr + sb;
        cSeq += asn1Len(cSeq).sizeBytes;
        
        const char *elemName = asn1ElementAtIndex(cSeq, 0);
        t_asn1ElemLen elemNameLen = asn1Len(elemName+1);
        const char *elemNameStr = elemName + elemNameLen.sizeBytes+1;
        
        const char *elemSet = asn1ElementAtIndex(cSeq, 1);
        if (!elemSet)
            reterror(-5, "can't find elemSet. i=%d\n",i);
        
        const char *dgstSeq = getValueForTagInSet(elemSet, *(uint32_t*)"TSGD");
        if (!dgstSeq)
            reterror(-6, "can't find dgstSeq. i=%d\n",i);
        
        
        const char *dgst = asn1ElementAtIndex(dgstSeq, 1);
        if (!dgst || asn1Tag(dgst)->tagNumber != kASN1TagOCTET)
            reterror(-7, "can't find DGST. i=%d\n",i);
        
        t_asn1ElemLen lenDGST = asn1Len(dgst + 1);
        const char *dgstData = dgst + lenDGST.sizeBytes + 1;

        if ((err = loop_cb(elemNameStr, dgstData, lenDGST.dataLen, state, userData))) {
            if (err > 0) { //restart loop if err > 0
                i = -1;
                err = 0;
                continue;
            }
            break;
        }
    }
    
error:
    return err;
#undef reterror
}


static int im4m_buildidentity_check_cb(const char elemNameStr[4], const char *dgstData, size_t dgstDataLen, RT_Identity *state, TSSCustomUserData *userData){
#define skipelem(e) if (strncmp(e, elemNameStr,4) == 0) return 0
    skipelem("ftsp");
    skipelem("ftap");
    skipelem("rfta");
    skipelem("rfts");
    
    if (state->rt) {
        if (!hasBuildidentityElementWithHash(state->rt, dgstData, dgstDataLen, userData)){
            //remove identity we are not looking for and start comparing all hashes again
            plist_array_remove_item(state->identities, plist_array_get_item_index(state->rt));
            state->rt = NULL;
            return 1; //trigger loop restart
        }
    }
    else if (!(state->rt = findAnyBuildidentityForFilehash(state->identities, dgstData, dgstDataLen, userData))) {
        error("can't find any identity which matches all hashes inside IM4M\n");
        return -1;
    }

    
#undef skipelem
    return 0;
}
//char *getIM4PFromIMG4(const char *buf, TSSCustomUserData *userData){
//    char *magic = NULL;
//    size_t l;
//    getSequenceName(buf, &magic, &l, userData);
//    if (strncmp("IMG4", magic, l)) {
//        error("unexpected \"%.*s\", expected \"IMG4\"\n",(int)l,magic);
//        return NULL;
//    }
//    if (asn1ElementsInObject(buf) < 2) {
//        error("not enough elements in SEQUENCE");
//        return NULL;
//    }
//    char *ret = (char*)asn1ElementAtIndex(buf, 1);
//    getSequenceName(ret, &magic, &l, userData);
//    if (strncmp("IM4P", magic, 4) == 0) {
//        return ret;
//    }
//    error("unexpected \"%.*s\", expected \"IM4P\"\n",(int)l,magic);
//    return NULL;
//}

plist_t getBuildIdentityForIM4M(const char *buf, const plist_t buildmanifest, TSSCustomUserData *userData) {
#define reterror(a ...){state.rt=NULL;error(a);goto error;}
//#define skipelem(e) if (strncmp(elemNameStr, e, 4) == 0) {/*warning("skipping element=%s\n",e);*/continue;} //seems to work as it is, we don't need to see that warning anymore

    plist_t manifest = plist_copy(buildmanifest);

    RT_Identity state = {0};

    state.identities = plist_dict_get_item(manifest, "BuildIdentities");
    if (!state.identities) {
        writeErrorMsg("Cannot find BuildIdentities in BuildManifest.");
        reterror("can't find BuildIdentities\n");
    }

    doForDGSTinIM4M(buf, &state, &im4m_buildidentity_check_cb, userData);
    
    plist_t finfo = plist_dict_get_item(state.rt, "Info");
    plist_t fdevclass = plist_dict_get_item(finfo, "DeviceClass");
    plist_t fresbeh = plist_dict_get_item(finfo, "RestoreBehavior");
    
    if (!finfo || !fdevclass || !fresbeh) {
        writeErrorMsg("Cannot get required info from BuildIdentities in BuildManifest.");
        reterror("found buildidentiy, but can't read information\n");
    }
    
    plist_t origIdentities = plist_dict_get_item(buildmanifest, "BuildIdentities");
    
    for (int i=0; i<plist_array_get_size(origIdentities); i++) {
        plist_t curr = plist_array_get_item(origIdentities, i);
    
        plist_t cinfo = plist_dict_get_item(curr, "Info");
        plist_t cdevclass = plist_dict_get_item(cinfo, "DeviceClass");
        plist_t cresbeh = plist_dict_get_item(cinfo, "RestoreBehavior");
        
        if (plist_compare_node_value(cresbeh, fresbeh) && plist_compare_node_value(cdevclass, fdevclass)) {
            state.rt = curr;
            goto error;
        }
    }
    //fails if loop ended without jumping to error
    reterror("found indentity, but failed to match it with orig copy\n");
    
error:
    plist_free(manifest);
    return state.rt;
#undef reterror
}

static int verifyIM4MDigestWithHash(const char *dgstData, size_t dgstDataLen, plist_dict_t manifest, TSSCustomUserData *userData) {
    plist_dict_iter iterator = NULL;
    plist_dict_new_iter(manifest, &iterator);

    char *freeKeys[plist_dict_get_size(manifest)];

    const char *skippingKeys[] = {
        "Savage", "Yonkers", "eUICC"
    };

    char *key = NULL;
    plist_t node = NULL;
    int index = 0;
skip:
    plist_dict_next_item(manifest, iterator, &key, &node);
    for (; node; plist_dict_next_item(manifest, iterator, &key, &node)) {
        plist_t digestNode = plist_dict_get_item(node, "Digest");
        if (!digestNode) {
            warning("No digest for key: %s.\n", key);
            freeKeys[index++] = key;
            continue;
        }
        for (int a = 0; a < sizeof(skippingKeys)/sizeof(skippingKeys[0]); a++) {
            if (strncmp(skippingKeys[a], key, strlen(skippingKeys[a])) == 0) {
                warning("SKIP checking digest for key: %s.\n", key);
                freeKeys[index++] = key;
                goto skip;
            }
        }
        char *data = NULL;
        uint64_t length = 0;
        plist_get_data_val(digestNode, &data, &length);
        if (!data) {
            error("Cannot get digest data for key: %s.\n", key);
            writeErrorMsg("Cannot get digest data for key: %s.", key);
            free(key);
            return -1;
        }
        if (length == dgstDataLen && memcmp(dgstData, data, (size_t)dgstDataLen) == 0) {
            info("Found digest for key: %s.\n", key);
            free(data);
            freeKeys[index++] = key;
            free(iterator);
            for (int i = 0; i < index; i++) {
                plist_dict_remove_item(manifest, freeKeys[i]);
                free(freeKeys[i]);
            }
            return 0;
        }
        free(data);
        free(key);
    }
    warning("No matching digest found.\n");
    free(iterator);
    for (int i = 0; i < index; i++) {
        plist_dict_remove_item(manifest, freeKeys[i]);
        free(freeKeys[i]);
    }
    return 1;
}
int verifyIM4MWithIdentity(const char *im4mBuffer, plist_t buildIdentity, TSSCustomUserData *userData) {
    plist_dict_t manifest = plist_dict_get_item(buildIdentity, "Manifest");
    int err = 0;
#define reterror(code, msg ...) do {error(msg); if (userData) { writeErrorMsg(msg); userData->errorCode=code;} goto error;}while(0)
    plist_array_t noMatchingTags = NULL;

    const char *im4mset = asn1ElementAtIndex(im4mBuffer, 2);
    if (!im4mset)
        reterror(-2,"Can't find im4mset\n");
    const char *manbSeq = getValueForTagInSet(im4mset, *(uint32_t*)"BNAM");
    if (!manbSeq)
        reterror(-3,"Can't find manbSeq\n");

    const char *manbSet = asn1ElementAtIndex(manbSeq, 1);
    if (!manbSet)
        reterror(-4,"Can't find manbSet\n");
    const int total = asn1ElementsInObject(manbSet);
    noMatchingTags = plist_new_array();
    for (int i = 0; i < total; i++) {
        const char *curr = asn1ElementAtIndex(manbSet, i);

        size_t sb = 0;
        if (asn1GetPrivateTagnum((t_asn1Tag *)curr, &sb) == *(uint32_t*)"PNAM")
            continue;
        const char *cSeq = curr + sb;
        cSeq += asn1Len(cSeq).sizeBytes;

        const char *elemName = asn1ElementAtIndex(cSeq, 0);
        t_asn1ElemLen elemNameLen = asn1Len(elemName+1);
        char elemNameStr[5];
        memcpy(elemNameStr, elemName + elemNameLen.sizeBytes + 1, 4);
        elemNameStr[4] = '\0';

        const char *elemSet = asn1ElementAtIndex(cSeq, 1);
        if (!elemSet)
            reterror(-5, "Can't find elemSet. i=%d\n",i);

        const char *dgstSeq = getValueForTagInSet(elemSet, *(uint32_t*)"TSGD");
        if (!dgstSeq)
            reterror(-6, "Can't find dgstSeq. i=%d\n",i);

        const char *dgst = asn1ElementAtIndex(dgstSeq, 1);
        if (!dgst || asn1Tag(dgst)->tagNumber != kASN1TagOCTET)
            reterror(-7, "Can't find DGST. i=%d\n",i);

        t_asn1ElemLen lenDGST = asn1Len(dgst + 1);
        const char *dgstData = dgst + lenDGST.sizeBytes + 1;

        err = verifyIM4MDigestWithHash(dgstData, lenDGST.dataLen, manifest, userData);
        if (err < 0) {
            reterror(-8, "An error has occurred when comparing digest for tag: %s\n.", elemNameStr);
        }
        if (err > 0) {
            plist_array_append_item(noMatchingTags, plist_new_string(elemNameStr));
        }
    }

    err = plist_dict_get_size(manifest);
    if (err == 0) {
        info("All digest data have been matched in identity.\n");
    }
    else {
        plist_dict_iter iterator = NULL;
        plist_dict_new_iter(manifest, &iterator);
        char *key = NULL;
        plist_dict_next_item(manifest, iterator, &key, NULL);

        error("Missing digest data for key: \n");
        for (; key; plist_dict_next_item(manifest, iterator, &key, NULL)) {
            log_console("%s\n", key);
            free(key);
        }
        free(iterator);
        reterror(-9, "Digest data in blobs are incomplete.\n");
    }
    const int noMatchingSize = plist_array_get_size(noMatchingTags);
    if (noMatchingSize) {
        warning("No digest data for tags: ");
        for (int a = 0; a < noMatchingSize - 1; a++) {
            char *key = NULL;
            plist_get_string_val(plist_array_get_item(noMatchingTags, a), &key);
            log_console("%s, ", key);
            free(key);
        }
        char *key = NULL;
        plist_get_string_val(plist_array_get_item(noMatchingTags, noMatchingSize - 1), &key);
        log_console("%s.\n", key);
        free(key);

    }
error:
    plist_free(noMatchingTags);
    if (err == 0) {
        log_console("[OK] IM4M is valid for the given BuildIdentity.\n");
    }
    else {
        char *loc = index(userData->errorMessage, '\n');
        if (loc) {
            *loc = '\0';
        }
    }
    return err;
#undef reterror
}
static void printGeneralBuildIdentityInformation(plist_t buildidentity) {
    plist_t info = plist_dict_get_item(buildidentity, "Info");
    plist_dict_iter iter = NULL;
    plist_dict_new_iter(info, &iter);
    
    plist_type t;
    plist_t node = NULL;
    char *key = NULL;
    plist_dict_next_item(info, iter, &key, &node);
    while (node) {
        char *str = NULL;
        switch (t = plist_get_node_type(node)) {
            case PLIST_STRING:
                plist_get_string_val(node, &str);
                printf("%s : %s\n",key,str);
                break;
            case PLIST_BOOLEAN:
                plist_get_bool_val(node, (uint8_t*)&t);
                printf("%s : %s\n",key,((uint8_t)t) ? "YES" : "NO" );
            default:
                break;
        }
        free(str);
        plist_dict_next_item(info, iter, &key, &node);
    }
    free(iter);
}

static int verify_signature(const char *data, const char *sig, const char *certificate, int useSHA384) {
    //return 0 if signature valid, 1 if invalid, <0 if error occured
    int err = 0;
    EVP_MD_CTX *mdctx = NULL;

    t_asn1ElemLen dataSize = asn1Len(data+1);
    t_asn1ElemLen sigSize = asn1Len(sig+1);
    t_asn1ElemLen certSize = asn1Len(certificate+1);

    X509 *cert = d2i_X509(NULL, (const unsigned char**)&certificate, certSize.dataLen + certSize.sizeBytes + 1);
    EVP_PKEY *certpubkey = X509_get_pubkey(cert);
    
    retassure(-1, mdctx = EVP_MD_CTX_create());
    
    retassure(-2, EVP_DigestVerifyInit(mdctx, NULL, (useSHA384) ? EVP_sha384() : EVP_sha1(), NULL, certpubkey) == 1);
    
    retassure(-3, EVP_DigestVerifyUpdate(mdctx, data, dataSize.dataLen + dataSize.sizeBytes +1) == 1);
    
    err = (EVP_DigestVerifyFinal(mdctx, (const unsigned char*)sig+1 + sigSize.sizeBytes, sigSize.dataLen) != 1);
    
error:
    X509_free(cert);
    EVP_PKEY_free(certpubkey);
    if(mdctx) EVP_MD_CTX_destroy(mdctx);
    return err;
}

//int find_dgst_cb(char elemNameStr[4], char *dgstData, size_t dgstDataLen, void *state){
//    return memcmp(dgstData, state, dgstDataLen) == 0 ? -255 : 0; //-255 is not an error in this case, but indicates that we found our hash
//}

int verifyIM4MSignature(const char *buf, TSSCustomUserData *userData){
    {
        const int num = asn1ElementsInObject(buf);
        if (num != 5) {
            error("[Error] object should contain exactly 5 elements but %d found.\n", num);
            writeErrorMsg("object should contain exactly 5 elements but %d found.", num);
            return -1;
        }
    }

    const char *im4m = asn1ElementAtIndex(buf, 2);
    const char *sig = asn1ElementAtIndex(buf, 3);
    const char *certs = asn1ElementAtIndex(buf, 4);

    int elemsInCerts = asn1ElementsInObject(certs);
    // iPhone 7 has 1 cert, while pre-iPhone 7 have 2 certs.
    if (elemsInCerts < 1) {
        error("[Error] object should contain at least one cert but no elements found.\n");
        writeErrorMsg("object should contain at least one cert but no elements found.");
        return -2;
    }

//    char *bootAuthority = asn1ElementAtIndex(certs, 0); //does not exist on iPhone7
    const char *tssAuthority = asn1ElementAtIndex(certs, elemsInCerts - 1); //is always last item
    // use SHA384 if elems is 2 otherwise use SHA1
    const int v = verify_signature(im4m, sig, tssAuthority, elemsInCerts < 2);
    if (v == 0) {
        log_console("[OK] IM4M signature is verified by TssAuthority.\n");
    }
    return v;
}

const char *getBNCHFromIM4M(const char* im4m, size_t *nonceSize, TSSCustomUserData *userData) {
    const char *ret = NULL;
    const char *mainSet = NULL;
    const char *manbSet = NULL;
    const char *manpSet = NULL;
    const char *nonceOctet = NULL;
    const char *bnch = NULL;
    size_t bnchSize = 0;
    const char *manb = NULL;
    const char *manp = NULL;
    const char *certs = NULL;

    if (asn1ElementsInObject(im4m) != 5) {
        error("unexpected number of Elements (%d) in IM4M sequence\n", asn1ElementsInObject(im4m));
        writeErrorMsg("unexpected number of Elements (%d) in IM4M sequence.", asn1ElementsInObject(im4m));
        goto error;
    }
    mainSet = asn1ElementAtIndex(im4m, 2);
    certs = asn1ElementAtIndex(im4m, 4);
    
    manb = getValueForTagInSet(mainSet, *(uint32_t*)"BNAM"); //MANB priv Tag
    int total = asn1ElementsInObject(manb);
    if (total < 2){
        error("Unexpected number of elements in MANB sequence: %d.\n", total);
        writeErrorMsg("Unexpected number of elements in MANB sequence: %d.", total);
        goto error;
    }
    manbSet = asn1ElementAtIndex(manb, 1);
    
    manp = getValueForTagInSet(manbSet, *(uint32_t *)"PNAM"); //MANP priv Tag
    total = asn1ElementsInObject(manp);
    if (total < 2){
        error("Unexpected number of elements in MANP sequence: %d.\n", total);
        writeErrorMsg("Unexpected number of elements in MANP sequence: %d.", total);
        goto error;
    }
    manpSet = asn1ElementAtIndex(manp, 1);
    
    bnch = getValueForTagInSet(manpSet, *(uint32_t *)"HCNB"); //BNCH priv Tag
    total = asn1ElementsInObject(bnch);

    if (total < 2){
        error("Unexpected number of elements in BNCH sequence: %d.\n", total);
        writeErrorMsg("Unexpected number of elements in BNCH sequence: %d.", total);
        goto error;
    }
    nonceOctet = asn1ElementAtIndex(bnch, 1);
    nonceOctet++;
    
    ret = nonceOctet + asn1Len(nonceOctet).sizeBytes;
    bnchSize = asn1Len(nonceOctet).dataLen;
    // iPhone 7 and above use 32 byte nonce
    if (bnchSize != (asn1ElementsInObject(certs) == 1 ? 32 : 20)) {
        error("Incorrect BNCH size: %zu.\n", bnchSize);
        writeErrorMsg("Incorrect BNCH size: %zu.", bnchSize);
        ret = NULL;
        goto error;
    }
    if (nonceSize)
        *nonceSize = bnchSize;
    
error:
    return ret;
}

int verifyIMG4(const char *buf, plist_t buildmanifest, TSSCustomUserData *userData) {
    //return 0 on valid file, positive value on invalid file, negative value when errors occured
    int err = 0;
#define reterror(code,a ...){error(a);err=code;goto error;}
    char *im4pSHA = NULL;
//    if (sequenceHasName(buf, "IMG4")){
//        //verify IMG4
//        char *im4p = getIM4PFromIMG4(buf, userData);
//        im4pSHA = getSHA1ofSqeuence(im4p);
//
//        if (!im4p) goto error;
//
//        buf = getElementFromIMG4(buf, "IM4M", userData);
//    }

//    if (!sequenceHasName(buf, "IM4M"))
//        reterror(-1,"unable to find IM4M tag");
//
//    if (im4pSHA){
//        if (doForDGSTinIM4M(buf, im4pSHA, find_dgst_cb, userData) == -255)
//            printf("[OK] IM4P is valid for the attached IM4M\n");
//        else
//            reterror(1,"IM4P can't be verified by IM4M\n");
//    }

//    if ((err = verifyIM4MSignature(buf, userData))){
//        reterror((err < 0) ? err : 2, "Signature verification of IM4M failed with error=%d\n",err);
//    }else
//        printf("[OK] IM4M signature is verified by TssAuthority\n");
//
    // TODO: verify certificate chain
    
    if (buildmanifest) {
        plist_t identity = getBuildIdentityForIM4M(buf, buildmanifest, userData);
        if (identity){
            printf("[OK] IM4M is valid for the given BuildManifest for the following restore:\n\n");
            printGeneralBuildIdentityInformation(identity);
            
        }else{
            reterror(3,"IM4M is not valid for any restore within the Buildmanifest\n");
        }
    }else{
        warning("No BuildManifest specified, can't verify restore type of APTicket\n");
    }
    

error:
    safeFree(im4pSHA);
    return err;
#undef reterror
}
