//
//  iDeviceInfo.cpp
//  TssTool-test
//
//  Created by User on 7/9/18.
//  Copyright © 2018 User. All rights reserved.
//

#include "iDeviceTSSRequest.hpp"
#include "TSSC.h"
#include "TSSHelper.h"

#include <unordered_set>
#include <cassert>

struct Nonce {
    char internalNonce[100];
    char readableNonce[100]; // always null terminated
    size_t parsedSize;
    Nonce(const char *parsedNonce, size_t parsedLength) {
        const size_t apnonceLen = parsedLength * 2;
        assert(parsedLength < sizeof(this->internalNonce)/sizeof(char));
        assert(apnonceLen + 2 < sizeof(this->readableNonce)/sizeof(char));
        for (int i = 0; i < apnonceLen; i += 2)
            std::snprintf(&this->readableNonce[i], apnonceLen - i + 1, "%02x", ((unsigned char *)parsedNonce)[i / 2]);
        this->parsedSize = parsedLength;
        memcpy(this->internalNonce, parsedNonce, parsedLength);
    }
    // readableNonce must be null-terminated.
    Nonce(const char *readableNonce, const char *parsedNonce, size_t parsedLength) {
        assert(parsedLength < sizeof(this->internalNonce)/sizeof(char));
        const size_t readableNonceLength = strlen(readableNonce);
        assert(readableNonceLength < sizeof(this->readableNonce)/sizeof(char));
        memcpy(this->readableNonce, readableNonce, readableNonceLength);
        memcpy(this->internalNonce, parsedNonce, parsedLength);
        this->parsedSize = parsedLength;
    }
};
static_assert(sizeof(uint64_t) == 8, "the size of uint64_t is not 8.");
template <>
void BufferContainer<void>::freeBuffer() {
    // delete void * is unsafe.
    if (this->form == Malloced_C) {
        free(this->buffer);
    }
    else {
        // assert freeFunc is nonnull.
        this->freeFunction(this->buffer);
    }
}
template <typename T>
static inline void safeFreeContainer(BufferContainer<T> *&container) {
    if (container) {
        container->freeBuffer();
        delete container;
        container = nullptr;
    }
}
static inline const char *buildManifestPathFromArchive(bool isOTA) {
    return isOTA ? "AssetData/boot/BuildManifest.plist" : "BuildManifest.plist";
}
static inline void fillOptionalUnknownErrMsg(char *modifiableString) {
    if (modifiableString[0] == '\0') {
        strcpy(modifiableString, "An unknown error has occurred.");
    }
}
static void cStringCopier(const char *originalString, char *&destination) {
    if (originalString == nullptr) {
        throw "Argument cannot be null. ";
    }
    const auto length = std::strlen(originalString);
    destination = new char[length + 1];
    strncpy(destination, originalString, length);
    destination[length] = '\0';
}
static bool writeStringBufferToPath(const StringBufferContainer &buffer, const char *path, TSSCustomUserData *userData) {
    using namespace std;
    // multiple instances try to write at the same time? This might be an issue.
    FILE *f = fopen(path, "w");
    if (!f || buffer.length != fwrite(buffer.buffer, sizeof(char), buffer.length, f)) {
        warning("Failed to write BuildManifest in temp folder. Maybe the path is not accessible? Continuing though...\n");
        if (f) {
            fclose(f);
        }
        return false;
    }
    info("Successfully wrote buildmanifest to tmp.\n");
    fclose(f);
    return true;
}
// no free plist_t.
static BuildIdentity *_getMatchedIdentitiesFromBuildManifest(const OpaqueBufferContainer *buildManifestPlist, DeviceInfo_ptr deviceInfo) {
    BuildIdentity identityTuple;
    // It is possible that incompatible ota update files includes the current model in its supporteddevicetypes.
    plist_t buildIdentities = plist_dict_get_item(buildManifestPlist->buffer, "BuildIdentities");
    const auto arraySize = plist_array_get_size(buildIdentities);
    for (int a = 0; a < arraySize; a++) {
        plist_t identityPlist = plist_array_get_item(buildIdentities, a);
        plist_t info = plist_dict_get_item(identityPlist, "Info");
        char *str = nullptr;
        plist_get_string_val(plist_dict_get_item(info, "DeviceClass"), &str);
        if (str && strcmp(deviceInfo->deviceBoardConfiguration, str) == 0) {
            free(str);
            str = nullptr;
            plist_get_string_val(plist_dict_get_item(info, "RestoreBehavior"), &str);
            if (str) {
                if (strcmp(str, "Update") == 0) {
                    identityTuple.updateInstall = identityPlist;
                }
                else if (strcmp(str, "Erase") == 0) {
                    identityTuple.eraseInstall = identityPlist;
                }
                else printf("[WARNING] Unknown restore behavior: %s.\n", str);
                if (identityTuple.eraseInstall && identityTuple.updateInstall) {
                    free(str);
                    break;
                }
            }
        }
        free(str);
    }
    return (identityTuple.eraseInstall || identityTuple.updateInstall) ? new BuildIdentity(identityTuple) : nullptr;
}
std::string iDeviceTSSRequest::temporaryDirectoryPath = std::string();
#pragma mark - Constr. & Destr.
iDeviceTSSRequest::iDeviceTSSRequest(const char *firmwareURL, DeviceInfo_ptr deviceInfo, uint64_t ecid) {
    this->generator[0] = '\0';
    this->userData = new TSSCustomUserData((TSSBoolean *)&this->connectionCanceled);
    this->deviceInfo = deviceInfo;
    cStringCopier(firmwareURL, this->firmwareURL);
    this->setECID(ecid);
}
iDeviceTSSRequest::~iDeviceTSSRequest() noexcept {
    delete [] this->apnonce;
    delete [] this->sepnonce;
    delete [] this->firmwareURL;
    safeFreeContainer(this->buildManifest);
    delete this->supportedDeviceModelList;
    delete this->userData;
    delete this->matchedBuildIdentity;
}
#pragma mark - Getter & Setter
void *iDeviceTSSRequest::delegate() const {
    return this->userData->userData;
}
const char *iDeviceTSSRequest::getApNonce() const {
    return this->apnonce->readableNonce;
}
bool iDeviceTSSRequest::setApNonce(const char *nonce) {
    if (!this->deviceInfo) {
        return false;
    }
    if (!nonce) {
        delete [] this->apnonce;
        this->apnonce = nullptr;
        return true;
    }
    size_t length = 0;
    char *parsedNonce = parseNonce(nonce, &length);
    if (!parsedNonce || length != apNonceLengthForDeviceModel(this->deviceInfo->deviceModel)) {
        free(parsedNonce);
        return false;
    }
    delete [] this->apnonce;
    this->apnonce = new Nonce(parsedNonce, length);
    free(parsedNonce);

    return true;
}
const char *iDeviceTSSRequest::getSepNonce() const {
    return this->sepnonce->readableNonce;
}
bool iDeviceTSSRequest::setSepNonce(const char *nonce) {
    if (!this->deviceInfo) {
        return false;
    }
    if (!nonce) {
        delete [] this->sepnonce;
        this->sepnonce = nullptr;
        return true;
    }
    size_t length = 0;
    char *parsedNonce = parseNonce(nonce, &length);
    if (!parsedNonce || length != requiredSepNonceLengthForModel(this->deviceInfo->deviceModel)) {
        free(parsedNonce);
        return false;
    }

    delete [] this->sepnonce;
    this->sepnonce = new Nonce(parsedNonce, length);
    free(parsedNonce);
    return true;
}
bool iDeviceTSSRequest::setGenerator(const char *generator) {
    if (!generator) {
        this->generator[0] = '\0';
        return true;
    }
    if (std::strlen(generator) != sizeof(this->generator) - 1 || generator[0] != '0' || generator[1] != 'x') {
        return false;
    }
    for (const char *ptr = generator + 2; *ptr != '\0'; ptr++) {
        if (isdigit(*ptr)) {
            continue;
        }
        if (*ptr < 'a' || *ptr > 'f') {
            return false;
        }
    }
    strcpy(this->generator, generator);
    return true;
}
void iDeviceTSSRequest::setDeviceInfo(DeviceInfo_ptr deviceInfo) {
    if (deviceInfo == nullptr) {
        throw "Device info cannot be set to null.";
    }
    this->deviceInfo = deviceInfo;
}
void iDeviceTSSRequest::setFirmwareURL(const char *firmwareURL) {
    safeFreeContainer(this->buildManifest);
    this->loadedManifestIdentifier = 0;
    delete [] this->firmwareURL;
    cStringCopier(firmwareURL, this->firmwareURL);
}
void iDeviceTSSRequest::setECID(uint64_t ecid) {
    if (ecid == 0) {
        char randomNumbers[17];
        for (int a = 0; a < sizeof(randomNumbers)/sizeof(char) - 1; a++) {
            randomNumbers[a] = '0' + arc4random_uniform(10);
        }
        randomNumbers[sizeof(randomNumbers)/sizeof(char) - 1] = '\0';
        ecid = atoll(randomNumbers);
    }
    this->ecid = ecid;
}
void iDeviceTSSRequest::setDelegate(void *userData, void (*messageCall)(void *, const char *)) const {
    this->userData->messageCall = messageCall;
    this->userData->userData = userData;
}
#pragma mark - Methods
// do NOT free returned value nor plist_t inside;
// if nullptr is returned, check error msg.
BuildIdentity *iDeviceTSSRequest::getMatchedIdentitiesFromBuildManifest(const DeviceVersion &version) const {
    if (this->deviceInfo == nullptr) {
        return nullptr;
    }
    this->connectionCanceled = 0;
    if (this->loadedManifestIdentifier == version.identifier() && this->matchedBuildIdentity) {
        info("BuildManifest has been loaded.\n");
        return this->matchedBuildIdentity;
    }
    safeFreeContainer(this->buildManifest);
    delete this->matchedBuildIdentity;
    this->matchedBuildIdentity = nullptr;
    this->loadedManifestIdentifier = 0;
    using namespace std;

    string buildManifestFilePath = this->buildManifestPathName(version);
    FILE *f = fopen(buildManifestFilePath.c_str(), "r");
    if (f) {
        // open cached buildmanifest.
        info("Found cached buildmanifest.\n");
        fseek(f, 0, SEEK_END);
        const auto size = ftell(f);
        rewind(f);
        char *const cachedBuildManifest = new char[size];
        fread(cachedBuildManifest, sizeof(char), size, f);
        fclose(f);

        plist_t manifest = nullptr;
        plist_from_xml(cachedBuildManifest, (uint32_t)size, &manifest);
        delete [] cachedBuildManifest;
        if (!manifest) {
            error("Failed to open cached buildmanifest. Continue to download a new one.\n");
        }
        else {
            this->buildManifest = new OpaqueBufferContainer(manifest, 0, OpaqueBufferContainer::BufferType::Custom_Free_Way, plist_free);
            this->loadedManifestIdentifier = version.identifier();
            BuildIdentity *identities = _getMatchedIdentitiesFromBuildManifest(this->buildManifest, this->deviceInfo);
            if (identities) {
                return (this->matchedBuildIdentity = identities);
            }
            error("Cached BuildManifest does not match with current model.\n");
            safeFreeContainer(this->buildManifest);
        }
    }
    // failed to load from disk. Download now.
    StringBufferContainer *container;
    auto downloadedBuildManifest = this->downloadXMLBuildManifest(version, &container);
    if (!downloadedBuildManifest) {
        return nullptr;
    }
    BuildIdentity *matchedBuildIdentity = _getMatchedIdentitiesFromBuildManifest(downloadedBuildManifest, this->deviceInfo);
    // do not save if device model is not correct.
    if (matchedBuildIdentity) {
        this->buildManifest = downloadedBuildManifest;
        this->loadedManifestIdentifier = version.identifier();
        this->matchedBuildIdentity = matchedBuildIdentity;
        writeStringBufferToPath(*container, buildManifestFilePath.c_str(), this->userData);
        safeFreeContainer(container);
        return matchedBuildIdentity;
    }
    writeErrorMsg("Downloaded Manifest does not match specified model.");
    safeFreeContainer(downloadedBuildManifest);
    safeFreeContainer(container);
    return nullptr;
}
iDeviceTSSRequest::TSSRequestError iDeviceTSSRequest::validateFirmwareURL(const DeviceVersion &version) const {
    this->userData->errorMessage[0] = this->userData->buffer[0] = '\0';
    if (this->deviceInfo && getMatchedIdentitiesFromBuildManifest(version) == nullptr) {
        return TSSRequestError(TSSRequestError::Unknown_Error, this->userData->errorMessage);
    }
    if (this->deviceInfo == nullptr) {
        auto buildManifest = this->downloadXMLBuildManifest(version);
        if (!buildManifest) {
            fillOptionalUnknownErrMsg(this->userData->errorMessage);
            return TSSRequestError(this->userData->errorCode == 0 ? TSSRequestError::TSSRequestErrorCode::Unknown_Error : this->userData->errorCode, this->userData->errorMessage);
        }

        plist_t buildIdentities = plist_dict_get_item(buildManifest->buffer, "BuildIdentities");
        const auto buildIdentitiesSize = plist_array_get_size(buildIdentities);
        if (buildIdentitiesSize == 0) {
            safeFreeContainer(buildManifest);
            return TSSRequestError(-125, "\"BuildIdentities\" in buildmanifest is empty.");
        }
        delete this->supportedDeviceModelList;
        this->supportedDeviceModelList = new std::vector<DeviceInfo_ptr>;
        std::unordered_set<std::string> deviceBoardCollection;
        for (int index = 0; index < buildIdentitiesSize; index++) {
            plist_t deviceClass = plist_access_path(buildIdentities, 3, index, "Info", "DeviceClass");
            char *string = nullptr;
            plist_get_string_val(deviceClass, &string);
            DeviceInfo_ptr foundDevice;
            if (string && (foundDevice = findDeviceInfoForSpecifiedConfiguration(string))) {
                if (deviceBoardCollection.emplace(string).second) {
                    this->supportedDeviceModelList->push_back(foundDevice);
                }
            }
            free(string);
        }
        this->buildManifest = buildManifest;
    }
    return TSSRequestError();
}
bool iDeviceTSSRequest::isCurrentBuildManifestSigned(const DeviceVersion &version) const throw(TSSRequestError) {
    const auto error = this->validateFirmwareURL(version);
    if (error.code != TSSRequestError::No_Error) {
        throw error;
    }
    assert(this->deviceInfo && this->buildManifest && this->matchedBuildIdentity);
    DeviceInfo_BridgedCStruct device = {
        this->deviceInfo->deviceModel,
        this->deviceInfo->deviceBoardConfiguration,
        this->getECID(),
        // provided by tss or user-specified, apnonce is requested.
        {this->apnonce ? this->apnonce->internalNonce : nullptr, this->apnonce ? this->apnonce->parsedSize : 1},
        // provided by tss or user-specified, (64-bit devices only), sepnonce is requested.
        {this->sepnonce ? this->sepnonce->internalNonce : nullptr, this->sepnonce ? this->sepnonce->parsedSize : 1},
        this->generator,
//        this->deviceInfo->basebandCertID,
//        this->deviceInfo->bbsnumSize
    };
    const int isSigned = isBuildIdentitySignedForDevice(this->matchedBuildIdentity, &device, nullptr, this->userData);
    if (isSigned < 0) {
        fillOptionalUnknownErrMsg(this->userData->errorMessage);
        throw TSSRequestError(this->userData->errorCode == 0 ? TSSRequestError::TSSRequestErrorCode::Unknown_Error : this->userData->errorCode, this->userData->errorMessage);
    }
    return isSigned;
}
StringBufferContainer iDeviceTSSRequest::getShshblobsData(const DeviceVersion &version) const {
    if (!this->deviceInfo) {
        throw "Device Info is null.";
    }
    DeviceInfo_BridgedCStruct device = {
        this->deviceInfo->deviceModel,
        this->deviceInfo->deviceBoardConfiguration,
        this->getECID(),
        // provided by tss or user-specified, apnonce is requested.
        {this->apnonce ? this->apnonce->internalNonce : nullptr, this->apnonce ? this->apnonce->parsedSize : 1},
        // provided by tss or user-specified, (64-bit devices only), sepnonce is requested.
        {this->sepnonce ? this->sepnonce->internalNonce : nullptr, this->sepnonce ? this->sepnonce->parsedSize : 1},
        this->generator,
//        this->deviceInfo->basebandCertID,
//        this->deviceInfo->bbsnumSize
    };
    TSSDataBuffer buffer;
    const BuildIdentity *identity = this->getMatchedIdentitiesFromBuildManifest(version);
    if (identity) {
        if (isBuildIdentitySignedForDevice(identity, &device, &buffer, userData) < 0) {
            error("Cannot check tss status. Abort.\n");
        }
        else {
            if (!this->apnonce) {
                this->apnonce = new Nonce(device.apnonce.buffer, device.apnonce.length);
            }
            // sepnonce is reset every time.
            if (device.sepnonce.buffer) {
                delete [] this->sepnonce;
                this->sepnonce = new Nonce(device.sepnonce.buffer, device.sepnonce.length);
            }
        }
    }
    else {
        error("Failed to retrieve BuildManifest. Abort.\n");
    }
    return StringBufferContainer(buffer.buffer, buffer.length, StringBufferContainer::BufferType::Malloced_C);
}
OpaqueBufferContainer *iDeviceTSSRequest::downloadXMLBuildManifest(const DeviceVersion &version, StringBufferContainer **xmlDataContainer) const {
    if (this->firmwareURL == nullptr) {
        throw "Firmware URL is missing. Please set firmware URL before downloading BuildManifest.";
    }
    TSSDataBuffer buffer;
    OpaqueBufferContainer *container = nullptr;
    for (int downloadingTimes = 0; downloadingTimes < 3; downloadingTimes++) {
        buffer = {0};
        info("Downloading BuildManifest from destination URL...\n");
        int result = downloadPartialzip(this->firmwareURL, buildManifestPathFromArchive(version.isOTAFirmware()), &buffer, userData);
        if (result == 0) {
            plist_t manifest = nullptr;
            plist_from_xml(buffer.buffer, (uint32_t)buffer.length, &manifest);
            if (manifest) {
                container = new OpaqueBufferContainer(manifest, 0, OpaqueBufferContainer::BufferType::Custom_Free_Way, plist_free);
                if (xmlDataContainer) {
                    *xmlDataContainer = new StringBufferContainer(buffer.buffer, buffer.length, StringBufferContainer::BufferType::Malloced_C);
                }
                else {
                    free(buffer.buffer);
                }
                info("Successfully downloaded buildmanifest.\n");
                break;
            }
            else {
                free(buffer.buffer);
                error("Failed to parse buildmanifest. Retrying to download...\n");
                continue;
            }
        }
        else if (result == -1) {
            error("Cannot download BuildManifest from specified URL.\n");
            break;
        }
        else {
            warning("Failed to download BuildManifest.\n");
            free(buffer.buffer);
            buffer.buffer = nullptr;
            if (downloadingTimes != 2) {
                info("Retrying to download...\n");
            }
        }
    }
    return container;
}
std::pair<OpaqueBufferContainer *, OpaqueBufferContainer *> iDeviceTSSRequest::getEraseUpdateBuildIdentityForCurrentModel(const DeviceVersion &version) const {
    auto buildIdentities = this->getMatchedIdentitiesFromBuildManifest(version);
    auto pair = std::pair<OpaqueBufferContainer *, OpaqueBufferContainer *>();
    if (buildIdentities) {
        pair.second = buildIdentities->updateInstall ? new OpaqueBufferContainer(plist_copy(buildIdentities->updateInstall), 0, OpaqueBufferContainer::BufferType::Custom_Free_Way, plist_free) : nullptr;
        pair.first = buildIdentities->eraseInstall ? new OpaqueBufferContainer(plist_copy(buildIdentities->eraseInstall), 0, OpaqueBufferContainer::BufferType::Custom_Free_Way, plist_free) : nullptr;
    }
    return pair;
}
bool iDeviceTSSRequest::fillDeviceVersionWithCurrentBuildManifest(DeviceVersion &version) const { 
    if (this->buildManifest == nullptr) {
        return false;
    }
    plist_t manifest = this->buildManifest->buffer;
    plist_t pbuild = plist_dict_get_item(manifest, "ProductBuildVersion");
    plist_t pvers = plist_dict_get_item(manifest, "ProductVersion");
    if (pbuild == nullptr || pvers == nullptr) {
        writeErrorMsg("Failed to populate version as essential entries in buildmanifest are missing.");
        return false;
    }
    char *buildID = nullptr, *vers = nullptr;
    plist_get_string_val(pbuild, &buildID);
    plist_get_string_val(pvers, &vers);
    if (buildID == nullptr || vers == nullptr) {
        free(buildID);
        free(vers);
        return false;
    }
    version.setBuildID(buildID);
    version.setVersion(vers);
    free(buildID);
    free(vers);
    return true;
}
bool iDeviceTSSRequest::writeBuildManifestToFile(const DeviceVersion &version, const StringBufferContainer *xmlBuildManifest) const {
    const auto path = this->buildManifestPathName(version);
    if (xmlBuildManifest == nullptr) {
        char *plist_xml = nullptr;
        uint32_t length = 0;
        plist_to_xml(this->buildManifest->buffer, &plist_xml, &length);
        if (plist_xml && length) {
            auto buildManifest = StringBufferContainer(plist_xml, length, StringBufferContainer::BufferType::Malloced_C, nullptr);
            const bool result = writeStringBufferToPath(buildManifest, path.c_str(), userData);
            buildManifest.freeBuffer();
            return result;
        }
        return false;
    }
    return writeStringBufferToPath(*xmlBuildManifest, path.c_str(), userData);
}
inline std::string iDeviceTSSRequest::buildManifestPathName(const DeviceVersion &version) const {
    using std::string;
    // deviceModel_version_buildid or deviceModel_OTAID
    const string buildManifestName = this->deviceInfo->deviceModel + string("_") + version.description();
    return temporaryDirectoryPath + buildManifestName;
}
bool iDeviceTSSRequest::cancelConnection() const {
    this->connectionCanceled = -1;
    return true;
}
