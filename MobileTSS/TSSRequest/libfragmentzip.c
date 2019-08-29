//
//  libfragmentzip.c
//  libfragmentzip
//
//  Created by tihmstar on 24.12.16.
//  Copyright © 2016 tihmstar. All rights reserved.
//

#include "libfragmentzip.h"
#include <curl/curl.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#include <assert.h>

typedef struct {
    uint32_t signature;
    uint16_t version;
    uint16_t flags;
    uint16_t compression;
    uint16_t modtime;
    uint16_t moddate;
    uint32_t crc32;
    uint32_t size_compressed;
    uint32_t size_uncompressed;
    uint16_t len_filename;
    uint16_t len_extra_field;
    char filename[1]; //variable length
    //    char extra_field[]; //variable length
} ATTRIBUTE_PACKED fragentzip_local_file;

typedef struct{
    uint32_t crc32;
    uint32_t size_compressed;
    uint32_t size_uncompressed;
} ATTRIBUTE_PACKED fragmentzip_data_descriptor;

typedef struct{
    uint32_t signature;
    uint16_t disk_cur_number;
    uint16_t disk_cd_start_number;
    uint16_t cd_disk_number;
    uint16_t cd_entries;
    uint32_t cd_size;
    uint32_t cd_start_offset;
    uint16_t comment_len;
} ATTRIBUTE_PACKED fragmentzip_end_of_cd;

typedef struct{
    uint32_t signature;
    uint16_t version;
    uint16_t pkzip_version_needed;
    uint16_t flags;
    uint16_t compression;
    uint16_t modtime;
    uint16_t moddate;
    uint32_t crc32;
    uint32_t size_compressed;
    uint32_t size_uncompressed;
    uint16_t len_filename;
    uint16_t len_extra_field;
    uint16_t len_file_comment;
    uint16_t disk_num;
    uint16_t internal_attribute;
    uint32_t external_attribute;
    uint32_t local_header_offset;
    char filename[1]; //variable length
    //    char extra_field[]; //variable length
    //    char file_comment[]; //variable length
} ATTRIBUTE_PACKED fragmentzip_cd;

struct fragmentzip_info {
    char *url;
    CURL *mcurl;
    uint64_t length;
    fragmentzip_cd *cd;
    fragmentzip_end_of_cd *cd_end;
};

#define CASSERT(predicate, file) _impl_CASSERT_LINE(predicate,__LINE__,file)

