//
//  BallMachineData.swift
//  Ace
//
//  Created by lemon lee on 2025/3/15.
//

import Foundation

class BallMachineData: Codable {
    // MARK: - Properties
    static let shared = BallMachineData()
    
    var interval: Int  // 发球频率
    var speed: Int      // 发球速度
    var carLoc: Float     // 机器位置
    var ballLocation: [Int] // 发球点位
    
    // MARK: - Initializer
    private init(interval: Int = 3, speed: Int = 5, carLoc: Float = 1, ballLocation: [Int] = [15,16]) {
        self.interval = interval
        self.speed = speed
        self.carLoc = carLoc
        self.ballLocation = ballLocation
    }
    
    // MARK: - Public Methods
    // 保存数据到 UserDefaults
    func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: "ballMachineData")
        } catch {
            print("数据保存失败: \(error.localizedDescription)")
        }
    }
    
    // 加载数据从 UserDefaults
    func load() {
        if let data = UserDefaults.standard.data(forKey: "ballMachineData") {
            do {
                let decoder = JSONDecoder()
                let loadedData = try decoder.decode(BallMachineData.self, from: data)
                self.interval = loadedData.interval
                self.speed = loadedData.speed
                self.carLoc = loadedData.carLoc
                self.ballLocation = loadedData.ballLocation
            } catch {
                print("数据加载失败: \(error.localizedDescription)")
            }
        } else {
            // 如果没有数据，则使用默认值
            print("没有找到保存的数据，使用默认设置")
        }
    }
}
