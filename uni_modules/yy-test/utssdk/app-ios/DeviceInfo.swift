import UIKit

public class DeviceInfo {
    static func getInfo() -> [String: Any] {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState.rawValue

        let screen = UIScreen.main

        let locale = Locale.current

        print(UIDevice.current.name)

        return [
            "deviceName": UIDevice.current.name,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "model": UIDevice.current.model,
            "localizedModel": UIDevice.current.localizedModel,
            "uuid": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "modelIdentifier": identifier,
            "screenWidth": screen.bounds.width,
            "screenHeight": screen.bounds.height,
            "screenScale": screen.scale,
            "batteryLevel": batteryLevel,
            "batteryState": batteryState,
            "language": locale.languageCode ?? "",
            "region": locale.regionCode ?? "",
        ]
    }
}
