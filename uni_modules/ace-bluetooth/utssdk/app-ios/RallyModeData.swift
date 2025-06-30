import Foundation

class RallyModeData: Codable {
    // MARK: - Properties
    static let shared = RallyModeData()
    
    var carLoc: Int
    var carLocX: Int
    var speed: Int
    var ntrpLevel: Int
    var isFixedPoint: Bool
    var fixedPoint: [Int]
    var spin: Int
    var carSpeed: Int
    
    // MARK: - Initializer
    private init(carLoc: Int = 1, carLocX: Int = 5, speed: Int = 3, ntrpLevel: Int = 3, isFixedPoint: Bool = false, fixedPoint: [Int] = [4], spin: Int = 0, carSpeed: Int = 3) {
        self.carLoc = carLoc
        self.speed = speed
        self.ntrpLevel = ntrpLevel
        self.isFixedPoint = isFixedPoint
        self.fixedPoint = fixedPoint
        self.carLocX = carLocX
        self.spin = spin
        self.carSpeed = carSpeed
    }
    
    // MARK: - Public Methods
    // 保存数据到 UserDefaults
    func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: "rallyModeData")
        } catch {
            print("数据保存失败: \(error.localizedDescription)")
        }
    }
    
    // 加载数据从 UserDefaults
    func load() {
        if let data = UserDefaults.standard.data(forKey: "rallyModeData") {
            do {
                let decoder = JSONDecoder()
                let loadedData = try decoder.decode(RallyModeData.self, from: data)
                self.carLoc = loadedData.carLoc
                self.carLocX = loadedData.carLocX
                self.speed = loadedData.speed
                self.ntrpLevel = loadedData.ntrpLevel
                self.isFixedPoint = loadedData.isFixedPoint
                self.fixedPoint = loadedData.fixedPoint
                self.spin = loadedData.spin
                self.carSpeed = loadedData.carSpeed
            } catch {
                print("数据加载失败: \(error.localizedDescription)")
            }
        } else {
            // 如果没有数据，则使用默认值
            print("没有找到保存的数据，使用默认设置")
        }
    }
}