#define _impl_PASTE(a,b) a##b
#define _impl_CASSERT_LINE(predicate, line, file) \
typedef char _impl_PASTE(assertion_failed_##file##_,line)[2*!!(predicate)-1];

#define assure(a) do{ if ((a) == 0){err=1; goto error;} }while(0)
#define retassure(retcode, a) do{ if ((a) == 0){err=retcode; goto error;} }while(0)
#define fragmentzip_nextCD(cd) ((fragmentzip_cd *)(cd->filename+cd->len_filename+cd->len_extra_field+cd->len_file_comment))

typedef struct{
    char *buf;
    size_t size_buf;
    size_t size_downloaded;
    fragmentzip_process_callback_t callback;
}t_downloadBuffer;

static size_t downloadFunction(void* data, size_t size, size_t nmemb, t_downloadBuffer* dbuf) {
    size_t dsize = size*nmemb;
    size_t vsize = 0;
    if (dsize <= dbuf->size_buf - dbuf->size_downloaded){
        vsize = dsize;
    }
    else{
        vsize = dbuf->size_buf - dbuf->size_downloaded;
    }
//    if (dsize == 162) {
//        printf("Downloaded: %s\n", (char *)data);
//    }

    memcpy(dbuf->buf+dbuf->size_downloaded, data, vsize);
    dbuf->size_downloaded += vsize;
//    printf("DEBUG: dbuf->size_buf: %zu, dbuf->downloaded_size: %zu, nmemb: %zu, vsize: %zu.\n", dbuf->size_buf, dbuf->size_downloaded, nmemb, vsize);
//    log_console("%.02f...", (((double)dbuf->size_downloaded/dbuf->size_buf)*100));
    if (dbuf->callback){
        dbuf->callback((unsigned int)(((double)dbuf->size_downloaded/dbuf->size_buf)*100));
    }
    return vsize;
}

CASSERT(sizeof(fragmentzip_cd) == 47, fragmentzip_cd_size_is_wrong);
CASSERT(sizeof(fragmentzip_end_of_cd) == 22, fragmentzip_end_of_cd_size_is_wrong);
static CURLcode curlEasyPerformRetry(CURL *handler, int retry, TSSCustomUserData *userData) {
    CURLcode code = 0;
    for (int a = 0; a < retry; a++) {
        code = curl_easy_perform(handler);
        if (code == CURLE_ABORTED_BY_CALLBACK) {
            log_console("[CURL] Abort by User.\n");
            break;
        }
        if (code == CURLE_OK) {
            break;
        }
        log_console("[CURL] Bad code: %d. Error message from CURL: %s.\n", code, curl_easy_strerror(code));
        log_console("[CURL] Retrying to connect in %d second (%d/%d)...\n", a + 1, a + 1, retry);
        sleep(a + 1);
    }
    if (userData && code != CURLE_OK) {
        userData->errorCode = code;
        strncpy(userData->errorMessage, curl_easy_strerror(code), sizeof(userData->errorMessage)/sizeof(char));
    }
    return code;
}
static int progress_callback(void *clientp, curl_off_t dltotal, curl_off_t dlnow, curl_off_t ultotal, curl_off_t ulnow) {
    return *((TSSCustomUserData *)clientp)->signal;
}

static fragmentzip_t *fragmentzip_open_extended(const char *url, CURL *mcurl, TSSCustomUserData *userData) {
    int err = 0;
    fragmentzip_t *info = NULL;
    t_downloadBuffer *dbuf = NULL;
    fragmentzip_end_of_cd *cde = NULL;
    assure(dbuf = calloc(1, sizeof(t_downloadBuffer)));
    assure(info = calloc(1, sizeof(fragmentzip_t)));

    assure(info->url = strdup(url));
    
    assure(info->mcurl = mcurl);
    static const long connection_timeout = 7;  // must reach URL in 7 sec.
    static const long total_transfer_timeout = 15;  // buildmanifest should not take more than 15 sec. to get.

    curl_easy_setopt(info->mcurl, CURLOPT_CONNECTTIMEOUT, connection_timeout);
    curl_easy_setopt(info->mcurl, CURLOPT_TIMEOUT, total_transfer_timeout);
    curl_easy_setopt(info->mcurl, CURLOPT_URL, info->url);
    curl_easy_setopt(info->mcurl, CURLOPT_NOBODY, 1);
    curl_easy_setopt(info->mcurl, CURLOPT_FOLLOWLOCATION, 1L);

    {
        static const char *userAgent[] = {"Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36"};
        curl_easy_setopt(info->mcurl, CURLOPT_USERAGENT, userAgent[arc4random_uniform(sizeof(userAgent)/sizeof(userAgent[0]))]);
    }

    if (userData) {
        curl_easy_setopt(info->mcurl, CURLOPT_XFERINFOFUNCTION, progress_callback);
        curl_easy_setopt(info->mcurl, CURLOPT_NOPROGRESS, 0);
        curl_easy_setopt(info->mcurl, CURLOPT_PROGRESSDATA, userData);
    }
    log_console("[CURL] preparing to download from URL (1/3)...\n");
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
    
    curl_off_t len = 0;
    curl_easy_getinfo(info->mcurl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &len);
    if (len <= 0) {
        err = 1;
        writeErrorMsg("Requested resource is unavailable.");
        goto error;
    }
    assure((info->length = len) > sizeof(fragmentzip_end_of_cd));
    
    //get end of central directory
    assure(dbuf->buf = malloc(dbuf->size_buf = sizeof(fragmentzip_end_of_cd)));
    
    curl_easy_setopt(info->mcurl, CURLOPT_WRITEFUNCTION, &downloadFunction);
    curl_easy_setopt(info->mcurl, CURLOPT_WRITEDATA, dbuf);
    
    char downloadRange[100] = {0};
    snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu",info->length - sizeof(fragmentzip_end_of_cd), info->length-1);
    
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    curl_easy_setopt(info->mcurl, CURLOPT_HTTPGET, 1);

    log_console("[CURL] preparing to download from URL (2/3)...\n");
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);

    assure(strncmp(dbuf->buf, "\x50\x4b\x05\x06", 4) == 0);
    
    cde = (fragmentzip_end_of_cd*)dbuf->buf;
//    fixEndian_end_of_cd(cde);

    memset(downloadRange, 0, sizeof(downloadRange));
    snprintf(downloadRange, sizeof(downloadRange), "%u-%llu",cde->cd_start_offset, info->length-1);

    dbuf->size_downloaded = 0;
    dbuf->size_buf = cde->cd_size + sizeof(fragmentzip_end_of_cd);
    assure(dbuf->buf = malloc(dbuf->size_buf));

    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    log_console("[CURL] preparing to download from URL (3/3)...\n");
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);

    assure(strncmp(dbuf->buf, "\x50\x4b\x01\x02", 4) == 0);
    
    info->cd = (fragmentzip_cd *)dbuf->buf;
    info->cd_end = (fragmentzip_end_of_cd *)(((char *)info->cd)+cde->cd_size);

