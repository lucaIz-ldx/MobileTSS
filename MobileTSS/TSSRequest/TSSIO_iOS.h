//
//  TSSIO_iOS.h
//  TssTool
//
//  Created by User on 7/11/18.
//  Copyright © 2018 User. All rights reserved.
//

#ifndef TSSIO_iOS_h
#define TSSIO_iOS_h
#include <stdio.h>
#ifdef DEBUG
#define CONSOLE(a...) printf(a)
#else
#define CONSOLE(a...)
#endif

#define info(a ...) do { \
        snprintf(userData->buffer + sprintf(userData->buffer, "[INFO] "), sizeof(userData->buffer)/sizeof(char) - 7, a);\
        if (userData->callback) {\
            userData->callback(userData->userData, userData->buffer);\
        }\
    CONSOLE("[INFO] " a);\
} while (0)
#define log_console(a ...) do { \
        snprintf(userData->buffer, sizeof(userData->buffer)/sizeof(char), a);\
        if (userData->callback) {\
            userData->callback(userData->userData, userData->buffer);\
        }\
    CONSOLE(a);\
} while (0)
#define warning(a ...) do {\
        snprintf(userData->buffer + sprintf(userData->buffer, "[WARNING] "), sizeof(userData->buffer)/sizeof(char), a);\
        if (userData->callback) {\
            userData->callback(userData->userData, userData->buffer);\
        }\
    CONSOLE("[WARNING] " a);\
} while (0)
#define error(a ...) do {\
        snprintf(userData->buffer + sprintf(userData->buffer, "[ERROR] "), sizeof(userData->buffer)/sizeof(char), a);\
        if (userData->callback) {\
            userData->callback(userData->userData, userData->buffer);\
        }\
    CONSOLE("[ERROR] " a);\
} while (0)
#define writeErrorMsg(a ...) do {\
    if (userData->errorMessage[0] == '\0') {\
        snprintf(userData->errorMessage, sizeof(userData->errorMessage)/sizeof(char), a);\
    }\
    CONSOLE("[WRITE ERROR] " a);\
    CONSOLE("\n");\
} while (0)

typedef void (*TSSCustomUserDataCallback) (void *, const char *);
struct TSSCustomUserData {
    TSSCustomUserDataCallback callback;
    void *userData;
    int errorCode;
    char buffer[1024];
    char errorMessage[132];
    const TSSBoolean *signal;
    long timeout;
};
typedef struct TSSCustomUserData TSSCustomUserData;

struct TSSDataBuffer {
    char *buffer;
    size_t length;
};
typedef struct TSSDataBuffer TSSDataBuffer;

#endif /* TSSIO_iOS_h */
