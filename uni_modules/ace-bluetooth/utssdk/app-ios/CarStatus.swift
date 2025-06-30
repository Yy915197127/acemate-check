import Foundation

class CarStatus {
    static let shared = CarStatus()
    
    // 定义存储属性
    var batteryLevel: Int = 0
    var carLocStatus: Int = 0
    var carMode: String = ""
    var carTime: TimeInterval = 0
    var imuError: Int = 0
    var isRunning: Int = 0
    var tLocError: Int = 0
    var timeDriftError: Int = 0
    var ipAddr = ""
    var isTimeset = 0
    
    // 私有化初始化，确保外部无法实例化
    private init() {}
    
    // 解析 JSON 并更新状态
    func updateStatus(from json: [String: Any]) {
        print("json:")
        if let batteryLevel = json["battery_leve"] as? Int {
            self.batteryLevel = batteryLevel
        }
        if let carLocStatus = json["car_loc_status"] as? Int {
            self.carLocStatus = carLocStatus
        }
        if let carMode = json["car_mode"] as? String {
            self.carMode = carMode
        }
        if let carTime = json["car_time"] as? TimeInterval {
            self.carTime = carTime
        }
        if let imuError = json["imu_error"] as? Int {
            self.imuError = imuError
        }
        if let isRunning = json["is_running"] as? Int {
            self.isRunning = isRunning
        }
        if let tLocError = json["t_loc_error"] as? Int {
            self.tLocError = tLocError
        }
        if let timeDriftError = json["time_drift_error"] as? Int {
            self.timeDriftError = timeDriftError
        }
        if let ipAddr = json["wifi_ip_addr"] as? String {
            self.ipAddr = ipAddr
        }
        
        
        if let timeSet = json["time_is_set"] as? Int {
            self.isTimeset = timeSet
        }
    }
    
    // 获取当前状态的字典表示
    func toJSON() -> [String: Any] {
        return [
            "battery_leve": batteryLevel,
            "car_loc_status": carLocStatus,
            "car_mode": carMode,
            "car_time": carTime,
            "imu_error": imuError,
            "is_running": isRunning,
            "t_loc_error": tLocError,
            "time_drift_error": timeDriftError,
            "time_is_set": isTimeset
        ]
    }
}
