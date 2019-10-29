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
//    char filename[]; //variable length
//    char extra_field[]; //variable length
} ATTRIBUTE_PACKED fragmentzip_local_file_header;

//typedef struct{
//    uint32_t crc32;
//    uint32_t size_compressed;
//    uint32_t size_uncompressed;
//} ATTRIBUTE_PACKED fragmentzip_data_descriptor;

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
    uint64_t zip64_end_of_cd_record_size; // excluding self
    uint16_t version_made_by;
    uint16_t version_needed_to_extract;
    uint32_t cd_disk_number;
    uint32_t num_of_disk_with_start_of_cd;
    uint64_t total_entries_in_cd_on_disk;
    uint64_t total_entries;
    uint64_t cd_size;
    uint64_t cd_start_offset;
    char zip64_extensible_data[];
} ATTRIBUTE_PACKED fragmentzip64_end_of_cd_record;

typedef struct{
    uint32_t signature;
    uint32_t num_of_disk_start_of_cd_end; // excluding self
    uint64_t relative_offset_of_zip64_cde_record;
    uint32_t num_of_disk;
} ATTRIBUTE_PACKED fragmentzip64_end_of_cd_locator;

struct Fragmentzip_extraField_64 {
    uint16_t tag;
    uint16_t size;  // the size for extra field minus tag and self (-4)
    uint64_t original_uncompressed_fileSize;
    uint64_t compressed_fileSize;
    uint64_t relative_header_offset;
} ATTRIBUTE_PACKED;
typedef struct Fragmentzip_extraField_64 Fragmentzip_extraField_64;

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
    char filename[]; //variable length
//    char extra_field[]; //variable length
//    char file_comment[]; //variable length
} ATTRIBUTE_PACKED fragmentzip_cd;

struct fragmentzip_info {
    char *url;
    CURL *mcurl;
    uint64_t length;
    fragmentzip_cd *cd;
    uint64_t entries_in_zip;
};

#define CASSERT(predicate, file) _impl_CASSERT_LINE(predicate,__LINE__,file)

