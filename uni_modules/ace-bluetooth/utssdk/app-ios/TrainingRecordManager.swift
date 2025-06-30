//
//  TrainingRecordManager.swift
//  Ace
//
//  Created by lemon on 2025/3/6.
//

import Foundation

/// 训练记录管理器 - 负责处理训练数据的解析、存储和同步
class TrainingRecordManager {
    // 单例
    static let shared = TrainingRecordManager()
    
    // 存储训练概览数据的目录
    private let recordDateListFileName = "trainingRecordDateList.json"
    
    // 是否正在同步中
    var isSyncing = false
    
    // 同步队列
    private let syncQueue = DispatchQueue(label: "com.acemate.trainingSyncQueue")
    
    // 需要同步的训练ID列表
    private var pendingSyncIds: [Int] = []
    
    // 存储当前同步的日期字符串
    private var currentDateString: String = ""
    
    private init() {}
    
    // MARK: - 数据解析和处理
    
    /// 处理训练数据概览响应
    func processTrainingDataOverview(jsonData: Data) {
        if let recordDateList = handleTrainingRecordDateListResponse(jsonData: jsonData) {
            // 保存概览数据
            self.saveRecordDateList(recordDateList)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .trainingRecordDateListReceived,
                object: nil,
                userInfo: ["recordDateList": recordDateList]
            )
            
            // 开始同步所有训练记录详情
            self.startSyncDetailRecords(for: recordDateList)
        }
    }
    
    /// 处理训练详情响应
    func processTrainingDetailResponse(jsonData: Data) {
        if let shotData = handleTrainingDetailResponse(jsonData: jsonData) {
            // 保存训练数据
            saveTrainingData(shotData)
            
            // 发送通知，以便UI可以更新
            NotificationCenter.default.post(
                name: .newTrainingDataReceived,
                object: nil,
                userInfo: ["shotData": shotData]
            )
            
            // 处理同步流程
            self.handleTrainingDetailReceived(shotData)
        }
    }
    
    /// 处理训练日期列表响应
    func handleTrainingRecordDateListResponse(jsonData: Data) -> TrainingRecordDateList? {
        do {
            let response = try JSONDecoder().decode(TrainingDataOverviewResponse.self, from: jsonData)
            return response.data.recordDateList
        } catch {
            print("解析训练日期列表失败：\(error)")
            return nil
        }
    }
    
    /// 处理训练详情响应
    func handleTrainingDetailResponse(jsonData: Data) -> ShotData? {
        do {
            let response = try JSONDecoder().decode(TrainingDetailResponse.self, from: jsonData)
            return response.data.trainDetail
        } catch {
            print("解析训练详情失败：\(error)")
            return nil
        }
    }
    
    // MARK: - 蓝牙数据请求桥接方法
    
    /// 处理训练数据响应 - 处理来自BluetoothManager的数据
    func handleTrainingDataResponse(_ data: Data, type: String) {
        switch type {
        case "rsp_train_data":
            processTrainingDataOverview(jsonData: data)
        case "rsp_train_detail":
            processTrainingDetailResponse(jsonData: data)
        default:
            print("未知的训练数据响应类型: \(type)")
        }
    }
    
    /// 请求特定日期的训练数据
    func requestTrainingData(for dateString: String? = nil) {
        // 如果没提供日期字符串，使用今天的日期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "zh_CN")
        let todayString = dateString ?? formatter.string(from: Date())
        
        BluetoothManager.shared.sendCommand(data: [
            "type": "ask_train_data",
            "data": ["date_str": todayString]
        ])
    }
    
    /// 请求特定训练的详细数据
    func requestTrainingDetailData(dateStr: String, trainId: Int) {
        BluetoothManager.shared.sendCommand(data: [
            "type": "ask_train_detail",
            "data": ["date_str": dateStr, "train_id": trainId]
        ])
    }
    
    // MARK: - 数据存储
    
    /// 保存训练数据
    func saveTrainingData(_ shotData: ShotData) {
        // 获取文档目录下的文件 URL
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("trainingDataList.json")
        
        // 尝试加载已存在的列表，若加载失败，则创建一个空列表
        var trainingList: TrainingDataList
        do {
            trainingList = try TrainingDataList.load(from: fileURL)
            print("加载已有数据，当前共有 \(trainingList.sessions.count) 条训练记录")
            
            // 检查是否已存在相同date的记录
            let existingIndex = trainingList.sessions.firstIndex { $0.date == shotData.date }
            
            if let index = existingIndex {
                // 如果存在相同date的记录，则替换它
                print("发现相同date(\(shotData.date))的记录，进行替换")
                trainingList.sessions[index] = shotData
                
                // 保存更新后的数据
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(trainingList)
                try data.write(to: fileURL)
                print("更新完成，当前共有 \(trainingList.sessions.count) 条训练记录")
            } else {
                // 不存在相同date的记录，正常添加
                try trainingList.add(shotData: shotData, to: fileURL)
                print("新训练数据已添加，当前共有 \(trainingList.sessions.count + 1) 条训练记录")
            }
        } catch {
            // 数据加载失败，创建新列表
            trainingList = TrainingDataList()
            print("没有找到已存数据，创建新的训练数据列表")
            
            // 添加并保存新的训练数据
            do {
                try trainingList.add(shotData: shotData, to: fileURL)
                print("新训练数据已添加到新列表中")
            } catch {
                print("添加新数据失败：\(error)")
            }
        }
    }
    
    /// 保存训练数据日期列表
    func saveRecordDateList(_ recordDateList: TrainingRecordDateList) {
        let fileURL = getDocumentsDirectory().appendingPathComponent(recordDateListFileName)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recordDateList)
            try data.write(to: fileURL)
            print("训练日期列表数据已保存")
        } catch {
            print("保存训练日期列表数据失败：\(error)")
        }
    }
    
    /// 加载训练数据日期列表
    func loadRecordDateList() -> TrainingRecordDateList? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(recordDateListFileName)
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(TrainingRecordDateList.self, from: data)
        } catch {
            print("加载训练日期列表数据失败：\(error)")
            return nil
        }
    }
    
    // MARK: - 同步管理
    
    /// 同步当天的所有训练记录
    func syncTodayTrainingRecords() {
        // 先请求获取当天的训练记录列表
        BluetoothManager.shared.getTrainingDayData()
    }
    
    /// 接收到训练记录列表后，开始同步详细记录
    func startSyncDetailRecords(for recordDateList: TrainingRecordDateList) {
        // 防止重复同步
        guard !isSyncing else {
            print("正在同步中，忽略此次请求")
            return
        }
        
        // 初始化同步状态
        isSyncing = true
//        BluetoothManager.shared.jsonDataBuffer = ""
        pendingSyncIds = recordDateList.trainIds
        
        // 保存当前日期字符串，用于后续请求
        self.currentDateString = recordDateList.dateString
        
        // 开始同步第一个训练记录
        syncNextTrainingRecord()
    }
    
    /// 同步下一个训练记录
    private func syncNextTrainingRecord() {
        // 在同步队列中执行
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 处理当前队列中的训练ID
            self.processNextTrainingId()
            
            
            // 检查是否还有需要同步的ID
//            if let nextId = self.pendingSyncIds.first {
//                // 从列表中移除这个ID
//                self.pendingSyncIds.removeFirst()
//                
//                // 在主线程请求详细训练数据
//                DispatchQueue.main.async {
//                    print("正在同步训练ID: \(nextId), 日期: \(self.currentDateString)")
//                    self.requestTrainingDetailData(dateStr: self.currentDateString, trainId: nextId)
//                }
//            } else {
//                // 没有更多需要同步的ID，完成同步
//                DispatchQueue.main.async {
//                    self.isSyncing = false
//                    print("所有训练记录同步完成")
//                    // 发送同步完成通知
//                    NotificationCenter.default.post(name: .trainingRecordsSyncCompleted, object: nil)
//                }
//            }
        }
    }
    
    /// 处理下一个训练ID
    private func processNextTrainingId() {
        // 检查是否还有需要同步的ID
        while !pendingSyncIds.isEmpty {
            let nextId = pendingSyncIds.first!
            pendingSyncIds.removeFirst()
            
            // 检查本地是否已存在该训练记录
            if !isTrainingRecordExist(trainId: nextId) {
                // 本地不存在，请求详细数据
                DispatchQueue.main.async {
                    print("正在同步训练ID: \(nextId), 日期: \(self.currentDateString)")
                    self.requestTrainingDetailData(dateStr: self.currentDateString, trainId: nextId)
                }
                return // 退出，等待数据回调后再处理下一个
            } else {
                print("训练ID: \(nextId) 已存在，跳过")
                // 继续检查下一个ID
            }
        }
        
        // 所有ID都已处理完毕
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSyncing = false
            print("所有训练记录同步完成")
            NotificationCenter.default.post(name: .trainingRecordsSyncCompleted, object: nil)
        }
    }
    
    
    /// 检查训练记录是否已存在
    private func isTrainingRecordExist(trainId: Int) -> Bool {
        let fileURL = getDocumentsDirectory().appendingPathComponent("trainingDataList.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false // 文件不存在，说明没有任何记录
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let trainingList = try decoder.decode(TrainingDataList.self, from: data)
            
            // 检查是否存在相同ID的记录
            // 注意：这里假设trainId可以通过日期字符串的某种转换对应到ShotData.date
            // 具体实现可能需要根据应用的数据结构调整
            return trainingList.sessions.contains { shotData in
                // 这里根据实际情况调整比较逻辑
                let idFromDate = Int(shotData.date)
                return idFromDate == trainId
            }
        } catch {
            print("检查训练记录是否存在时出错：\(error)")
            return false
        }
    }
    
    
    
    
    
    /// 收到一个训练详情记录后的处理
    func handleTrainingDetailReceived(_ shotData: ShotData) {
        // 保存或更新训练详情记录
        saveOrUpdateTrainingRecord(shotData)
        
        // 继续同步下一条记录
//        syncNextTrainingRecord()
        syncQueue.async { [weak self] in
            self?.processNextTrainingId()
        }
    }
    
    /// 保存或更新训练记录
    private func saveOrUpdateTrainingRecord(_ shotData: ShotData) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("trainingDataList.json")
        var trainingList: TrainingDataList
        
        // 尝试加载现有列表
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                trainingList = try decoder.decode(TrainingDataList.self, from: data)
                
                // 查找是否已存在相同ID的记录
                if let index = trainingList.sessions.firstIndex(where: { Int($0.date) == Int(shotData.date) }) {
                    // 存在则替换
                    trainingList.sessions[index] = shotData
                    print("更新已存在的训练记录：\(Int(shotData.date))")
                } else {
                    // 不存在则添加
                    trainingList.sessions.append(shotData)
                    print("添加新的训练记录：\(Int(shotData.date))")
                }
            } else {
                // 文件不存在，创建新列表
                trainingList = TrainingDataList(sessions: [shotData])
                print("创建新的训练数据列表并添加记录")
            }
            
            // 保存更新后的列表
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let updatedData = try encoder.encode(trainingList)
            try updatedData.write(to: fileURL)
            
            DispatchQueue.main.async {
//                self.isSyncing = false
                print("单条训练记录同步完成")
                // 发送同步完成通知
                NotificationCenter.default.post(name: .trainingRecordsSyncCompleted, object: nil)
            }
            
        } catch {
            print("保存训练记录失败：\(error)")
        }
    }
    
    /// 获取所有训练记录
    func fetchAllTrainingRecords(completion: @escaping ([ShotData]) -> Void) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("trainingDataList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let trainingList = try decoder.decode(TrainingDataList.self, from: data)
            completion(trainingList.sessions)
        } catch {
            print("加载训练记录失败：\(error)")
            completion([])
        }
    }
    
    /// 根据ID获取特定的训练记录
    func fetchTrainingRecord(withId id: TimeInterval) -> ShotData? {
        var result: ShotData? = nil
        
        let fileURL = getDocumentsDirectory().appendingPathComponent("trainingDataList.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let trainingList = try decoder.decode(TrainingDataList.self, from: data)
            result = trainingList.sessions.first { $0.date == id }
        } catch {
            print("加载训练记录失败：\(error)")
        }
        
        return result
    }
    
    /// 获取文档目录
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

