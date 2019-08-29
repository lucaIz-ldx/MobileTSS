#include "validate.h"
#include "validate_ca.h"

#include <stdio.h>
#include <string.h>
#include <openssl/asn1.h>
#include <openssl/x509.h>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <openssl/err.h>

#define IMG3_MAGIC 0x496d6733
#define IMG3_DATA_MAGIC 0x44415441
#define IMG3_VERS_MAGIC 0x56455253
#define IMG3_SEPO_MAGIC 0x5345504f
#define IMG3_SCEP_MAGIC 0x53434550
#define IMG3_BORD_MAGIC 0x424f5244
#define IMG3_BDID_MAGIC 0x42444944
#define IMG3_SHSH_MAGIC 0x53485348
#define IMG3_CERT_MAGIC 0x43455254
#define IMG3_KBAG_MAGIC 0x4B424147
#define IMG3_TYPE_MAGIC 0x54595045
#define IMG3_ECID_MAGIC 0x45434944

typedef struct AppleImg3Header {
    uint32_t magic;
    uint32_t size;
    uint32_t dataSize;
}__attribute__((__packed__)) AppleImg3Header;


#define FLIPENDIAN(x) flipEndian((unsigned char *)(&(x)), sizeof(x))
static inline void flipEndian(unsigned char* x, int length) {
    unsigned char tmp;
    for(int i = 0; i < (length / 2); i++) {
        tmp = x[i];
        x[i] = x[length - i - 1];
        x[length - i - 1] = tmp;
    }
}

struct tuple_t {
    long len;
    const unsigned char *value;
};
typedef struct tuple_t tuple_t;
struct TupleArray {
    tuple_t *content;
    int index;
    int length;
};
typedef struct TupleArray TupleArray;

static inline void save_tuple(struct tuple_t *dst, const void *src, long len) {
    dst->len = len;
    dst->value = src;
}

static int show_cont(int xclass, const unsigned char *p, long len, TupleArray *array)
{
    if ((xclass & V_ASN1_CONTEXT_SPECIFIC) == V_ASN1_CONTEXT_SPECIFIC) {
        struct tuple_t *tmp;
        if (array->index >= array->length) {
            tuple_t *oriArray = array->content;
            array->content = malloc(array->length * 2 * sizeof(struct tuple_t));
            if (!array->content) {
                array->length /= 2;
                array->content = oriArray;
                return -1;
            }
            array->length *= 2;
            memcpy(array->content, oriArray, (array->index - 1) * sizeof(struct tuple_t));
            free(oriArray);
        }
        tmp = array->content + array->index++;
        save_tuple(tmp, p, len);
    }
    return 0;
}

/*
 * This function was lifted from OpenSSL crypto/asn1/asn1_par.c
 * As a consequence, its respective Copyright and Licence applies.
 */

