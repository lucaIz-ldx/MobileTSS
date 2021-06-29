//
//  img4.h
//  img4tool
//
//  Created by tihmstar on 15.06.16.
//  Copyright © 2016 tihmstar. All rights reserved.
//

#ifndef img4_h
#define img4_h

#include <stdio.h>
#include <plist/plist.h>
#include "TSSBoolean.h"
#include "TSSIO_iOS.h"

typedef plist_t plist_dict_t;
typedef plist_t plist_array_t;
#ifdef __cplusplus
extern "C" {
#endif

//t_asn1ElemLen asn1Len(const char buf[4]);
//char *ans1GetString(char *buf, char **outString, size_t *strlen);
//int asn1ElementsInObject(const char *buf);
//char *asn1ElementAtIndex(const char *buf, int index);


//char *getValueForTagInSet(char *set, uint32_t tag);


//img4
void printIM4P(char *buf, TSSCustomUserData *userData);
void printIM4R(char *buf, TSSCustomUserData *userData);
plist_dict_t getIM4MInfoDict(const char *buf, TSSCustomUserData *userData);

int sequenceHasName(const char *buf, const char *name, TSSCustomUserData *userData);
int getSequenceName(const char *buf,char**name, size_t *nameLen, TSSCustomUserData *userData);
//size_t asn1GetPrivateTagnum(t_asn1Tag *tag, size_t *sizebytes);
int extractFileFromIM4P(char *buf, const char *dstFilename);
void printElemsInIMG4(const char *buf);

//char *getElementFromIMG4(char *buf, char* element);

const char *getBNCHFromIM4M(const char* im4m, size_t *nonceSize, TSSCustomUserData *userData);
//char *getIM4MFromIMG4(char *buf);

// 0 ok.
int verifyIM4MWithIdentity(const char *im4mBuffer, plist_t buildIdentity, TSSCustomUserData *userData);
int verifyIM4MSignature(const char *buf, TSSCustomUserData *userData);
int verifyIMG4(const char *buf, plist_t buildmanifest, TSSCustomUserData *userData);
plist_t getBuildIdentityForIM4M(const char *buf, const plist_t buildmanifest, TSSCustomUserData *userData);


#ifdef __cplusplus
}
#endif
    
#endif /* img4_h */