/// 训练详情响应模型
struct TrainingDetailResponse: Codable {
    let type: String
    let data: TrainingDetailData
    
    struct TrainingDetailData: Codable {
        let trainDetail: ShotData
        
        enum CodingKeys: String, CodingKey {
            case trainDetail = "train_detail"
        }
    }
}

/// 训练数据概览响应模型
struct TrainingDataOverviewResponse: Codable {
    let type: String
    let data: TrainingDataOverviewData
    
    struct TrainingDataOverviewData: Codable {
        let recordDateList: TrainingRecordDateList
        
        enum CodingKeys: String, CodingKey {
            // 同时支持record_date_list和train_data两种键名
            case recordDateList = "train_data"
        }
    }
}

/// 训练记录日期列表模型
struct TrainingRecordDateList: Codable {
    let dateString: String
    let totalHits: Int?
    let totalHours: Double?
    let totalTrainTimes: Int?
    let trainIds: [Int]
    
    enum CodingKeys: String, CodingKey {
        case dateString = "date_str"
        case totalHits = "total_hits"
        case totalHours = "total_hours"
        case totalTrainTimes = "total_train_times"
        case trainIds = "train_ids"
    }
    
    /// 将日期字符串转换为可读格式
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "zh_CN")
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: date)
        }
        return dateString
    }
}


