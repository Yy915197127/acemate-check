import CoreBluetooth
import Foundation

 class BluetoothPlugin: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // MARK: - 单例
    /// 共享实例
      static let shared = BluetoothPlugin()
    
    // 心跳定时器
    private var heartbeatTimer: Timer?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - 扫描设备
       public func startScan() {
        print("扫描设备")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("蓝牙状态：\(centralManager.state.rawValue)")
    }

     public func stopScan() {
        centralManager.stopScan()
    }
    
    // MARK: - CBCentralManagerDelegate

     public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("蓝牙已开启，开始扫描")
//            startScan()
        } else {
            print("蓝牙状态不可用：\(central.state.rawValue)")
        }
    }

     public func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        print("发现设备：\(peripheral.name ?? "未知")")
        
        // 可加入名称过滤条件
        if peripheral.name?.contains("target") == true {
            print("发现过滤设备：\(peripheral.name ?? "未知")")
            targetPeripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

     public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("已连接设备：\(peripheral.name ?? "未知")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

     public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败：\(error?.localizedDescription ?? "未知错误")")
    }

    // MARK: - CBPeripheralDelegate

     public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

     public func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            // 假设这里是写入通道，UUID 需替换为你设备的写特征 UUID
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
                print("找到写入特征: \(characteristic.uuid)")
                
                // 启动心跳
                startHeartbeat()
            }
        }
    }

    // MARK: - 心跳包

     public func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

     public func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

     public func sendHeartbeat() {
        let data = Data([0x01, 0x00]) // 示例心跳内容，替换为你设备要求的格式
        sendData(data)
    }

    // MARK: - 发送数据

     public func sendData(_ data: Data) {
        guard let peripheral = targetPeripheral,
              let writeChar = writeCharacteristic else {
            print("未连接或未找到写特征")
            return
        }
        peripheral.writeValue(data, for: writeChar, type: .withResponse)
    }

    // MARK: - 断开连接

     public func disconnect() {
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        stopHeartbeat()
    }
}
