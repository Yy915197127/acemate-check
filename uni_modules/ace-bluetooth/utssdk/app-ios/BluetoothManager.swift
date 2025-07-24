import CoreBluetooth
import DCloudUTSFoundation
import Foundation
import NetworkExtension
//import SVProgressHUD
import UIKit

/// BluetoothManager负责管理与ACEMATE设备的蓝牙连接和通信
/// 该类处理蓝牙设备的发现、连接、数据传输和心跳维护
class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - 单例
    /// 共享实例
    static let shared = BluetoothManager()

    weak var uiHandler: BluetoothManagerUIHandler?

    // 当前正在展示的“Opening Hotspot”浮层
    //    private var hotspotProgressView: HotspotProgressView?
    // MARK: - 配置信息 (可以考虑外部化配置)
    /// 目标设备名称，用于过滤扫描结果
    private let deviceName = "ACEMATE"
    /// 设备服务UUID
    let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    /// 状态特征UUID，用于接收设备数据
    let statusCharUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    /// 命令特征UUID，用于发送指令到设备
    let dataCommandCharUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    let currentVersion = "v0.2.0_install"

    /// 最大重试次数
    private let maxRetries = 5
    /// 重试间隔时间（秒）
    private let retryIntervalSeconds: TimeInterval = 5

    // MARK: - 属性
    /// 中央管理器，负责扫描和连接外设
    var centralManager: CBCentralManager!
    /// 当前连接的外设
    private var targetPeripheral: CBPeripheral?

    /// 扫描超时计时器
    var scanTimeoutTimer: Timer?
    /// 扫描超时时间（秒）
    private let scanTimeoutInterval: TimeInterval = 60.0

    /// 重连尝试次数
    private var reconnectAttempts = 0
    /// 是否由用户主动断开连接
    private var isDisconnectInitiatedByUser = false

    /// 用于存储分段传输的JSON数据的缓冲区
    var jsonDataBuffer = ""
    /// 是否正在收集JSON数据
    private var isCollectingJsonData = false

    /// 中央管理器是否准备就绪
    var isCentralManagerReady = false
    /// 是否已连接到设备
    var isConnect = false

    // MARK: - 回调闭包
    /// 发现外设时的回调
    //    var onPeripheralDiscovered: ((_ peripheral:CBPeripheral, _ rssi:NSNumber, _ localName:String) -> Void)?
    var onPeripheralDiscovered: ((_ peripheral: String) -> Void)?

    var peripheralDic: [String: CBPeripheral] = [:]

    /// 连接状态变化时的回调
    var onConnectionChange: ((ConnectionState) -> Void)?

    /// 连接状态变化时的回调
    var onConnectionChangeBack: (() -> Void)?

    /// 开始连接时的回调
    var startConnectBlock: ((CBManagerState) -> Void)?

    var versionBlock: ((String) -> Void)?

    //接收设备返回的数据回调给UTS
    var onProcessReceivedDataBlock: (([String: Any]) -> Void)?

    // 重新连接回调给UTS
    var onReconnectBlockUTS: ((NSNumber) -> Void)?

    //信号强度回调
    var connectDeviceReadRSSIBlock: ((NSNumber) -> Void)?

    /// 读取特征值完成的回调
    private var readCompletion: ((Data?, Error?) -> Void)?
    /// 写入特征值完成的回调
    private var writeCompletion: ((Error?) -> Void)?

    /// 心跳定时器
    private var heartbeatTimer: Timer?
    /// 心跳间隔时间（秒）
    private let heartbeatInterval: TimeInterval = 10.0

    // MARK: - 枚举
    /// 连接状态枚举
    enum ConnectionState {
        case connected, disconnected
        case failed(Error?)
        case timeout
    }

    /// 蓝牙状态枚举
    enum BluetoothState {
        case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn, connected,
            disconnected, scanStarted, scanStopped
    }

    /// 蓝牙错误枚举
    enum BluetoothError: Error {
        case characteristicNotFound, bluetoothUnavailable
    }

    /// 当前蓝牙状态，状态改变时会发送通知
    var bluetoothState: BluetoothState = .unknown {
        didSet {
            NotificationCenter.default.post(name: .bluetoothStateChanged, object: nil)
        }
    }

    // MARK: - 初始化
    /// 私有初始化方法，初始化中央管理器
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate
    /// 中央管理器状态更新回调
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isCentralManagerReady = true
            bluetoothState = .poweredOn
            startConnectBlock?(central.state)
        case .poweredOff:
            bluetoothState = .poweredOff
        default:
            isCentralManagerReady = false
            bluetoothState = .unknown
        }
    }

    /// 尝试连接到已保存的设备
    /// 从UserDefaults获取之前保存的设备UUID，尝试直接连接
    /// 如果找不到已保存的设备，则开始扫描新设备
    func connectToSavedPeripheral() {
        guard let savedUUIDString = UserDefaults.standard.string(forKey: "savedPeripheralUUID"),
            let savedUUID = UUID(uuidString: savedUUIDString)
        else {
            console.log("没有已保存的设备UUID")
            return
        }
        let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [savedUUID])
        if let peripheral = knownPeripherals.first {
            targetPeripheral = peripheral
            centralManager.connect(peripheral, options: nil)
        } else {
            console.log("无法找到已保存的设备，开始扫描新设备")
            startScanning()
        }
    }

    /// 开始扫描附近的蓝牙设备
    /// 设置扫描超时计时器，达到超时时间后停止扫描
    func startScanning() {
        console.log("开始扫描新设备")
        self.peripheralDic.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: scanTimeoutInterval, repeats: false
        ) { [weak self] _ in
            self?.handleScanTimeout()
        }
    }

    /// 停止扫描蓝牙设备
    func stopScanning() {
        centralManager.stopScan()
    }

    /// 用户主动断开与设备的连接
    func disconnectPeripheral() {
        if let peripheral = targetPeripheral {
            isDisconnectInitiatedByUser = true
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    /// 处理扫描超时情况
    /// 停止扫描并通知外部超时
    private func handleScanTimeout() {
        centralManager.stopScan()
        console.log("扫描超时")
        onConnectionChange?(.timeout)
    }

    /// 连接失败的回调
    func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        onConnectionChange?(.failed(error))
    }

    /// 扫描到设备的回调
    /// 根据设备名称过滤，找到目标设备后停止扫描并尝试连接
    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            localName.contains(deviceName)
        {
            // console.log("设备广播名称：\(localName)")
            //            onPeripheralDiscovered?(peripheral, RSSI, localName)

            // 检查设备名称是否已存在于列表中
            let isNameUnique = !self.peripheralDic.contains { existingPeripheral in
                return existingPeripheral.key == localName
            }

            // 只有名字不同的设备才添加到列表
            if isNameUnique {
                self.peripheralDic.updateValue(peripheral, forKey: localName)
                onPeripheralDiscovered?(localName)
            } else {
                // console.log("设备 \(localName) 已存在于列表中，跳过添加")
            }

        }

    }

    /// 连接到指定的蓝牙设备
    /// - Parameter peripheral: 要连接的外设
    func connectDevice(peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    //获取信号强度
    func connectDeviceReadRSSI(_ readRSSIBlock: @escaping ((NSNumber) -> Void)) {
        targetPeripheral?.readRSSI()
        connectDeviceReadRSSIBlock = readRSSIBlock
    }

    //连接制定名称的设备
    func connectDeviceName(_ name: String, _ connectionChangeBlock: @escaping (() -> Void)) {
        guard !peripheralDic.isEmpty else { return }
        onConnectionChangeBack = connectionChangeBlock
        targetPeripheral = peripheralDic[name]
        centralManager.connect(targetPeripheral!, options: nil)
        scanTimeoutTimer?.invalidate()  //开始心跳
        centralManager.stopScan()  //停止扫描
    }

    /// 连接成功的回调
    /// 保存设备UUID，开始发现服务，更新连接状态
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        console.log("已连接到设备：\(peripheral.name ?? "unknown")")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        onConnectionChange?(.connected)
        bluetoothState = .connected
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "savedPeripheralUUID")
        reconnectAttempts = 0
        isConnect = true
    }

    /// 断开连接的回调
    /// 更新连接状态，停止心跳定时器
    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        console.log("已断开连接: \(peripheral.name ?? "未知设备")")
        onConnectionChange?(.disconnected)
        bluetoothState = .disconnected
        isConnect = false

        onReconnectBlockUTS?(0)

        //装配测试不用发送心跳
        // // 停止心跳定时器
        // stopHeartbeatTimer()

        // 如果不是用户主动断开连接，尝试重新连接
        if !isDisconnectInitiatedByUser {
            // 检查重试次数是否小于最大重试次数
            if reconnectAttempts < maxRetries {
                reconnectAttempts += 1
                console.log("非用户主动断开，尝试重新连接，当前尝试次数: \(reconnectAttempts)/\(maxRetries)")
                onReconnectBlockUTS?(-1)

                // 延迟一段时间后尝试重新连接
                DispatchQueue.main.asyncAfter(deadline: .now() + retryIntervalSeconds) {
                    [weak self] in
                    guard let self = self else { return }

                    if let peripheral = self.targetPeripheral {
                        console.log("正在尝试重新连接到: \(peripheral.name ?? "未知设备")")
                        self.centralManager.connect(peripheral, options: nil)
                    } else if let savedUUIDString = UserDefaults.standard.string(
                        forKey: "savedPeripheralUUID"),
                        let savedUUID = UUID(uuidString: savedUUIDString)
                    {
                        // 尝试连接之前保存的设备
                        let knownPeripherals = self.centralManager.retrievePeripherals(
                            withIdentifiers: [savedUUID])
                        if let peripheral = knownPeripherals.first {
                            console.log("正在尝试重新连接到之前保存的设备: \(peripheral.name ?? "未知设备")")
                            self.targetPeripheral = peripheral
                            self.centralManager.connect(peripheral, options: nil)
                        }
                    }
                }
            } else {
                console.log("已达到最大重试次数 (\(maxRetries))，不再尝试重新连接")
                targetPeripheral = nil
                onReconnectBlockUTS?(-2)
            }
        } else {
            // 用户主动断开连接，重置标志位
            isDisconnectInitiatedByUser = false
            targetPeripheral = nil
            console.log("用户主动断开连接，不尝试重新连接")
        }

    }

    // MARK: - CBPeripheralDelegate

    //获取信号强度 targetPeripheral?.readRSSI()
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        if let error = error {
            console.log("读取RSSI出错: \(error.localizedDescription)")
            return
        }
        connectDeviceReadRSSIBlock?(RSSI)
    }

    /// 发现服务的回调
    /// 找到目标服务后，开始发现特征
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        if let targetService = services.first(where: { $0.uuid == serviceUUID }) {
            peripheral.discoverCharacteristics(
                [statusCharUUID, dataCommandCharUUID], for: targetService)
        }
    }

    /// 发现特征的回调
    /// 找到特征后，发送时间戳，订阅通知，启动心跳定时器
    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard error == nil, let characteristics = service.characteristics else { return }
        console.log("已发现特征: \(characteristics.map { $0.uuid.uuidString })")

        //测试版隐藏
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
        //            console.log("================获取版本信息===============")
        //            self.getMachineVersion()
        //        })

        if let statusCharacteristic = characteristics.first(where: { $0.uuid == statusCharUUID }) {
            peripheral.setNotifyValue(true, for: statusCharacteristic)
        }

        //装配测试不用发送心跳
        // // 启动心跳定时器
        // startHeartbeatTimer()
    }

    /// 特征通知状态更新的回调
    /// 打印通知订阅状态
    func peripheral(
        _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if characteristic.uuid == statusCharUUID {
            if let error = error {
                console.log("订阅状态特征通知失败：\(error.localizedDescription)")
            } else {
                console.log(characteristic.isNotifying ? "已订阅状态特征通知" : "已停止状态特征通知订阅")
                onConnectionChangeBack?()
                onReconnectBlockUTS?(1)
            }
        }
    }

    /// 写入特征值完成的回调
    /// 调用完成回调
    func peripheral(
        _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        writeCompletion?(error)
        writeCompletion = nil
    }

    /// 收到特征值更新的回调
    /// 处理收到的数据或调用读取完成回调
    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if characteristic.uuid == statusCharUUID {
            guard error == nil else {
                console.log("读取状态特征通知值时出错：\(error!.localizedDescription)")
                return
            }
            if let data = characteristic.value {
                // 尝试解析接收到的数据
                processReceivedData(data)
            }
        } else {
            readCompletion?(characteristic.value, error)
            readCompletion = nil
        }
    }

    /// 处理接收到的蓝牙数据，支持分段传输的JSON数据
    /// - Parameter data: 收到的原始数据
    /// 将数据添加到缓冲区，检查是否形成完整的JSON对象，然后解析
    ///
    ///
    ///
    ///

    private let packetTimeout: TimeInterval = 0.5  // 500 ms
    private var packetTimer: DispatchSourceTimer?
    private let frameTail = "+==ACE==+"

    private func processReceivedData(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        console.log("收到原始数据: \(chunk)")

        jsonDataBuffer += chunk
        resetPacketTimer()  // 每收到数据就重置超时

        // 可能�������次粘多条，循环拆
        while let range = jsonDataBuffer.range(of: frameTail) {

            // 取出 1 条完整帧（不含分隔���本��）
            let jsonText = String(jsonDataBuffer[..<range.lowerBound])

            // 从缓冲区连同分隔符一并剔除
            //            jsonDataBuffer.removeSubrange(..<range.upperBound)
            jsonDataBuffer = ""

            // 去掉可能的换行、空格
            let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
            console.log("trimmed: \(trimmed)")
            console.log("==================完整数据====================")
            // 交给原来的解析
            parseJsonData(jsonString: trimmed)
            // 继续 while，看看后面是否还粘着下一条
        }
    }
    /// 超时即丢弃残包
    private func resetPacketTimer() {
        packetTimer?.cancel()
        packetTimer = DispatchSource.makeTimerSource(queue: .main)
        packetTimer?.schedule(deadline: .now() + packetTimeout)
        packetTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.jsonDataBuffer.isEmpty == false {
                console.log("❌ 收包超时，丢弃残包")
                self.jsonDataBuffer.removeAll()
            }
            self.packetTimer?.cancel()
            self.packetTimer = nil
        }
        packetTimer?.resume()
    }

    //    private func parseSingleJsonText(_ jsonString: String) {
    //        guard
    //            let jsonData = jsonString.data(using: .utf8),
    //            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    //        else {
    //            console.log("JSON 解析失败: \(jsonString)")
    //            return
    //        }
    ////        handle(json: json)   // 这里就是你原来的 switch type 逻辑
    //        parseJsonData(jsonString: <#T##String#>)
    //    }

    //    private func processReceivedData(_ data: Data) {
    //        // 将收到的数据转换为字符串
    //        guard let receivedString = String(data: data, encoding: .utf8) else {
    //            console.log("无法将数据转换为字符串")
    //            return
    //        }
    //
    //        console.log("收到原始数据：\(receivedString)")
    //
    //        // 添加到缓冲区
    //        jsonDataBuffer += receivedString
    //
    //        console.log("缓冲区数据: \(jsonDataBuffer)")
    //        // 检查是否包含完整的JSON对象
    //        if isCompleteJsonObject(jsonDataBuffer) {
    //            // 尝试解析完整的JSON数据
    //            parseJsonData()
    //            // 清空缓冲区，准备接收下一个JSON数据
    //            jsonDataBuffer = ""
    //            console.log("数据完整，解析数据。。。")
    //        } else {
    //            // 数据不完整，继续等待更多数据
    //            console.log("数据不完整，等待更多数据...")
    //        }
    //    }

    /// 检查字符串是否是一个完整的JSON对象
    /// - Parameter jsonString: 要检查的JSON字符串
    /// - Returns: 如果是完整的JSON对象则返回true，否则返回false
    private func isCompleteJsonObject(_ jsonString: String) -> Bool {
        // 基本检查：如果不是以 { 开头，就不是一个有效的JSON对象的开始
        guard jsonString.contains("{") else { return false }

        // 尝试解析，如果能够成功解析，则说明是完整的JSON
        do {
            // 尝试解析为JSON对象
            let _ = try JSONSerialization.jsonObject(
                with: jsonString.data(using: .utf8)!, options: [])
            return true
        } catch {
            // 解析失败，可能是不完整的JSON
            return false
        }
    }

    /// 解析完整的JSON数据
    /// 根据响应类型分发到不同的处理方法
    private func parseJsonData(jsonString: String) {
        do {
            // 检查JSON数据是否包含有效的对象
            guard let jsonData = jsonString.data(using: .utf8),
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
                    as? [String: Any]
            else {
                console.log("无效的JSON数据")
                return
            }

            // 解析响应类型
            guard let type = jsonObject["type"] as? String else {
                // 尝试检查是否有rsp_train_detail格式的数据
                if jsonObject["train_detail"] as? [String: Any] != nil {
                    console.log("接收到不带type的训练详情")

                    // 不修改字段名，模型期望的是miniutes而不是minutes
                    // 构建完整的JSON对象
                    let completeJson: [String: Any] = [
                        "type": "rsp_train_detail",
                        "data": ["train_detail": jsonObject["train_detail"]!],
                    ]

                    let completeJsonData = try JSONSerialization.data(
                        withJSONObject: completeJson, options: [])

                    // 委托给TrainingRecordManager处理详细数据
                    TrainingRecordManager.shared.processTrainingDetailResponse(
                        jsonData: completeJsonData)
                    return
                }

                console.log("JSON数据缺少type字段")
                return
            }

            // 处理不同类型的响应
            switch type {
            case "rsp_heartbeat":
                if let data = jsonObject["data"] as? [String: Any],
                    let carState = data["car_state"] as? [String: Any]
                {
                    CarStatus.shared.updateStatus(from: carState)
                    console.log("接收到心跳状态: \(carState)")

                    if CarStatus.shared.isTimeset == 0 {
                        self.setTimestampData()
                    }
                    //发送通知
                    NotificationCenter.default.post(
                        name: .carStateChanged,
                        object: nil,
                        userInfo: ["carState": carState]
                    )
                }

            case "rsp_set_mode":
                if let data = jsonObject["data"] as? [String: Any] {
                    // 处理设置模式的响应
                    console.log("模式设置响应: \(data)")
                }

            case "rsp_train_data":
                if jsonObject["data"] as? [String: Any] != nil {
                    // 处理训练数据概览
                    console.log("接收到训练数据概览")

                    // 委托给TrainingRecordManager处理训练数据概览
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: jsonObject, options: [])
                    TrainingRecordManager.shared.processTrainingDataOverview(jsonData: jsonData)
                }

            case "rsp_train_detail":
                if jsonObject["data"] as? [String: Any] != nil {
                    // 处理训练详情数据
                    console.log("接收到训练详情")

                    // 委托给TrainingRecordManager处理训练详情
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: jsonObject, options: [])
                    TrainingRecordManager.shared.processTrainingDetailResponse(jsonData: jsonData)
                }

            case "versionInfo":
                if let data = jsonObject["data"] as? [String: Any] {
                    if let version = data["version"] as? String {
                        console.log("接���到版本信息, \(version)")
                        versionBlock?(version)
                        let machineVersion = versionNumber(from: version)
                        let newVersion = versionNumber(from: currentVersion)
                        if machineVersion < newVersion {
                            //临时测试
                            //                        if machineVersion <= newVersion {

                            //                            console.log("app 附带新版本，进行升级, \(OtaManager.shared.fileName)")
                            //                            sendOpenAp()

                            //                            OtaManager.shared.upload { result in
                            //                                OtaManager.shared.triggerUpdate { result in
                            //                                    console.log("升级成功")
                            //                                }
                            //                            }

                            if #available(iOS 13.0, *) {
                                DispatchQueue.main.async {
                                    // 弹出系统确认框
                                    let alert = UIAlertController(
                                        title: "New Firmware Available",
                                        message: "Upgrade now?",
                                        preferredStyle: .alert)
                                    alert.addAction(
                                        .init(title: "Cancel", style: .cancel, handler: nil))
                                    alert.addAction(
                                        .init(title: "Upgrade", style: .default) { _ in
                                            // 1) 发送打开热点命令
                                            self.sendOpenAp()

                                            // 2) 在最顶部 VC 上 show 浮层
                                            if let windowScene = UIApplication.shared
                                                .connectedScenes
                                                .first(where: {
                                                    $0.activationState == .foregroundActive
                                                }) as? UIWindowScene,
                                                let topVC = windowScene.windows
                                                    .first(where: { $0.isKeyWindow })?
                                                    .rootViewController
                                            {

                                                // 保存引用，方便后面 dismiss
                                                //                                        self.hotspotProgressView = HotspotProgressView.show(on: topVC.view)
                                            }
                                        })

                                    // 展示 Alert
                                    if let windowScene = UIApplication.shared.connectedScenes
                                        .first(where: { $0.activationState == .foregroundActive })
                                        as? UIWindowScene,
                                        let root = windowScene.windows
                                            .first(where: { $0.isKeyWindow })?.rootViewController
                                    {
                                        root.present(alert, animated: true, completion: nil)
                                    }

                                }
                            }

                        }
                    }

                }
            case "wifiHotspot":
                console.log("wifiInfo: \(jsonObject)")
                if let ssid = jsonObject["data"] as? String {

                    //                    DispatchQueue.main.async {
                    //                        self.hotspotProgressView?.dismiss()
                    //                        self.hotspotProgressView = nil
                    //                    }

                    uiHandler?.bluetoothManager(self, didReceiveWiFiHotspot: ssid)
                    //                    connectToHotspot(ssid: ssid)
                }
            case "factory_test":
                // case "factoryTestResult":
                print("工厂模式收到设备返回数据: \(jsonObject)")

                onProcessReceivedDataBlock?(jsonObject)
            default:
                console.log("未知的响应类型: \(type)")
            }
        } catch {
            TrainingRecordManager.shared.isSyncing = false
            console.log("JSON解析出错：\(error.localizedDescription)")
        }
    }

    // 提取版本号并合并成一个整数（如 0.1.4 → 00010004 → 10004）
    func versionNumber(from version: String) -> Int {
        let pattern = #"(\d+)\.(\d+)\.(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: version, range: NSRange(version.startIndex..., in: version))
        else {
            return 0
        }

        let components: [Int] = (1...3).compactMap {
            Range(match.range(at: $0), in: version).flatMap { Int(version[$0]) }
        }

        // 统一格式：主版本 * 10000 + 次版本 * 100 + 补丁版本
        return components.count == 3
            ? (components[0] * 10000 + components[1] * 100 + components[2]) : 0
    }

    func connectToHotspot(ssid: String, in parentView: UIView) {

        console.log("==============开始连接WiFi热点===================)")
        //
        //        SVProgressHUD.show(withStatus: "Connecting to \(ssid)")
        //
        //        let config = NEHotspotConfiguration(ssid: ssid)
        //        config.joinOnce = true
        //        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        //        NEHotspotConfigurationManager.shared.apply(config) { error in
        //            SVProgressHUD.dismiss()
        //            console.log("==============error===================)")
        //            if let error = error as? NSError {
        //                console.log("❌ 连接失败：\(error.localizedDescription)")
        //            }else {
        //                console.log("==================✅ 已连接到 \(ssid)=========================")
        //
        //                //先监测本地网络是否有授权
        //                LocalNetworkPermissionTrigger.shared.checkLocalNetworkAccess { Bool in
        //                    console.log("获取本地网络权限：\(Bool)")
        //
        //                    guard Bool else  {
        //                        //引导用户去设置中开启本地网络权限
        //                        LocalNetworkPermissionTrigger.shared.showPermissionAlert()
        //                        return
        //                    }
        //
        //                    // 1. 显示升级进度弹框
        //                    let progressView = UpgradeProgressView.show(on: parentView)
        //
        //                    // 2. 上传固件，关联 UI 进度
        //                    progressView.updateProgress(0, status: "正在传输升级包 0%")
        //                    OtaManager.shared.upload(progress: { prog in
        //                        let pct = Int(prog * 100)
        //                        progressView.updateProgress(Float(prog), status: "正在传输升级包 \(pct)%")
        //                    }, completion: { result in
        //                        switch result {
        //                        case .success:
        //                            console.log("上传完成，开始升级")
        //                            // 3. 切换到“正在升级”阶段，90 秒模拟进度
        //
        //                            // 真正触发升级指令
        //                            OtaManager.shared.triggerUpdate { result in
        //                                switch result {
        //                                case .success:
        //                                    console.log("升级成功，响应UI")
        //                                    progressView.startUpgrade(duration: 20)
        //                                case .failure(_):
        //                                    console.log("升级失败")
        //                                }
        //                            }
        //
        //                        case .failure(let err):
        //                            console.log("上传失败：\(err)")
        //                            DispatchQueue.main.async {
        //                                progressView.updateProgress(0, status: "上传失败")
        //                                // 1 秒后消失
        //                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        //                                    progressView.dismiss()
        //                                }
        //                            }
        //                        }
        //                    })
        //
        //                }
        //            }
        //        }
    }

    func connectToHotspot(ssid: String) {
        let configuration = NEHotspotConfiguration(ssid: ssid)
        configuration.joinOnce = false  // 设置为 true 表示连接后不保存

        NEHotspotConfigurationManager.shared.apply(configuration) { (error) in
            if let nsError = error as NSError?, nsError.domain == NEHotspotConfigurationErrorDomain
            {
                if nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    console.log("✅ 已连接到 \(ssid)")

                    //                    OtaManager.shared.upload { result in
                    //                        OtaManager.shared.triggerUpdate { result2 in
                    //
                    //                        }
                    //                    }

                } else {
                    console.log("❌ 连接失败：\(nsError.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 外部接口方法示例
    /// 根据UUID查找特征
    /// - Parameter uuid: 特征UUID
    /// - Returns: 找到的特征，如果未找到则返回nil
    private func findCharacteristic(by uuid: CBUUID) -> CBCharacteristic? {
        guard let service = targetPeripheral?.services?.first(where: { $0.uuid == serviceUUID })
        else { return nil }
        return service.characteristics?.first(where: { $0.uuid == uuid })
    }

    /// 向特征写入数据
    /// - Parameters:
    ///   - data: 要写入的数据
    ///   - uuid: 特征UUID
    ///   - completion: 完成回调，传递可能的错误
    func writeValue(data: Data, to uuid: CBUUID, completion: ((Error?) -> Void)?) {
        writeCompletion = completion
        guard let characteristic = findCharacteristic(by: uuid) else {
            completion?(BluetoothError.characteristicNotFound)
            return
        }
        targetPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }

    /// 从特征读取数据
    /// - Parameters:
    ///   - uuid: 特征UUID
    ///   - completion: 完成回调，传递读取的数据和可能的错误
    func readValue(from uuid: CBUUID, completion: ((Data?, Error?) -> Void)?) {
        readCompletion = completion
        guard let characteristic = findCharacteristic(by: uuid) else {
            completion?(nil, BluetoothError.characteristicNotFound)
            return
        }
        targetPeripheral?.readValue(for: characteristic)
    }

    // MARK: - 心跳管理
    /// 启动心跳定时器
    /// 每隔一定时间向设备发送心跳请求，保持连接活跃
    private func startHeartbeatTimer() {
        // 确保先停止已有的定时器
        stopHeartbeatTimer()

        // 创建新的定时器，每10秒触发一次
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) {
            [weak self] _ in
            self?.setMachineHeartBeat()
        }

        // 立即发送一次心跳
        setMachineHeartBeat()

        console.log("心跳定时器已启动，间隔: \(heartbeatInterval)秒")
    }

    /// 停止心跳定时器
    private func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        console.log("心跳定时器已停止")
    }

    /// 请求机器心跳
    /// 向设备发送心跳请求，维持连接状态
    func setMachineHeartBeat() {
        if TrainingRecordManager.shared.isSyncing {
            return
        }
        //        BluetoothManager.shared.jsonDataBuffer = ""
        // 向机器发送时间戳
        sendCommand(data: [
            "type": "ask_heartbeat"
        ])
        console.log("发送心跳请求")
    }

    /// 设置机器时间戳
    /// 向设备发送当前时间，同步设备时钟
    ///     ///
    func setTimestampData() {
        // 向机器发送时间戳
        let timeZoneIdentifier = TimeZone.current.identifier

        sendCommand(data: [
            "type": "set_time",
            "data": [
                "unix_timestamp": Int(Date().timeIntervalSince1970),
                "time_zone": timeZoneIdentifier,
            ],
        ])
    }

    func sendOpenAp() {
        // 向机器发送时间戳
        sendCommand(data: [
            "type": "ap"
        ])
    }

    /// 获取训练数据
    /// 请求获取当天的训练数据列表
    func getTrainingDayData() {

        let yesterday = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

        // 向机器发送当天时间戳
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        //        formatter.locale = Locale(identifier: "zh_CN") // 确保本地化
        let todayString = formatter.string(from: Date())
        //        let yesterdayString = formatter.string(from: yesterday)
        console.log("todayString: \(todayString)")
        sendCommand(data: [
            "type": "ask_train_data",
            "data": ["date_str": todayString],
        ])
    }

    /// 获取训练详细数据
    /// - Parameters:
    ///   - dateStr: 日期字符串，格式为"yyyyMMdd"
    ///   - trainId: 训练ID
    func getTrainingDayDetailData(dateStr: String, trainId: Int) {
        // 向机器发送日期和训练 ID
        sendCommand(data: [
            "type": "ask_train_detail",
            "data": ["date_str": dateStr, "train_id": trainId],
        ])
    }

    /// 设置Rally训练模式
    /// 配置设备进入Rally训练模式，并设置相关参数
    func setRallyData() {
        // 获取 RallyModeData 中的参数并发送

        let isFixedPoint = RallyModeData.shared.isFixedPoint ? 1 : 0

        // 创建一个新数组，将 fixedPoint 数组的所有元素 +1
        let fireLocList = RallyModeData.shared.fixedPoint.map { $0 + 1 }

        sendCommand(data: [
            "type": "set_mode",
            "data": [
                "mode": "rally",
                "fire_speed": RallyModeData.shared.speed,
                "ntrp_level": RallyModeData.shared.ntrpLevel,
                "fixed_point": isFixedPoint,
                "car_loc_z": RallyModeData.shared.carLoc,
                "car_loc_x": RallyModeData.shared.carLocX,
                "fire_loc_list": fireLocList,
                "spin": RallyModeData.shared.spin,  // -10 到 10
            ],
        ])
    }

    /// 设置BallMachine训练模式
    /// 配置设备进入发球机训练模式，并设置相关参数
    func setBallMachineData() {
        // 获取 ServerMode 中的参数并发送
        sendCommand(data: [
            "type": "set_mode",
            "data": [
                "mode": "ball_machine",
                "speed": BallMachineData.shared.speed,
                //                "fire_distance": BallMachineData.shared.,
                "serve_interval": BallMachineData.shared.interval,
                "ball_loc": BallMachineData.shared.ballLocation,
                "car_loc_z": RallyModeData.shared.carLoc,
                "car_loc_x": RallyModeData.shared.carLocX,
            ],
        ])
    }

    /// 设置Serve训练模式
    /// 配置设备进入Serve训���模式��并设置��关参数
    func setServeData() {
        // 获取 ServeModeData 中的参数并发送

        //        let isFixedPoint = s.shared.isFixedPoint ? 1 : 0

        // 创建一个新数组，将 fixedPoint 数组的所有元素 +1
        //        let fireLocList = RallyModeData.shared.fixedPoint.map { $0 + 1 }

        sendCommand(data: [
            "type": "set_mode",
            "data": [
                "mode": "practice_serve",
                "serve_interval": ServerModeData.shared.fireInterval,
            ],
        ])
    }

    func setControlData() {
        // 获取 ServeModeData 中的参数并发送

        //        let isFixedPoint = s.shared.isFixedPoint ? 1 : 0

        // 创建一个新数组，将 fixedPoint 数组的所有元素 +1
        //        let fireLocList = RallyModeData.shared.fixedPoint.map { $0 + 1 }

        sendCommand(data: [
            "type": "set_mode",
            "data": [
                "mode": "motion_control"
            ],
        ])

        isShot = false
    }

    /// 启动设备
    /// 发送启动命令，开始训练
    func startDevice() {
        sendCommand(data: ["type": "run_start"])
    }

    /// 停止设备
    /// 发送暂停命令，停止训练，并获取当天训练数据
    func stopDevice() {
        sendCommand(data: ["type": "run_pause"])

        // 延迟 0.5s获取训练数据
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //            self.getTrainingDayData()
        //        }
    }

    func getMachineVersion() {
        sendCommand(data: ["type": "getVersion"])
    }

    var isShot = false

    func moveDevice(dir: String) {

        if dir == "shot" {
            if !isShot {
                sendCommand(data: [
                    "type": "motion_control",
                    "data": ["shot_switch": "on"],
                ])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.sendCommand(data: [
                        "type": "motion_control",
                        "data": ["motion": dir, "shot_switch": "on"],
                    ])
                }
                isShot = true
            } else {
                self.sendCommand(data: [
                    "type": "motion_control",
                    "data": ["motion": dir, "shot_switch": "on"],
                ])
            }

        } else {

            sendCommand(data: [
                "type": "motion_control",
                "data": ["motion": dir, "shot_switch": "off"],
            ])
            isShot = false
        }
    }

    func setDeviceSpeed(speed: Int) {

        sendCommand(data: [
            "type": "motion_control",
            "data": ["speed": speed],
        ])
    }

    func setDeviceHight(height: Float) {

        sendCommand(data: [
            "type": "motion_control",
            "data": ["shot_height": height, "shot_switch": "on"],
        ])
    }

    func setDeviceDistance(distance: Int) {

        sendCommand(data: [
            "type": "motion_control",
            "data": ["shot_dis": distance, "shot_switch": "on"],
        ])
    }

    func setDeviceServeRotate(rotate: Int) {

        sendCommand(data: [
            "type": "motion_control",
            "data": ["shot_rotate": rotate, "shot_switch": "on"],
        ])
    }

    /// 处理训练记录日期列表响应
    /// - Parameter jsonData: 响应的JSON数据
    /// - Returns: 解析后的训练记录日期列表，如果解析失败则返回nil
    func handleTrainingRecordDateListResponse(jsonData: Data) -> TrainingRecordDateList? {
        do {
            let response = try JSONDecoder().decode(
                TrainingDataOverviewResponse.self, from: jsonData)
            return response.data.recordDateList
        } catch {
            console.log("解析训练日期列表失败：\(error)")
            return nil
        }
    }

    private var lastCommandSentTime: Date = .distantPast
    private let minIntervalBetweenCommands: TimeInterval = 0.2
    private var commandQueue: [[String: Any]] = []
    private var isSending: Bool = false

    // 串行队列用于处理命令发送
    private let commandSerialQueue = DispatchQueue(label: "com.acemate.commandQueue")

    func onSendCommand(data: [String: Any], dataBlock: @escaping (([String: Any]) -> Void)) {
        onProcessReceivedDataBlock = dataBlock
        commandSerialQueue.async {
            self.commandQueue.append(data)
            self.processCommandQueue()
        }
    }

    func sendCommand(data: [String: Any]) {
        commandSerialQueue.async {
            self.commandQueue.append(data)
            self.processCommandQueue()
        }
    }

    private func processCommandQueue() {

        commandSerialQueue.async {
            guard !self.commandQueue.isEmpty else { return }

            // 如果上一次发送卡死超过阈值（如 2 s），强制解锁
            if self.isSending, Date().timeIntervalSince(self.lastCommandSentTime) > 2.0 {
                self.isSending = false
            }
            guard !self.isSending else { return }

            let now = Date()
            let timeSinceLastSend = now.timeIntervalSince(self.lastCommandSentTime)

            if timeSinceLastSend >= self.minIntervalBetweenCommands {
                let dataToSend = self.commandQueue.removeFirst()
                self.isSending = true
                self.lastCommandSentTime = now

                do {
                    console.log("send_data: \(dataToSend)")
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: dataToSend, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8),
                        let finalData = (jsonString + "\r\n").data(using: .utf8)
                    {
                        //                        console.log("finalData: \(jsonString + "\r\n")")
                        self.writeValue(data: finalData, to: self.dataCommandCharUUID) { error in
                            self.commandSerialQueue.asyncAfter(
                                deadline: .now() + self.minIntervalBetweenCommands
                            ) {
                                self.isSending = false

                                if let error = error {
                                    console.log("写入命令失败: \(error.localizedDescription)")
                                } else {
                                    console.log("命令发送成功， \(jsonString)")
                                }
                                self.processCommandQueue()
                            }
                        }
                    } else {
                        self.isSending = false
                        console.log("⚠️ JSON 编码失败")
                        self.processCommandQueue()
                    }
                } catch {
                    self.isSending = false
                    console.log("JSON 序列化失败: \(error.localizedDescription)")
                }
            } else {
                let delay = self.minIntervalBetweenCommands - timeSinceLastSend
                self.commandSerialQueue.asyncAfter(deadline: .now() + delay) {
                    self.processCommandQueue()
                }
            }
        }
    }

    /// 发送命令到设备
    /// - Parameter data: 命令数据字典
    /// 将字典序列化为JSON，添加换行符后发送到设备
    //    func sendCommand(data: [String: Any]) {
    //        do {
    //            console.log("send_data: \(data)")
    //            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
    //            if let jsonString = String(data: jsonData, encoding: .utf8),
    //               let finalData = (jsonString + "\r\n").data(using: .utf8) {
    //                console.log("finalData: \(jsonString + "\r\n")")
    //                writeValue(data: finalData, to: dataCommandCharUUID) { error in
    //                    if let error = error {
    //                        console.log("写入命令失败: \(error.localizedDescription)")
    //                    } else {
    //                        console.log("命令发送成功")
    //                    }
    //                }
    //            }
    //        } catch {
    //            console.log("JSON ��列化失败: \(error.localizedDescription)")
    //        }
    //    }
}

protocol BluetoothManagerUIHandler: AnyObject {
    func bluetoothManager(_ manager: BluetoothManager, didReceiveWiFiHotspot ssid: String)
}

// MARK: - 通知扩展
extension Notification.Name {
    /// 蓝牙���态变������知
    static let bluetoothStateChanged = Notification.Name("bluetoothStateChanged")
    /// 设备状态变化通知
    static let carStateChanged = Notification.Name("carStateChanged")
    /// 新训练数据接收通知
    static let newTrainingDataReceived = Notification.Name("newTrainingDataReceived")
    /// 训练记录日期列表接收通知
    static let trainingRecordDateListReceived = Notification.Name("trainingRecordDateListReceived")
    /// 训练记录同步完成通知
    static let trainingRecordsSyncCompleted = Notification.Name("trainingRecordsSyncCompleted")
}