extension TrainingRecordManager {
    
    /// 删除所有本地训练记录
    func deleteAllTrainingRecords() {
        let fileManager = FileManager.default
        
        // 删除训练详情数据文件
        let trainingDataURL = getDocumentsDirectory().appendingPathComponent("trainingDataList.json")
        if fileManager.fileExists(atPath: trainingDataURL.path) {
            do {
                try fileManager.removeItem(at: trainingDataURL)
                print("✅ 已删除训练数据文件: \(trainingDataURL.lastPathComponent)")
            } catch {
                print("❌ 删除训练数据文件失败: \(error)")
            }
        } else {
            print("⚠️ 训练数据文件不存在")
        }
        
        // 删除训练记录概览日期列表文件
        let dateListURL = getDocumentsDirectory().appendingPathComponent(recordDateListFileName)
        if fileManager.fileExists(atPath: dateListURL.path) {
            do {
                try fileManager.removeItem(at: dateListURL)
                print("✅ 已删除训练日期列表文件: \(dateListURL.lastPathComponent)")
            } catch {
                print("❌ 删除训练日期列表失败: \(error)")
            }
        } else {
            print("⚠️ 训练日期列表文件不存在")
        }
        
        // 可选：通知 UI 进行刷新或清空
//        NotificationCenter.default.post(name: .trainingRecordsSyncCompleted, object: nil)
    }
}