#define _impl_PASTE(a,b) a##b
#define _impl_CASSERT_LINE(predicate, line, file) \
typedef char _impl_PASTE(assertion_failed_##file##_,line)[2*!!(predicate)-1];

#define retassure(cond, code, msg...) do{ if ((cond) == 0){err=code; error(msg); writeErrorMsg(msg); goto error;} }while(0)
#define assure(cond) do{ if ((cond) == 0){err=Other_Error; goto error;} } while(0)

#define fragmentzip_nextCD(cd) ((fragmentzip_cd *)(cd->filename+cd->len_filename+cd->len_extra_field+cd->len_file_comment))

typedef struct{
    char *buf;
    size_t size_buf;
    size_t size_downloaded;
    fragmentzip_process_callback_t callback;
}t_downloadBuffer;

static size_t downloadFunction(void* data, size_t size, size_t nmemb, t_downloadBuffer* dbuf) {
    const size_t dsize = size * nmemb;
    size_t vsize = 0;
    if (dsize <= dbuf->size_buf - dbuf->size_downloaded){
        vsize = dsize;
    }
    else{
        vsize = dbuf->size_buf - dbuf->size_downloaded;
//        printf("Overflow: %lu.\n", (dsize - vsize));
    }

    memcpy(dbuf->buf + dbuf->size_downloaded, data, vsize);
    dbuf->size_downloaded += vsize;
//    printf("DEBUG: dbuf->size_buf: %zu, dbuf->downloaded_size: %zu, nmemb: %zu, vsize: %zu.\n", dbuf->size_buf, dbuf->size_downloaded, nmemb, vsize);
//    log_console("%.02f...", (((double)dbuf->size_downloaded/dbuf->size_buf)*100));
    if (dbuf->callback){
        dbuf->callback((unsigned int)(((double)dbuf->size_downloaded/dbuf->size_buf)*100));
    }
    return vsize;
}
CASSERT(sizeof(fragmentzip64_end_of_cd_record) == 56, fragmentzip64_end_of_cd_record_size_is_not_56);
CASSERT(sizeof(fragmentzip_local_file_header) == 30, fragmentzip_local_file_header_size_is_not_30);
CASSERT(sizeof(fragmentzip64_end_of_cd_locator) == 20, fragmentzip64_end_of_cd_locator_size_is_not_20);
CASSERT(sizeof(fragmentzip_cd) == 46, fragmentzip_cd_size_is_wrong);
CASSERT(sizeof(fragmentzip_end_of_cd) == 22, fragmentzip_end_of_cd_size_is_wrong);
CASSERT(sizeof(uint64_t) == 8, uint64_t_is_not_8_bytes);

static CURLcode curlEasyPerformRetry(CURL *handler, int retry, TSSCustomUserData *userData) {
    t_downloadBuffer *downloadBuffer;
    curl_easy_getinfo(handler, CURLINFO_PRIVATE, &downloadBuffer);
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
        downloadBuffer->size_downloaded = 0;
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
static inline void reinit_downloadBuffer(t_downloadBuffer *buffer, size_t size) {
    buffer->size_downloaded = 0;
    free(buffer->buf);
    buffer->size_buf = size;
    buffer->buf = malloc(size);
}
enum Error_Code {
    No_Error = 0,
    Incorrect_Signature = -1,
    File_Not_Found = -2,
    Other_Error = -99,
};
static fragmentzip_t *fragmentzip_open_extended(const char *url, CURL *mcurl, TSSCustomUserData *userData) {
    enum Error_Code err = No_Error;
    fragmentzip_t *info = NULL;
    t_downloadBuffer downloadbuffer = {0};
    assure(info = calloc(1, sizeof(fragmentzip_t)));

    assure(info->url = strdup(url));
    assure(info->mcurl = mcurl);

    if (userData && userData->timeout != 0) {
        const long connection_timeout = userData->timeout;
        const long total_transfer_timeout = connection_timeout + 10;  // buildmanifest should not take more than 10 + connection_timeout sec. to get.

        curl_easy_setopt(info->mcurl, CURLOPT_CONNECTTIMEOUT, connection_timeout);
        curl_easy_setopt(info->mcurl, CURLOPT_TIMEOUT, total_transfer_timeout);
    }
    curl_easy_setopt(info->mcurl, CURLOPT_URL, info->url);
    curl_easy_setopt(info->mcurl, CURLOPT_NOBODY, 1);
    curl_easy_setopt(info->mcurl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(info->mcurl, CURLOPT_PRIVATE, &downloadbuffer);

    {
        static const char *userAgent[] = {"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1"};
        curl_easy_setopt(info->mcurl, CURLOPT_USERAGENT, userAgent[arc4random_uniform(sizeof(userAgent)/sizeof(userAgent[0]))]);
    }

    if (userData) {
        curl_easy_setopt(info->mcurl, CURLOPT_XFERINFOFUNCTION, progress_callback);
        curl_easy_setopt(info->mcurl, CURLOPT_NOPROGRESS, 0);
        curl_easy_setopt(info->mcurl, CURLOPT_PROGRESSDATA, userData);
    }
    log_console("[CURL] preparing to download from URL (1/3)...\n");
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
    
    curl_easy_getinfo(info->mcurl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &info->length);
    retassure(info->length > 0, Other_Error, "Requested resource is unavailable.");

    retassure(info->length > sizeof(fragmentzip_end_of_cd), Other_Error, "Invalid zip format.");
    
    //get end of central directory
    reinit_downloadBuffer(&downloadbuffer, sizeof(fragmentzip_end_of_cd));

    curl_easy_setopt(info->mcurl, CURLOPT_WRITEFUNCTION, &downloadFunction);
    curl_easy_setopt(info->mcurl, CURLOPT_WRITEDATA, &downloadbuffer);

    char downloadRange[100] = {0};
    snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu",info->length - sizeof(fragmentzip_end_of_cd), info->length-1);
    
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    curl_easy_setopt(info->mcurl, CURLOPT_HTTPGET, 1);

    log_console("[CURL] preparing to download from URL (2/3)...\n");
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);

    retassure(strncmp(downloadbuffer.buf, "\x50\x4b\x05\x06", 4) == 0, Incorrect_Signature, "Incorrect zip header signature.");
    
    uint64_t cd_start_offset = 0;
    if (((fragmentzip_end_of_cd *)downloadbuffer.buf)->cd_start_offset == 0xffffffff) {
        // Zip64
        // get locator and then get cde.
        log_console("[CURL] Firmware is in Zip64 format. Downloading locator metadata...\n");
        reinit_downloadBuffer(&downloadbuffer, sizeof(fragmentzip64_end_of_cd_locator));
        snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu",info->length - sizeof(fragmentzip_end_of_cd) - sizeof(fragmentzip64_end_of_cd_locator), info->length - sizeof(fragmentzip_end_of_cd) - 1);
        curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
        assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
        fragmentzip64_end_of_cd_locator *locator = (fragmentzip64_end_of_cd_locator *)downloadbuffer.buf;
        retassure(*(uint32_t *)downloadbuffer.buf == 0x07064b50, -2, "Incorrect locator header signature.");
        const uint64_t record_start_offset = locator->relative_offset_of_zip64_cde_record;

        log_console("[CURL] Firmware is in Zip64 format. Downloading record metadata...\n");
        reinit_downloadBuffer(&downloadbuffer, info->length - sizeof(fragmentzip_end_of_cd) - sizeof(fragmentzip64_end_of_cd_locator) - record_start_offset);

        // note cde record might have extensible data.
        snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu", record_start_offset, info->length - sizeof(fragmentzip_end_of_cd) - sizeof(fragmentzip64_end_of_cd_locator) - 1);
        curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
        assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
        fragmentzip64_end_of_cd_record *record = (fragmentzip64_end_of_cd_record *)downloadbuffer.buf;
        retassure(*(uint32_t *)downloadbuffer.buf == 0x06064b50, -2, "Incorrect record header signature.");

        cd_start_offset = record->cd_start_offset;
        info->entries_in_zip = record->total_entries;
    }
    else {
        fragmentzip_end_of_cd *cde = (fragmentzip_end_of_cd *)downloadbuffer.buf;
        cd_start_offset = cde->cd_start_offset;
        info->entries_in_zip = cde->cd_entries;
    }

    memset(downloadRange, 0, sizeof(downloadRange));
    snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu",cd_start_offset, info->length - 1);

    reinit_downloadBuffer(&downloadbuffer, info->length - cd_start_offset);
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    log_console("[CURL] preparing to download from URL (3/3)...\n");
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);

    retassure(strncmp(downloadbuffer.buf, "\x50\x4b\x01\x02", 4) == 0, Incorrect_Signature, "Incorrect zip header signature.");

    info->cd = (fragmentzip_cd *)downloadbuffer.buf;

error:
    if (err) {
        fragmentzip_close(info);
        info = NULL;
        free(downloadbuffer.buf);
    }
    return info;
}

fragmentzip_t *fragmentzip_open(const char *url, TSSCustomUserData *userData) {
    return fragmentzip_open_extended(url, curl_easy_init(), userData);
}

fragmentzip_cd *fragmentzip_getCDForPath(fragmentzip_t *info, const char *path){
    const size_t path_len = strlen(path);
    fragmentzip_cd *curr = info->cd;
    for (int i = 0; i < info->entries_in_zip; i++) {
        if (path_len == curr->len_filename && strncmp(curr->filename, path, path_len) == 0)
            return curr;
        curr = fragmentzip_nextCD(curr);
    }
    return NULL;
}

int fragmentzip_download_file(fragmentzip_t *info, const char *remotepath, TSSDataBuffer *buffer, fragmentzip_process_callback_t callback, TSSCustomUserData *userData) {
    enum Error_Code err = No_Error;

    log_console("[CURL] downloading from URL...\n");

    t_downloadBuffer compressed = {0};
    fragmentzip_local_file_header *lfile = NULL;
    char *uncompressed = NULL;

    fragmentzip_cd *rfile = NULL;
    retassure((rfile = fragmentzip_getCDForPath(info, remotepath)), Other_Error, "Cannot locate BuildManifest in specified URL.");

    if (!buffer) {
        // client just check availability; no buffer container passed.
        goto error;
    }

    compressed.callback = callback;
    
    assure(compressed.buf = malloc(compressed.size_buf = sizeof(fragmentzip_local_file_header)));
    
    char downloadRange[100] = {0};
    uint64_t headerOffset = rfile->local_header_offset, compressedSize = rfile->size_compressed, uncompressedSize = rfile->size_uncompressed;
    if (rfile->pkzip_version_needed >= 45) {
        // zip64 format
        Fragmentzip_extraField_64 *field = (Fragmentzip_extraField_64 *)(rfile->filename + rfile->len_filename);
        retassure(field->tag == 0x1, Incorrect_Signature, "Invalid zip extensible data tag.");   // unidentified zip ext. data tag
        switch (field->size) {
            // sizeof(field->original_uncompressed_fileSize) + sizeof(field->compressed_fileSize) + sizeof(field->relative_header_offset)
            case 24:
                headerOffset = field->relative_header_offset;
            // sizeof(field->original_uncompressed_fileSize) + sizeof(field->compressed_fileSize)
            case 16:
                compressedSize = field->compressed_fileSize;
                uncompressedSize = field->original_uncompressed_fileSize;
                break;
            default:
                retassure(0, Incorrect_Signature, "Incorrect zip extensible data size.");
        }
    }
    snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu",headerOffset, (headerOffset + compressed.size_buf - 1));
    
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    curl_easy_setopt(info->mcurl, CURLOPT_WRITEDATA, &compressed);
    
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
    
    retassure(strncmp(compressed.buf, "\x50\x4b\x03\x04", 4) == 0, Incorrect_Signature, "Incorrect zip header signature");
    
    lfile = (fragmentzip_local_file_header *)compressed.buf;
    compressed.buf = NULL;

    reinit_downloadBuffer(&compressed, compressedSize);

    const uint64_t start = headerOffset + sizeof(fragmentzip_local_file_header) + lfile->len_filename + lfile->len_extra_field;
    snprintf(downloadRange, sizeof(downloadRange), "%llu-%llu",start, start + compressed.size_buf - 1);
    curl_easy_setopt(info->mcurl, CURLOPT_RANGE, downloadRange);
    
    assure(curlEasyPerformRetry(info->mcurl, 2, userData) == CURLE_OK);
    
    assure(uncompressed = malloc(uncompressedSize));
    //file downloaded, now unpack it
    switch (lfile->compression) {
        case 8: // deflated
        {
            z_stream strm = {0};
            retassure(inflateInit2(&strm, -MAX_WBITS) >= 0, Other_Error, "Failed to init zlib.");
            
            strm.avail_in = compressedSize;
            strm.next_in = (Bytef *)compressed.buf;
            strm.avail_out = uncompressedSize;
            strm.next_out = (Bytef *)uncompressed;
            
            retassure(inflate(&strm, Z_FINISH) > 0, Other_Error, "Failed to inflate data.");
            retassure(strm.msg == NULL, Other_Error, "An error has occurred when deflate data: %s.", strm.msg);
            inflateEnd(&strm);
        }
            break;
        default:
            retassure(0, Other_Error, "Unknown compression method: %d", lfile->compression);
    }
    
    retassure(crc32(0, (Bytef *)uncompressed, uncompressedSize) == rfile->crc32, Other_Error, "crc32 check failed.");
    
    //file unpacked, now save it
    buffer->buffer = uncompressed;
    uncompressed = NULL;
    buffer->length = uncompressedSize;
    log_console("[CURL] Success.\n");
error:
    free(compressed.buf);
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