static int
asn1_parse2(const unsigned char **pp, long length, long offset, int depth, tuple_t *theset, tuple_t *rsasig, tuple_t *apcert, TupleArray *array)
{
	const unsigned char *p, *ep, *tot, *op;
	long len, hl;
	int j, tag, xclass, r, ret = 0;
	p = *pp;
	tot = p + length;
	op = p - 1;
	while (p < tot && op < p) {
		op = p;
		j = ASN1_get_object(&p, &len, &tag, &xclass, length);
		if (j & 0x80) {
//            XLOG(0, "Error in encoding\n");
			goto end;
		}
		hl = p - op;
		length -= hl;
		/* if j == 0x21 it is a constructed indefinite length object */

		if (j & V_ASN1_CONSTRUCTED) {
			ep = p + len;
			if (len > length) {
//                XLOG(0, "length is greater than %ld\n", length);
				goto end;
			}
			if (j == 0x21 && len == 0) {
				for (;;) {
					r = asn1_parse2(&p, tot - p, offset + (p - *pp), depth + 1, theset, rsasig, apcert, array);
					if (r == 0) {
						goto end;
					}
					if (r == 2 || p >= tot) {
						break;
					}
				}
			} else {
				if (depth == 1 && !xclass && tag == V_ASN1_SET) save_tuple(theset, op, hl + len);
				if (depth == 1 && (xclass & V_ASN1_CONTEXT_SPECIFIC) == V_ASN1_CONTEXT_SPECIFIC) save_tuple(apcert, p, len);
				while (p < ep) {
					r = asn1_parse2(&p, len, offset + (p - *pp), depth + 1, theset, rsasig, apcert, array);
					if (r == 0) {
						goto end;
					}
				}
			}
		} else if (xclass != 0) {
			if (show_cont(xclass, op + hl, len, array)) goto end;
			p += len;
		} else {
			/* DECODE HERE */
			if (depth == 1 && tag == V_ASN1_OCTET_STRING) save_tuple(rsasig, p, len);
			/* DECODE HERE */
			p += len;
			if (tag == V_ASN1_EOC && xclass == 0) {
				ret = 2;	/* End of sequence */
				goto end;
			}
		}
		length -= len;
	}
	ret = 1;
end:
	if (!ret) {
		free(array->content);
        memset(array, 0, sizeof(*array));
	}
	*pp = p;
	return ret;
}
typedef plist_t plist_data_t;
typedef plist_t plist_dict_t;
typedef plist_t plist_array_t;
typedef plist_t plist_string_t;

struct component_t {
	char *key;
	char *path;
	char *build;
	TSSDataBuffer digest;
	TSSDataBuffer partial;
	TSSDataBuffer blob;
	int required;
};
typedef struct component_t Component_t;
static uint64_t getECID(const void *data)
{
	unsigned char temp[8];
	memcpy(temp, data, sizeof(temp));
	return *(uint64_t *)temp;
}

static void doPartialSHA1(unsigned char md[SHA_DIGEST_LENGTH], const unsigned char *toHashData, int toHashLength, const unsigned int *partialDigest)
{
//    unsigned int v31 = partialDigest[0]; // XXX ASSERT(v31 == ecid->size == 64)?
	unsigned int v32 = partialDigest[1];
	SHA_CTX hashctx;
	memset(&hashctx, 0, sizeof(hashctx));
	hashctx.h0 = partialDigest[2];
	hashctx.h1 = partialDigest[3];
	hashctx.h2 = partialDigest[4];
	hashctx.h3 = partialDigest[5];
	hashctx.h4 = partialDigest[6];
	FLIPENDIAN(hashctx.h0);
	FLIPENDIAN(hashctx.h1);
	FLIPENDIAN(hashctx.h2);
	FLIPENDIAN(hashctx.h3);
	FLIPENDIAN(hashctx.h4);
	hashctx.Nl = 8 * v32 + 64; // XXX could this 64 be actually v31?
	SHA1_Update(&hashctx, toHashData, toHashLength);
	SHA1_Final(md, &hashctx);
}

static int
extract2Certs(const unsigned char *p, long length, X509 **x1, X509 **x2)
{
	const unsigned char *cert1;
	const unsigned char *cert2;

	long len1, len2;
	int j, tag, xclass;

	cert1 = p;
	j = ASN1_get_object(&p, &len1, &tag, &xclass, length);
	if (j != V_ASN1_CONSTRUCTED) {
		return -1;
	}
	p += len1;
	len1 = p - cert1;
	if (len1 >= length) {
		return -1;
	}
	*x1 = d2i_X509(NULL, &cert1, len1);
	if (!*x1) {
		return -1;
	}
	length -= len1;

	cert2 = p;
	j = ASN1_get_object(&p, &len2, &tag, &xclass, length);
	if (j != V_ASN1_CONSTRUCTED) {
		X509_free(*x1);
		return -1;
	}
	p += len2;
	len2 = p - cert2;
	if (len2 > length) {
		X509_free(*x1);
		return -1;
	}
	*x2 = d2i_X509(NULL, &cert2, len2);
	if (!*x2) {
		X509_free(*x1);
		return -1;
	}

	return 0;
}

