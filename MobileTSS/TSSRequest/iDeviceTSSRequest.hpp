//
//  iDeviceInfo.hpp
//  TssTool-test
//
//  Created by User on 7/9/18.
//  Copyright © 2018 User. All rights reserved.
//

#ifndef iDeviceInfo_hpp
#define iDeviceInfo_hpp

#include <iostream>
#include "LocalDeviceConstants.h"
#include <vector>

template <typename DataType>
struct BufferContainer {
    typedef void (*CustomFreeFunction) (void *);
    DataType *const buffer;
    const CustomFreeFunction freeFunction;
    const size_t length;
    enum BufferType {
        Malloced_C,
        Newed_Cplusplus,
        Newed_ArrayBlock_Cplusplus,
        Custom_Free_Way
    };
    const BufferType form;
    void freeBuffer() {if (this->form == Malloced_C) free(buffer); else if (this->form == Newed_ArrayBlock_Cplusplus) delete [] buffer; else if (this->form == Newed_Cplusplus) delete this->buffer; else freeFunction(this->buffer);}
    BufferContainer(DataType *const _buffer, size_t _length, BufferType _form, CustomFreeFunction _function = nullptr): buffer(_buffer), length(_length), form(_form), freeFunction(_function) {}
};
using StringBufferContainer = BufferContainer<char>;
using OpaqueBufferContainer = BufferContainer<void>;

class DeviceVersion {
    std::string version;
    std::string buildID;
    bool isOTA;
public:
    uint64_t identifier() const {return static_cast<uint64_t>(std::hash<std::string>{}(this->version + this->buildID + std::string(this->isOTA ? "true" : "false")));}
    const std::string &getVersion() const {return this->version;}
    const std::string &getBuildID() const {return this->buildID;}
    bool isOTAFirmware() const {return this->isOTA;}
    void setVersion(const std::string &version) {this->version = version;}
    void setBuildID(const std::string &buildID) {this->buildID = buildID;}
    void setOTAFirmware(bool isOTAFirmware) {this->isOTA = isOTAFirmware;}
    std::string description() const {return this->version + (this->buildID.empty() ? "" : "-") + this->buildID + (this->isOTA ? "-OTA" : "");}
    DeviceVersion(): DeviceVersion("","") {}
    DeviceVersion(const std::string &_version, const std::string &_buildID, const bool _isOTA = false) : version(_version), buildID(_buildID), isOTA(_isOTA) {}
};
struct TSSCustomUserData;
struct BuildIdentity;
struct Nonce;
class iDeviceTSSRequest {
    DeviceInfo_ptr deviceInfo;
    char *firmwareURL = nullptr;
    uint64_t ecid = 0;
    
    mutable Nonce *apnonce = nullptr, *sepnonce = nullptr;//char *sepnonce = nullptr;
    mutable OpaqueBufferContainer *buildManifest = nullptr;
    mutable BuildIdentity *matchedBuildIdentity = nullptr;
    mutable std::vector<DeviceInfo_ptr> *supportedDeviceModelList = nullptr;
    mutable struct TSSCustomUserData *userData;
    mutable uint64_t loadedManifestIdentifier = 0;

    mutable char generator[19];
    mutable TSSBoolean connectionCanceled = 0;

public:
    // set this if want to cache buildmanifests
    static std::string temporaryDirectoryPath;  // must include "/" at the end.

    // use new and run on heap.
    // ecid is required if saving shsh.
    // if ecid is not provided, a random ecid will be generated internally.
    // deviceInfo can be null.
    iDeviceTSSRequest(const char *firmwareURL, DeviceInfo_ptr deviceInfo, uint64_t ecid = 0);

    ~iDeviceTSSRequest() noexcept;

    uint64_t getECID() const {return this->ecid;}
    const char *getFirmwareURL() const {return this->firmwareURL;}
    DeviceInfo_ptr getDeviceInfo() const {return this->deviceInfo;}

    // nullable if never fetched
    const char *getApNonce() const;
    const char *getSepNonce() const;
    const char *getGenerator() const {return this->generator;}

    const std::vector<DeviceInfo_ptr> *supportedDevice() const {return this->supportedDeviceModelList;}
    bool isRequestConnectionCanceled() const {return this->connectionCanceled != 0;}
    void *delegate() const;

    // setters that do not inherently change the request.
    void setDelegate(void *userData, void (*messageCall) (void *, const char *)) const;

    // use null to reset nonce/generator.
    // deviceInfo must be determined before setting nonce.
    bool setApNonce(const char *nonce);
    bool setSepNonce(const char *nonce);

    bool setGenerator(const char *generator);

    void setDeviceInfo(DeviceInfo_ptr deviceInfo);
    void setFirmwareURL(const char *firmwareURL);
    void setECID(uint64_t ecid);

    struct TSSRequestError {
        enum TSSRequestErrorCode {
            No_Error = 0,   // never throw this code.
            Missing_BuildManifest_In_URL = -1,  // Cannot get BuildManifest from destination URL; probably firmware is not accessible if URL is valid.
            Firmware_Device_Model_Mismatch = -2,    // current device model is not compatible with set firmware URL.
//            Network_Error = -3,     // An network error has occurred during tss status querying.
            Unknown_Machine_Model = -4,
            Connection_Canceled = -99,   // user cancels the operation.
            Unknown_Error = -128     // Unused.
        };
        std::string reason;
        TSSRequestErrorCode code;
        TSSRequestError(int code = No_Error, const std::string &info = ""): reason(info), code(static_cast<TSSRequestErrorCode>(code)) {}
    };

    // client should use this method to preload BuildManifest before checking signing status to check if firmware url is usable.
    // if deviceInfo is not set, a list of supportedDevices will be available.
    TSSRequestError validateFirmwareURL(const DeviceVersion &version) const;

    // It will call validation method and get signing status.
    bool isCurrentBuildManifestSigned(const DeviceVersion &version) const throw(TSSRequestError);

    // deviceInfo must be set before save blobs.
    StringBufferContainer getShshblobsData(const DeviceVersion &version) const;
    bool fillDeviceVersionWithCurrentBuildManifest(DeviceVersion &version) const;

    // always return true.
    bool cancelConnection() const;

    bool writeBuildManifestToFile(const DeviceVersion &version, const StringBufferContainer *xmlBuildManifest = nullptr) const;
    // erase, update.
    std::pair<OpaqueBufferContainer *, OpaqueBufferContainer *> getEraseUpdateBuildIdentityForCurrentModel(const DeviceVersion &version) const;

private:
    OpaqueBufferContainer *downloadXMLBuildManifest(const DeviceVersion &version, StringBufferContainer **xmlDataContainer = nullptr) const;
    BuildIdentity *getMatchedIdentitiesFromBuildManifest(const DeviceVersion &version) const;
    inline std::string buildManifestPathName(const DeviceVersion &version) const;
};
#endif /* iDeviceInfo_hpp */
