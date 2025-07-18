import DCloudUTSFoundation
import FMDB
import Foundation

class DeviceModel: Codable {
    var id: Int
    var aceid: String
    var name: String
    var createdAt: Int
    var createdTime: String
    var rssi: Int
    var sAndr: Bool
    var wheel: Bool
    var shot: Bool
    var feeder_rotate: Bool
    var door_latch: Bool
    var launcher_pitch: Bool
    var highG: Bool
    var HighG_remark: String
    var gyroscope: Bool
    var pressure: Bool
    var camera: Bool
    var wifi: Bool
    var wifi_name: String
    var isSucceed: Bool

    static func CreatedTime(_ createdAt: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdAt))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    func encode() -> String {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            return jsonString
        } catch {
            console.log("序列化失败: \(error.localizedDescription)")
            return ""
        }
    }

    static func decode(from jsonString: String) -> DeviceModel? {
        guard let data = jsonString.data(using: .utf8) else {
            console.log("字符串无法转为 Data")
            return nil
        }
        do {
            let decoder = JSONDecoder()
            let model = try decoder.decode(DeviceModel.self, from: data)
            return model
        } catch {
            console.log("反序列化失败: \(error.localizedDescription)")
            return nil
        }
    }

    // 构造器
    init(
        id: Int = 0,
        aceid: String = "",
        name: String = "",
        rssi: Int = 0,
        sAndr: Bool = false,
        wheel: Bool = false,
        shot: Bool = false,
        feeder_rotate: Bool = false,
        door_latch: Bool = false,
        launcher_pitch: Bool = false,
        highG: Bool = false,
        HighG_remark: String = "",
        gyroscope: Bool = false,
        pressure: Bool = false,
        camera: Bool = false,
        wifi: Bool = false,
        wifi_name: String = ""
    ) {
        self.id = id
        self.aceid = aceid
        self.name = name
        self.createdAt = Int(Date().timeIntervalSince1970)
        self.createdTime = DeviceModel.CreatedTime(self.createdAt)
        self.rssi = rssi
        self.sAndr = sAndr
        self.wheel = wheel
        self.shot = shot
        self.feeder_rotate = feeder_rotate
        self.door_latch = door_latch
        self.launcher_pitch = launcher_pitch
        self.highG = highG
        self.HighG_remark = HighG_remark
        self.gyroscope = gyroscope
        self.pressure = pressure
        self.camera = camera
        self.wifi = wifi
        self.wifi_name = wifi_name
        self.isSucceed =
            self.sAndr && self.wheel && self.shot && self.feeder_rotate && self.door_latch
            && self.launcher_pitch && self.highG && self.gyroscope && self.pressure && self.camera
            && self.wifi
    }

    // 从FMResultSet映射
    init(resultSet: FMResultSet) {
        self.id = Int(resultSet.int(forColumn: "id"))
        self.aceid = resultSet.string(forColumn: "aceid") ?? ""
        self.name = resultSet.string(forColumn: "name") ?? ""
        self.createdAt = Int(resultSet.int(forColumn: "createdAt"))
        self.createdTime = DeviceModel.CreatedTime(self.createdAt)
        self.rssi = Int(resultSet.int(forColumn: "rssi"))
        self.sAndr = resultSet.bool(forColumn: "sAndr")
        self.wheel = resultSet.bool(forColumn: "wheel")
        self.shot = resultSet.bool(forColumn: "shot")
        self.feeder_rotate = resultSet.bool(forColumn: "feeder_rotate")
        self.door_latch = resultSet.bool(forColumn: "door_latch")
        self.launcher_pitch = resultSet.bool(forColumn: "launcher_pitch")
        self.highG = resultSet.bool(forColumn: "highG")
        self.HighG_remark = resultSet.string(forColumn: "HighG_remark") ?? ""
        self.gyroscope = resultSet.bool(forColumn: "gyroscope")
        self.pressure = resultSet.bool(forColumn: "pressure")
        self.camera = resultSet.bool(forColumn: "camera")
        self.wifi = resultSet.bool(forColumn: "wifi")
        self.wifi_name = resultSet.string(forColumn: "wifi_name") ?? ""
        self.isSucceed =
            self.sAndr && self.wheel && self.shot && self.feeder_rotate && self.door_latch
            && self.launcher_pitch && self.highG && self.gyroscope && self.pressure && self.camera
            && self.wifi
    }
}
