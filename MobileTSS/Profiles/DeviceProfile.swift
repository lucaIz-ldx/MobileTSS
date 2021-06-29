//
//  DeviceProfile.swift
//  MobileTSS
//
//  Created by User on 12/6/19.
//

struct DeviceProfile: Equatable {
    static private(set) var local = DeviceProfile(localDevice: String(cString: getLocalDeviceInfo().pointee.deviceModel), board: String(cString: getLocalDeviceInfo().pointee.deviceBoardConfiguration), ecid: TSSECID.local?.ecidString)
    
    // set nil to remove saved ecid.
    @discardableResult
    static func setlocalECID(_ ecid: String?) -> Bool {
        guard let ecid = ecid else {
            TSSECID.local = nil
            return true
        }
        guard let ecidObj = TSSECID(string: ecid) else { return false }
        
        TSSECID.local = ecidObj
        DeviceProfile.local.ecid = ecid
        return true
    }

    static func ==(lhs: DeviceProfile, rhs: DeviceProfile) -> Bool {
        return lhs.deviceModel == rhs.deviceModel &&
            lhs.deviceBoard == rhs.deviceBoard &&
            lhs.ecid == rhs.ecid
    }
    enum DeviceProfileError : Error {
        case invalidDeviceModel
        case invalidDeviceBoard
        case invalidECID
    }
    
    var deviceModel: String
    var deviceBoard: String
    private(set) var ecid: String?

    init(deviceModel: String, deviceBoard: String, ecid: String? = nil) throws {
        guard findDeviceInfoForSpecifiedModel(deviceModel) != nil else {
            throw DeviceProfileError.invalidDeviceModel
        }
        guard let deviceModelFromDatabase = findDeviceInfoForSpecifiedConfiguration(deviceBoard)?.pointee.deviceModel, String(cString: deviceModelFromDatabase) == deviceModel else {
            throw DeviceProfileError.invalidDeviceBoard
        }
        if let ecid = ecid {
            if let parsedECID = TSSECID(string: ecid) {
                self.ecid = parsedECID.ecidString
            }
            else {
                throw DeviceProfileError.invalidECID
            }
        }
        self.deviceModel = deviceModel
        self.deviceBoard = deviceBoard
    }
    init?(archivedDictionary: [String : String]) {
        guard let deviceModel = archivedDictionary[InfoKeys.DeviceModel_Key],
            let deviceBoard = archivedDictionary[InfoKeys.DeviceBoard_Key]
            else { return nil }
        try? self.init(deviceModel: deviceModel, deviceBoard: deviceBoard, ecid: archivedDictionary[InfoKeys.ECID_Key])
    }
    var archivedDictionary: [String : String] {
        var dict = [InfoKeys.DeviceBoard_Key : deviceBoard,
                    InfoKeys.DeviceModel_Key : deviceModel]
        if let ecid = ecid {
            dict[InfoKeys.ECID_Key] = ecid
        }
        return dict
    }
    var profileKey: String {
        return deviceModel + "_" + deviceBoard + "_" + (ecid ?? "nil")
    }
    
    @discardableResult
    mutating func updateECID(_ ecidString: String?) -> Bool {
        guard let ecidString = ecidString, ecidString.isEmpty == false else {
            // remove existing ecid if nil or empty string
            ecid = nil
            return true
        }
        guard let parsedECID = TSSECID(string: ecidString)?.ecidString else { return false }
        ecid = parsedECID
        return true
    }
    
    // this ensures compatibility for new devices without explicit update
    private init(localDevice model: String, board: String, ecid: String?) {
        deviceModel = model
        deviceBoard = board
        self.ecid = ecid
    }
}
fileprivate typealias InfoKeys = CustomFirmwareTableViewController.CustomRequest.ArchivableKeys
fileprivate extension InfoKeys {
    static let ECID_Key = "ECID"
}
