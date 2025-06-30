//
//  TrainingRecord.swift
//  Ace
//
//  Created by lemon on 3/4/25.
//

import CoreGraphics
import Foundation

/// 训练模式
enum TrainingMode: String, Codable {
    case ballMachine = "ball_machine"
    case servePractice = "practice_serve"
    case rally = "rally"
    
    var displayName: String {
        switch self {
        case .ballMachine:
            return "发球机模式"
        case .servePractice:
            return "发球练习"
        case .rally:
            return "对打模式"
        }
    }
}


// MARK: - 单次出手详情模型
//struct ShotDetail: Codable {
//    let netFail: Bool
//    let landPoint: CGPoint?
//    let speed: Double?
//    let netClearance: Double?
//    let isForehand: Bool?
//    
//    enum CodingKeys: String, CodingKey {
//        case netFail = "net_fail"
//        case landPoint = "land_point"
//        case speed
//        case netClearance = "net_clearance"
//        case isForehand = "is_forehand"
//    }
//    
//    // 将 JSON 中的数组转换为 CGPoint
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        netFail = try container.decode(Bool.self, forKey: .netFail)
//        if let points = try? container.decode([Double].self, forKey: .landPoint),
//           points.count == 2 {
//            landPoint = CGPoint(x: points[0], y: points[1])
//        } else {
//            landPoint = nil
//        }
//        speed = try? container.decode(Double.self, forKey: .speed)
//        netClearance = try? container.decode(Double.self, forKey: .netClearance)
//        isForehand = try? container.decode(Bool.self, forKey: .isForehand)
//    }
//    
//    // 将 CGPoint 转换为数组进行编码
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(netFail, forKey: .netFail)
//        if let point = landPoint {
//            try container.encode([Double(point.x), Double(point.y)], forKey: .landPoint)
//        }
//        try container.encodeIfPresent(speed, forKey: .speed)
//        try container.encodeIfPresent(netClearance, forKey: .netClearance)
//        try container.encodeIfPresent(isForehand, forKey: .isForehand)
//    }
//}

struct ShotDetail: Codable {
    let netFail: Bool
    let landPoint: CGPoint?
    let speed: Double?
    let netClearance: Double?
    
    // —————————————————————  解 码  —————————————————————
    init(from decoder: Decoder) throws {
        // 1️⃣ 先尝试旧“对象”格式，便于与老固件共存
        if let obj = try? decoder.container(keyedBy: ObjKeys.self) {
            netFail       = try obj.decode(Bool.self,    forKey: .netFail)
            if let pts    = try? obj.decode([Double].self, forKey: .landPoint),
               pts.count == 2 {
                landPoint = CGPoint(x: pts[0], y: pts[1])
            } else { landPoint = nil }
            speed         = try obj.decodeIfPresent(Double.self, forKey: .speed) ?? 0
            netClearance  = try obj.decodeIfPresent(Double.self, forKey: .netClearance) ?? 0
            return
        }
        
        // 2️⃣ 再按“紧凑数组”格式
        var arr = try decoder.unkeyedContainer()
        netFail       = try arr.decode(Bool.self)
        netClearance  = try arr.decode(Double.self)
        
        // land_point 可能是 null
        if let pts = try? arr.decode([Double].self), pts.count == 2 {
            landPoint = CGPoint(x: pts[0], y: pts[1])
        } else {
            _ = try? arr.decodeNil()                 // 兼容 null
            landPoint = nil
        }
        speed         = try arr.decode(Double.self)
    }
    
    // —————————————————————  编 码  —————————————————————
    func encode(to encoder: Encoder) throws {
        var arr = encoder.unkeyedContainer()
        try arr.encode(netFail)
        try arr.encode(netClearance)
        if let p = landPoint {
            try arr.encode([Double(p.x), Double(p.y)])
        } else {
            try arr.encodeNil()
        }
        try arr.encode(speed)
    }
    
    // ――― 旧对象键（为了兼容老数据，保留即可）
    private enum ObjKeys: String, CodingKey {
        case netFail       = "net_fail"
        case landPoint     = "land_point"
        case speed
        case netClearance  = "net_clearance"
    }
}