static int cryptoMagic(X509 *x0, X509 *x1, X509 *x2,
	    const unsigned char *toHashData, int toHashLength,
	    /*XXX const*/ unsigned char *rsaSigData, int rsaSigLen,
	    const unsigned int *partialDigest)
{
	int rv = 0;
	EVP_PKEY *pk = X509_get_pubkey(x2);
	if (pk) {
		if (pk->type == EVP_PKEY_RSA) {
			RSA *rsa = EVP_PKEY_get1_RSA(pk);
			if (rsa) {
				X509_STORE *store = X509_STORE_new();
				if (store) {
					X509_STORE_CTX ctx;
					X509_STORE_add_cert(store, x0);
					X509_STORE_add_cert(store, x1);
					if (X509_STORE_CTX_init(&ctx, store, x2, 0) == 1) {
						X509_STORE_CTX_set_flags(&ctx, X509_V_FLAG_IGNORE_CRITICAL);
						if (X509_verify_cert(&ctx) == 1) {
							unsigned char md[SHA_DIGEST_LENGTH];
                            if (partialDigest) {
//                                 XXX we need to flip ECID back before hashing
								doPartialSHA1(md, toHashData, toHashLength, partialDigest);
                            } else {
                                SHA1(toHashData, toHashLength, md);
                            }
							rv = RSA_verify(NID_sha1, md, SHA_DIGEST_LENGTH, rsaSigData, rsaSigLen, rsa);
						}
						X509_STORE_CTX_cleanup(&ctx);
					}
					X509_STORE_free(store);
				}
				RSA_free(rsa);
			}
		}
		EVP_PKEY_free(pk);
	}
	return rv ? 0 : -1;
}

static const char *
checkBlob(X509 *x0, const TSSDataBuffer *blob, const TSSDataBuffer *partialDigest, uint64_t *savecid)
{
    int64_t len = blob->length;
    const unsigned char *ptr = (const unsigned char *)blob->buffer;

    AppleImg3Header *cert = NULL;
    AppleImg3Header *ecid = NULL;
    AppleImg3Header *shsh = NULL;

    while (len > 0) {
        AppleImg3Header *hdr;
        if (len < sizeof(AppleImg3Header)) {
            return "truncated";
        }
        hdr = (AppleImg3Header *)ptr;
//        flipAppleImg3Header(hdr); // XXX we need to flip ECID back before hashing
        switch (hdr->magic) {
            case IMG3_ECID_MAGIC:
                ecid = (AppleImg3Header *)ptr;
                break;
            case IMG3_SHSH_MAGIC:
                shsh = (AppleImg3Header *)ptr;
                break;
            case IMG3_CERT_MAGIC:
                cert = (AppleImg3Header *)ptr;
                break;
            default:
                return "unknown";
        }
        len -= hdr->size;
        ptr += hdr->size;
    }

    if (!ecid || !shsh || !cert) {
        return "incomplete";
    }
    unsigned int partial0 = *(unsigned int *)partialDigest->buffer;
    if (partial0 != 0x40 || partial0 != ecid->size) {
        return "internal"; // XXX see doPartialSHA1()
    }

    uint64_t thisecid = getECID(ecid + 1);
    if (*savecid == 0) {
        *savecid = thisecid;
    }
    if (*savecid != thisecid) {
        return "mismatch";
    }

    X509 *x1 = NULL, *x2 = NULL;
    int rv = extract2Certs((unsigned char *)(cert + 1), cert->dataSize, &x1, &x2);
    if (rv) {
        return "asn1";
    }

    rv = cryptoMagic(x0, x1, x2, (unsigned char *)ecid, ecid->size, (unsigned char *)(shsh + 1), shsh->dataSize, (const unsigned int *)partialDigest->buffer);

    X509_free(x2);
    X509_free(x1);
    return rv ? "crypto" : NULL;
}