// MARK: - 训练数据同步流程说明
/*
训练数据同步的完整流程:

1. 开始同步
   - 用户触发 TrainingRecordManager.shared.syncTodayTrainingRecords()
   - 系统使用 BluetoothManager.shared.getTrainingDayData() 发送请求获取今天的训练记录列表

2. 处理训练记录列表响应
   - BluetoothManager 接收到 "rsp_train_data" 类型的响应
   - 解析数据并调用 processTrainingDataOverview 方法
   - 保存训练记录列表到本地文件
   - 发送 .trainingRecordDateListReceived 通知
   - 调用 TrainingRecordManager.startSyncDetailRecords 开始同步详细记录

3. 同步详细训练记录
   - TrainingRecordManager 初始化同步状态并存储所有待同步的训练ID
   - 保存当前日期字符串，用于请求详细记录
   - 逐个同步训练记录:
     a. 从队列取出下一个训练ID
     b. 使用 BluetoothManager.getTrainingDayDetailData 请求详细数据
     c. 传递日期字符串和训练ID

4. 处理训练详情响应
   - BluetoothManager 接收到 "rsp_train_detail" 类型的响应
   - 解析数据并调用 saveTrainingData 保存训练详情
   - 发送 .newTrainingDataReceived 通知
   - 调用 TrainingRecordManager.handleTrainingDetailReceived 处理同步流程
   - TrainingRecordManager 更新或添加训练记录到本地数据库
   - 继续同步下一条记录

5. 完成同步
   - 所有训练ID同步完成后，发送 .trainingRecordsSyncCompleted 通知
   - UI 可以更新显示同步状态和最新数据

使用此同步机制可确保本地训练数据与设备数据保持同步，同时避免蓝牙通信冲突。
*/

/// 训练数据模型 