error:
    if (err) {
        fragmentzip_close(info);
        info = NULL;
        if (dbuf) {
            free(dbuf->buf);
        }
    }
    free(dbuf);
    free(cde);
    return info;
}

fragmentzip_t *fragmentzip_open(const char *url, TSSCustomUserData *userData) {
    return fragmentzip_open_extended(url, curl_easy_init(), userData);
}

fragmentzip_cd *fragmentzip_getCDForPath(fragmentzip_t *info, const char *path){
    size_t path_len = strlen(path);

    fragmentzip_cd *curr = info->cd;
    for (int i=0; i<info->cd_end->cd_entries; i++) {
        
        if (path_len == curr->len_filename && strncmp(curr->filename, path, path_len) == 0) return curr;
        
        curr = fragmentzip_nextCD(curr);
    }

    return NULL;
}

int fragmentzip_download_file(fragmentzip_t *info, const char *remotepath, TSSDataBuffer *buffer, fragmentzip_process_callback_t callback, TSSCustomUserData *userData) {
    int err = 0;

    log_console("[CURL] downloading from URL...\n");

    t_downloadBuffer *compressed = NULL;
    fragentzip_local_file *lfile = NULL;
    char *uncompressed = NULL;

    fragmentzip_cd *rfile = NULL;
    if (!(rfile = fragmentzip_getCDForPath(info, remotepath))) {
        writeErrorMsg("Cannot locate BuildManifest in specified URL.");
        err = -1;
        goto error;
    }

    if (!buffer) {
        // client just check availability; no buffer container passed.
        goto error;
    }

    retassure(-2,compressed = calloc(1, sizeof(t_downloadBuffer)));
    compressed->callback = callback;
    
    retassure(-3,compressed->buf = malloc(compressed->size_buf = sizeof(fragentzip_local_file)-1));
    
    char downloadRange[100] = {0};
    snprintf(downloadRange, sizeof(downloadRange), "%u-%u",rfile->local_header_offset,(unsigned)(rfile->local_header_offset + compressed->size_buf-1));
    
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    curl_easy_setopt(info->mcurl, CURLOPT_WRITEDATA, compressed);
    
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
    
    retassure(-5,strncmp(compressed->buf, "\x50\x4b\x03\x04", 4) == 0);
    
    lfile = (fragentzip_local_file*)compressed->buf;

    compressed->size_downloaded = 0;
    retassure(-6,compressed->buf = malloc(compressed->size_buf = rfile->size_compressed));
    
    memset(downloadRange, 0, sizeof(downloadRange));
    
    unsigned int start = (unsigned int)rfile->local_header_offset + sizeof(fragentzip_local_file)-1 + lfile->len_filename + lfile->len_extra_field;
    snprintf(downloadRange, sizeof(downloadRange), "%u-%u",start,(unsigned int)(start+compressed->size_buf-1));
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
    
    retassure(-8,uncompressed = malloc(rfile->size_uncompressed));
    //file downloaded, now unpack it
    switch (lfile->compression) {
        case 8: //defalted
        {
            z_stream strm = {0};
            retassure(-13, inflateInit2(&strm, -MAX_WBITS) >= 0);
            
            strm.avail_in = rfile->size_compressed;
            strm.next_in = (Bytef *)compressed->buf;
            strm.avail_out = rfile->size_uncompressed;
            strm.next_out = (Bytef *)uncompressed;
            
            retassure(-14, inflate(&strm, Z_FINISH) > 0);
            retassure(-9,strm.msg == NULL);
            inflateEnd(&strm);
        }
            break;
            
        default:
            writeErrorMsg("Unknown compression method.");
            assure(0);
            break;
    }
    
    retassure(-10,crc32(0, (Bytef *)uncompressed, rfile->size_uncompressed) == rfile->crc32);
    
    //file unpacked, now save it
    buffer->buffer = uncompressed;
    uncompressed = NULL;
    buffer->length = rfile->size_uncompressed;
    log_console("[CURL] Success.\n");
error:
    if (compressed) {
        free(compressed->buf);
        free(compressed);
    }
    free(uncompressed);
    free(lfile);

    return err;
}


void fragmentzip_close(fragmentzip_t *info){
    if (info) {
        free(info->url);
        curl_easy_cleanup(info->mcurl);
        free(info->cd); //don't free info->cd_end because it points into the same buffer
        free(info);
    }
}
