//
//  TSSIO_iOS.h
//  TssTool
//
//  Created by User on 7/11/18.
//  Copyright © 2018 User. All rights reserved.
//

#ifndef TSSIO_iOS_h
#define TSSIO_iOS_h
#ifdef __cplusplus
#include <cstdio>
#else
#include <stdio.h>
#endif

#ifdef DEBUG
#define CONSOLE(a...) printf(a)
#else
#define CONSOLE(a...)
#endif

#define info(a ...) do { \
    if (userData && userData->messageCall) {\
        snprintf(userData->buffer + sprintf(userData->buffer, "[INFO] "), sizeof(userData->buffer)/sizeof(char), a);\
        userData->messageCall(userData->userData, userData->buffer);\
    }\
    CONSOLE("[INFO] " a);\
} while (0)
#define log_console(a ...) do { \
    if (userData && userData->messageCall) {\
        snprintf(userData->buffer, sizeof(userData->buffer)/sizeof(char), a);\
        userData->messageCall(userData->userData, userData->buffer);\
    }\
    CONSOLE(a);\
} while (0)
#define warning(a ...) do {\
    if (userData && userData->messageCall) {\
        snprintf(userData->buffer + sprintf(userData->buffer, "[WARNING] "), sizeof(userData->buffer)/sizeof(char), a);\
        userData->messageCall(userData->userData, userData->buffer);\
    }\
    CONSOLE("[WARNING] " a);\
} while (0)
#define error(a ...) do {\
    if (userData && userData->messageCall) {\
        snprintf(userData->buffer + sprintf(userData->buffer, "[ERROR] "), sizeof(userData->buffer)/sizeof(char), a);\
        userData->messageCall(userData->userData, userData->buffer);\
    }\
    CONSOLE("[ERROR] " a);\
} while (0)
#define writeErrorMsg(a ...) do {\
    if (userData && userData->errorMessage[0] == '\0') {\
        snprintf(userData->errorMessage, sizeof(userData->errorMessage)/sizeof(char), a);\
    }\
    CONSOLE("[WRITE ERROR] " a);\
    CONSOLE("\n");\
} while (0)

typedef void (*MessagingPrototype) (void *, const char *);
struct TSSCustomUserData {
    MessagingPrototype messageCall;
    void *userData;
    int errorCode;
    char buffer[1024];
    char errorMessage[132];
    const TSSBoolean *signal;
#ifdef __cplusplus
    TSSCustomUserData(const TSSBoolean *sig = nullptr, int err = 0, MessagingPrototype resrv = nullptr) noexcept : signal(sig), errorCode(err), messageCall(resrv) {}
#endif
};
#ifndef __cplusplus
typedef struct TSSCustomUserData TSSCustomUserData;
#endif

struct TSSDataBuffer {
    char *buffer;
    size_t length;
#ifdef __cplusplus
    TSSDataBuffer(char *buf = nullptr, size_t len = 0) noexcept : buffer(buf), length(len) {}
#endif
};
#ifndef __cplusplus
typedef struct TSSDataBuffer TSSDataBuffer;
#endif

#endif /* TSSIO_iOS_h */
