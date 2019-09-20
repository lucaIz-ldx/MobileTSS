//
//  GlobalKeys.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

struct JsonKeys {
    static let name_Key = "name"
    static let boardconfig_Key = "boardconfig"
    
    static let firmwares_Key = "firmwares"
    static let url_Key = "url"
    static let signed_Key = "signed"
    static let version_Key = "version"
    static let buildid_Key = "buildid"
    static let identifier_Key = "identifier"
    static let releasedate_Key = "releasedate"
    static let isOTASigned_Key = "isOTASigned"
}
struct OTAMetaDataKeys {
    static let Assets_Key = "Assets"
    static let OSVersion_Key = "OSVersion"
    static let SupportedDevices_Key = "SupportedDevices"
    static let BaseURL_Key = "__BaseURL"
    static let RelativePath_Key = "__RelativePath"
    static let AllowableOTA_Key = "AllowableOTA"
    static let Build_Key = "Build"
}
struct LocalizedString {
    // TODO: localize
    static let errorTitle = "Error"
}
struct CustomAPGenKey {
    static let APNonce_Key = "apnonce"
    static let Generator_Key = "generator"
}
struct GlobalConstants {
//    static let mainDirectory = "/private/var/mobile/Documents/\(Bundle.main.bundleIdentifier!)/"
//    static let buildManifestDirectoryPath: String = {
//        let directoryPath = mainDirectory + "BuildManifests/"
//        try! FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
//        return directoryPath
//    }()
//    static let documentsDirectoryPath: String = {
//        let directoryPath = mainDirectory + "Documents/"
//        try! FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
//        return directoryPath
//    }()
//    static let customRequestDataFilePath: String = {
//        let directoryPath = mainDirectory + "Preferences/"
//        try! FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
//        return directoryPath + "/CustomRequest.plist"
//    }()
//    static let customAPNonceGenListFilePath: String = {
//        let directoryPath = mainDirectory + "Preferences/"
//        try! FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
//        return directoryPath + "/CustomAPNoncesWithGen.plist"
//    }()

        static let buildManifestDirectoryPath: String = {
            let directoryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/BuildManifests/"
            try! FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
            return directoryPath
        }()
        static let documentsDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/"
        static let customRequestDataFilePath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/CustomRequest.plist"
        static let customAPNonceGenListFilePath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/CustomAPNoncesWithGen.plist"

    static let localProductType = String(cString: getLocalDeviceInfo().pointee.deviceModel)
    static let localDeviceBoard = String(cString: getLocalDeviceInfo().pointee.deviceBoardConfiguration)
}