// MARK: - 单次训练数据模型
struct ShotData: Codable {
    var videoUrl: String?
    let trainType: TrainingMode
    let date: TimeInterval
    let minutes: Double
    let hits: Int
    let averageSpeed: Double
    let averageNetClearance: Double
    let topSpeed: Double
    let inBoundsRate: Double
    let netFailRate: Double
    let shotDetails: [ShotDetail]
    
    
    enum CodingKeys: String, CodingKey {
        case videoUrl = "video_url"
        case trainType = "train_type"
        case date
        case minutes 
        case hits
        case averageSpeed = "average_speed"
        case averageNetClearance = "average_net_clearance"
        case topSpeed = "top_speed"
        case inBoundsRate = "in_bounds_rate"
        case netFailRate = "net_fail_rate"
        case shotDetails = "shot_details"
        
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
        trainType = try container.decode(TrainingMode.self, forKey: .trainType)
        date = try container.decode(TimeInterval.self, forKey: .date)
        minutes = try container.decode(Double.self, forKey: .minutes)
        hits = try container.decode(Int.self, forKey: .hits)
        averageSpeed = try container.decode(Double.self, forKey: .averageSpeed)
        topSpeed = try container.decode(Double.self, forKey: .topSpeed)
        inBoundsRate = try container.decode(Double.self, forKey: .inBoundsRate)
        netFailRate = try container.decode(Double.self, forKey: .netFailRate)
        shotDetails = try container.decode([ShotDetail].self, forKey: .shotDetails)
        
        // 计算平均过网高度
        let validClearances = shotDetails.compactMap { $0.netClearance }
        averageNetClearance = validClearances.isEmpty ? 0 : validClearances.reduce(0, +) / Double(validClearances.count)
    }
    
    // 保存当前训练数据到指定 URL
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    // 从指定 URL 加载训练数据
    static func load(from url: URL) throws -> ShotData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ShotData.self, from: data)
    }
    
    // 格式化日期字符串
    var formattedDate: String {
        let dateObj = Date(timeIntervalSince1970: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm分"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: dateObj)
    }
}

// MARK: - 训练数据列表模型
struct TrainingDataList: Codable {
    var sessions: [ShotData] = []
    
    // 将整个列表保存到指定 URL
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    // 从指定 URL 加载列表数据
    static func load(from url: URL) throws -> TrainingDataList {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(TrainingDataList.self, from: data)
    }
    
    // 添加新的训练数据，并同时持久化整个列表
    mutating func add(shotData: ShotData, to url: URL) throws {
        sessions.append(shotData)
        try save(to: url)
    }
}

// MARK: - JSON解析工具
//extension BluetoothManager {
//    
//    /// 处理训练详情数据
//    func handleTrainingDetailResponse(jsonData: Data) -> ShotData? {
//        do {
//            let response = try JSONDecoder().decode(TrainingDetailResponse.self, from: jsonData)
//            return response.data.shotData
//        } catch {
//            print("解析训练详情失败：\(error)")
//            return nil
//        }
//    }
//}




// 获取文档目录下的文件 URL
//let fileURL = FileManager.default
//    .urls(for: .documentDirectory, in: .userDomainMask)[0]
//    .appendingPathComponent("trainingDataList.json")
//
//// 尝试加载已存在的列表；若加载失败，则创建一个空列表
//var trainingList: TrainingDataList
//do {
//    trainingList = try TrainingDataList.load(from: fileURL)
//    print("加载已有数据，当前共有 \(trainingList.sessions.count) 条训练记录")
//} catch {
//    trainingList = TrainingDataList()
//    print("没有找到已存数据，创建新的训练数据列表")
//}
//
//// 构造一条新的训练数据（此处可根据实际数据初始化）
//let newShotData = ShotData(
//    miniutes: 2.2876,
//    hits: 30,
//    averageSpeed: 10.4991,
//    averageNetClearance: 1.9519,
//    topSpeed: 13.5596,
//    inBoundsRate: 0.9333,
//    netFailRate: 0.0667,
//    shotDetails: [
//        // 示例的 shotDetail 数组，可以加入多个数据
//        ShotDetail(netFail: false,
//                   landPoint: CGPoint(x: -1.0, y: 5.0),
//                   speed: 11.0,
//                   netClearance: 2.1),
//        ShotDetail(netFail: true,
//                   landPoint: nil,
//                   speed: nil,
//                   netClearance: nil)
//    ]
//)
//
//// 添加新训练数据，并保存整个列表
//do {
//    try trainingList.add(shotData: newShotData, to: fileURL)
//    print("新训练数据已添加，当前共有 \(trainingList.sessions.count) 条训练记录")
//} catch {
//    print("添加新数据失败：\(error)")
//}



// MARK: - 示例代码：解析来自蓝牙的训练详情JSON
/*
func handleBluetoothTrainingDetail(jsonData: Data) {
    if let shotData = BluetoothManager.shared.handleTrainingDetailResponse(jsonData: jsonData) {
        // 保存到本地
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("trainingDataList.json")
        
        var trainingList: TrainingDataList
        do {
            trainingList = try TrainingDataList.load(from: fileURL)
        } catch {
            trainingList = TrainingDataList()
        }
        
        try? trainingList.add(shotData: shotData, to: fileURL)
        
        // 进一步处理，如更新UI等
        print("成功添加新训练记录：\(shotData.formattedDate)")
    }
}
*/