#define reterror(a...) do {err = 1; error(a); goto error; } while (0)
int verifyIMG3WithIdentity(plist_t shshDict, plist_t buildIdentity, TSSCustomUserData *userData) {
    buildIdentity = plist_dict_get_item(buildIdentity, "Manifest");

    size_t componentsArraySize = 0;

    int err = 0;
    OPENSSL_add_all_algorithms_noconf();
    const unsigned char *p = cerb;
    X509 *x0 = d2i_X509(NULL, &p, cerb_len);
    if (!x0) {
        error("FATAL: cannot load root CA.\n");
        writeErrorMsg("Cannot load root CA.");
        return -1;
    }

    Component_t *const components = calloc(plist_dict_get_size(buildIdentity), sizeof(Component_t));
    int index = 0;
    {
        plist_dict_iter iterator = NULL;
        plist_dict_new_iter(buildIdentity, &iterator);
        char *key = NULL;
        plist_t node = NULL;
        plist_dict_next_item(buildIdentity, iterator, &key, &node);
        for (; key; plist_dict_next_item(buildIdentity, iterator, &key, &node)) {
            plist_data_t digestData = plist_dict_get_item(node, "Digest");
            if (!digestData || plist_get_node_type(digestData) != PLIST_DATA) {
                warning("Cannot get digest data in key: %s.\n", key);
                free(key);
                continue;
            }
            components[index].key = key;
            plist_get_data_val(digestData, &components[index].digest.buffer, (uint64_t *)&components[index].digest.length);

            plist_get_data_val(plist_dict_get_item(node, "PartialDigest"), &components[index].partial.buffer, (uint64_t *)&components[index].partial.length);

            plist_string_t buildString = plist_dict_get_item(node, "BuildString");

            if (plist_get_node_type(buildString) == PLIST_STRING) {
                plist_get_string_val(buildString, &components[index].build);
            }
            plist_dict_t infoDict = plist_dict_get_item(node, "Info");
            if (infoDict && plist_get_node_type(infoDict) == PLIST_DICT) {
                plist_get_string_val(plist_dict_get_item(infoDict, "Path"), &components[index].path);
                uint8_t isfw = 0;
                plist_t firmwarePayload = plist_dict_get_item(infoDict, "IsFirmwarePayload");
                if (plist_get_node_type(firmwarePayload) == PLIST_BOOLEAN) {
                    plist_get_bool_val(firmwarePayload, &isfw);
                }
                components[index].required = isfw || !strcmp(key, "KernelCache");
            }
            index++;
        }
        componentsArraySize = index;
        free(iterator);
    }

    TupleArray tupleArray;
    tupleArray.content = malloc(sizeof(tuple_t) * 8);
    tupleArray.index = 0;
    tupleArray.length = 8;
    struct tuple_t apcert = {0};
    struct tuple_t rsasig = {0};
    struct tuple_t theset = {0};

    uint64_t savecid = 0;

    plist_data_t apticket = plist_dict_get_item(shshDict, "APTicket");
    TSSDataBuffer ticketData = {0};
    plist_get_data_val(apticket, &ticketData.buffer, (uint64_t *)&ticketData.length);
    if (ticketData.buffer) {
        int rv = asn1_parse2((const unsigned char **)&ticketData.buffer, ticketData.length, 0, 0, &theset, &rsasig, &apcert, &tupleArray);
        if (!rv || !apcert.value || !rsasig.value || !theset.value) {
            writeErrorMsg("Cannot parse ticket.");
            reterror("FATAL: cannot parse ticket.\n");
        }
        if (tupleArray.index > 0 && tupleArray.content[0].len == 8) {
            savecid = getECID(tupleArray.content[0].value);
        }
        if (!savecid) {
            error("bad, bad ECID\n");
            writeErrorMsg("Bad ECID.");
            err = 1;
        }
        X509 *y1, *y2;
        rv = extract2Certs(apcert.value, apcert.len, &y1, &y2);
        if (rv == 0) {
            cryptoMagic(x0, y1, y2, theset.value, (int)theset.len, (unsigned char *)rsasig.value, (int)rsasig.len, NULL);
            X509_free(y1);
            X509_free(y2);
        }
        else {
            error("APTicket failed crypto.\n");
            writeErrorMsg("APTicket wailed crypto.");
            err = 1;
        }
    }
    else {
        warning("WARNING: cannot find apticket.\n");
    }

    plist_dict_iter iterator = NULL;
    plist_dict_new_iter(shshDict, &iterator);
    char *key = NULL;
    plist_t node = NULL;
    plist_dict_next_item(shshDict, iterator, &key, &node);
    for (; node; plist_dict_next_item(shshDict, iterator, &key, &node)) {

        plist_data_t blobNode = plist_dict_get_item(node, "Blob");
        TSSDataBuffer shshblobData = {0};
        plist_get_data_val(blobNode, &shshblobData.buffer, (uint64_t *)&shshblobData.length);

        plist_data_t partialDigestNode = plist_dict_get_item(node, "PartialDigest");
        TSSDataBuffer shshPartialDigestData = {0};
        plist_get_data_val(partialDigestNode, &shshPartialDigestData.buffer, (uint64_t *)&shshPartialDigestData.length);
        if (shshblobData.buffer && shshPartialDigestData.buffer) {
            const char *diag = checkBlob(x0, &shshblobData, &shshPartialDigestData, &savecid);
            if (diag) {
                error("Blob for %s is invalid (%s)\n", key, diag);
                err = 1;
            }
            else {
                for (int index = 0; index < componentsArraySize; index++) {
                    if (components[index].partial.buffer &&
                        shshPartialDigestData.length == components[index].partial.length &&
                        memcmp(components[index].partial.buffer, shshPartialDigestData.buffer, shshPartialDigestData.length) == 0) {
                        components[index].blob.buffer = malloc(shshblobData.length);
                        components[index].blob.length = shshblobData.length;
                        memcpy(components[index].blob.buffer, shshblobData.buffer, shshblobData.length);
                    }
                }
            }
        }
        free(shshPartialDigestData.buffer);
        free(shshblobData.buffer);
        free(key);
    }
    free(iterator);

    if (!apticket && !savecid) {
		error("bad, bad ECID.\n");
        writeErrorMsg("Bad ECID.");
		err = 1;
	}

	for (int index = 0; index < componentsArraySize; index++) {
        struct component_t *centry = components + index;
		char found = 0;
		for (int j = 0; j < tupleArray.index; j++) {
			if (tupleArray.content[j].len == centry->digest.length && !memcmp(tupleArray.content[j].value, centry->digest.buffer, tupleArray.content[j].len)) {
				found = 1;
			}
		}
		if (!found) {
			if (centry->blob.buffer) {
				warning("no digest for %s (%s), but it has blob.\n", centry->key, centry->path);
			} else if (!centry->required) {
				warning("no digest for %s (%s), but it is not critical.\n", centry->key, centry->path);
			} else {
				error("no digest for %s (%s) and no blob found.\n", centry->key, centry->path);
                writeErrorMsg("No digest for %s (%s) and no blob found.", centry->key, centry->path);
				err = 1;
			}
		} else {
			info("%s is signed by APTicket%s.\n", centry->key, centry->blob.buffer ? " and blob" : "");
		}
	}
    if (err > 0) {
        error("SHSH is BROKEN.\n");
    }
    if (err == 0){
        info("SHSH seems usable for ECID %llu.\n", savecid);
    }

error:
	free(tupleArray.content);
    for (int index = 0; index < componentsArraySize; index++) {
        free(components[index].key);
        free(components[index].path);
        free(components[index].build);
        free(components[index].digest.buffer);
        free(components[index].partial.buffer);
        free(components[index].blob.buffer);
    }
    free(components);
	X509_free(x0);
	EVP_cleanup();
	ERR_remove_state(0);
	CRYPTO_cleanup_all_ex_data();
	return err;
}
