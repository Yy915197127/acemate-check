import DCloudUTSFoundation
import FMDB
import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()

    private let databaseQueue: FMDatabaseQueue?

    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dbURL = urls[0].appendingPathComponent("ACEDB.sqlite")

        databaseQueue = FMDatabaseQueue(path: dbURL.path)

        createTableIfNeeded()

        console.log(dbURL.path)
    }

    // 创建表
    private func createTableIfNeeded() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS test_details (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                aceid TEXT,
                name TEXT,
                createdAt INTEGER,
                rssi INTEGER,
                sAndr INTEGER,
                wheel INTEGER,
                shot INTEGER,
                feeder_rotate INTEGER,
                door_latch INTEGER,
                launcher_pitch INTEGER,
                highG INTEGER,
                HighG_remark TEXT,
                gyroscope INTEGER,
                pressure INTEGER,
                camera INTEGER,
                wifi INTEGER,
                wifi_name TEXT
            );
            """

        databaseQueue?.inDatabase { db in
            if db.executeUpdate(createTableSQL, withArgumentsIn: []) {
                console.log("表创建成功或已存在")
            } else {
                console.log("表创建失败: \(db.lastErrorMessage())")
            }
        }
    }

    // UTS插入
    func UTS_insertTestDetailsDB(_ aceID: String, _ name: String, ) {
        let mo = DeviceModel(aceid: aceID, name: name)
        insertTestDetailsDB(mo)
    }

    // 插入
    func insertTestDetailsDB(_ device: DeviceModel) {
        let insertSQL = """
            INSERT INTO test_details (
                aceid, name, createdAt, rssi, sAndr, wheel, shot, feeder_rotate,
                door_latch, launcher_pitch, highG, HighG_remark,
                gyroscope, pressure, camera, wifi, wifi_name
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        databaseQueue?.inDatabase { db in
            let success = db.executeUpdate(
                insertSQL,
                withArgumentsIn: [
                    device.aceid,
                    device.name,
                    device.createdAt,
                    device.rssi,
                    device.sAndr ? 1 : 0,
                    device.wheel ? 1 : 0,
                    device.shot ? 1 : 0,
                    device.feeder_rotate ? 1 : 0,
                    device.door_latch ? 1 : 0,
                    device.launcher_pitch ? 1 : 0,
                    device.highG ? 1 : 0,
                    device.HighG_remark,
                    device.gyroscope ? 1 : 0,
                    device.pressure ? 1 : 0,
                    device.camera ? 1 : 0,
                    device.wifi ? 1 : 0,
                    device.wifi_name,
                ]
            )
            if success {
                console.log("设备插入成功")
            } else {
                console.log("设备插入失败: \(db.lastErrorMessage())")
            }
        }
    }

    // 查询所有
    func fetchAllTestDetailsDB() -> [String] {
        var test_details: [String] = []
        let querySQL = "SELECT * FROM test_details ORDER BY id DESC"

        databaseQueue?.inDatabase { db in
            if let rs = try? db.executeQuery(querySQL, values: nil) {
                while rs.next() {
                    let device = DeviceModel(resultSet: rs)
                    test_details.append(device.encode())
                }
            }
        }
        return test_details
    }

    // 分页查询
    func fetchTestDetailsPageDB(page: NSNumber, pageSize: NSNumber) -> [String] {
        var test_details: [String] = []
        let offset = (Int(truncating: page) - 1) * Int(truncating: pageSize)
        let querySQL = "SELECT * FROM test_details ORDER BY id DESC LIMIT ? OFFSET ?"

        databaseQueue?.inDatabase { db in
            if let rs = try? db.executeQuery(querySQL, values: [Int(truncating: pageSize), offset])
            {
                while rs.next() {
                    let device = DeviceModel(resultSet: rs)
                    test_details.append(device.encode())
                }
            }
        }
        return test_details
    }

    // 根据aceid全等查询
    func fetchTestDetailsDB(aceid: String) -> String? {
        var device: DeviceModel?
        let querySQL = "SELECT * FROM test_details WHERE aceid = ? LIMIT 1"

        databaseQueue?.inDatabase { db in
            if let rs = try? db.executeQuery(querySQL, values: [aceid]) {
                if rs.next() {
                    device = DeviceModel(resultSet: rs)
                }
            }
        }
        return device?.encode()
    }

    // 更新（根据aceid）
    func UTS_updateTestDetailsDB(aceid: String, deviceJson: String) {
        guard let mo = DeviceModel.decode(from: deviceJson) else { return }
        updateTestDetailsDB(aceid: aceid, device: mo)
    }

    // 更新（根据aceid）
    func updateTestDetailsDB(aceid: String, device: DeviceModel) {
        let updateSQL = """
            UPDATE test_details SET
                name = ?,
                rssi = ?,
                sAndr = ?,
                wheel = ?,
                shot = ?,
                feeder_rotate = ?,
                door_latch = ?,
                launcher_pitch = ?,
                highG = ?,
                HighG_remark = ?,
                gyroscope = ?,
                pressure = ?,
                camera = ?,
                wifi = ?, 
                wifi_name = ?
            WHERE aceid = ?;
            """

        databaseQueue?.inDatabase { db in
            let success = db.executeUpdate(
                updateSQL,
                withArgumentsIn: [
                    device.name,
                    device.rssi,
                    device.sAndr ? 1 : 0,
                    device.wheel ? 1 : 0,
                    device.shot ? 1 : 0,
                    device.feeder_rotate ? 1 : 0,
                    device.door_latch ? 1 : 0,
                    device.launcher_pitch ? 1 : 0,
                    device.highG ? 1 : 0,
                    device.HighG_remark,
                    device.gyroscope ? 1 : 0,
                    device.pressure ? 1 : 0,
                    device.camera ? 1 : 0,
                    device.wifi ? 1 : 0,
                    device.wifi_name,
                    aceid,
                ]
            )
            if success {
                console.log("设备更新成功")
            } else {
                console.log("设备更新失败: \(db.lastErrorMessage())")
            }
        }
    }

    // 删除
    func deleteTestDetailsDB(id: NSNumber) {
        let deleteSQL = "DELETE FROM test_details WHERE id = ?"
        databaseQueue?.inDatabase { db in
            if db.executeUpdate(deleteSQL, withArgumentsIn: [Int(truncating: id)]) {
                console.log("设备删除成功")
            } else {
                console.log("设备删除失败: \(db.lastErrorMessage())")
            }
        }
    }
}
