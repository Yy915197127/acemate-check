import Foundation

class ServerModeData: Codable {
    // MARK: - Properties
    static let shared = ServerModeData()
    
//    var fireSpeed: Int
//    var fireDistance: Float
    var fireInterval: Int
    
    // MARK: - Initializer
    private init(fireInterval: Int = 5) {
//        self.fireSpeed = fireSpeed
//        self.fireDistance = fireDistance
        self.fireInterval = fireInterval
    }
    
    // MARK: - Public Methods
    // 保存数据到 UserDefaults
    func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: "serverModeData")
            print("数据保存成功: \(data)")
        } catch {
            print("数据保存失败: \(error.localizedDescription)")
        }
    }
    
    // 加载数据从 UserDefaults
    func load() {
        if let data = UserDefaults.standard.data(forKey: "serverModeData") {
            do {
                let decoder = JSONDecoder()
                let loadedData = try decoder.decode(ServerModeData.self, from: data)
//                self.fireSpeed = loadedData.fireSpeed
//                self.fireDistance = loadedData.fireDistance
                self.fireInterval = loadedData.fireInterval
            } catch {
                print("数据加载失败: \(error.localizedDescription)")
            }
        } else {
            // 如果没有数据，则使用默认值
            print("没有找到保存的数据，使用默认设置")
        }
    }
}
