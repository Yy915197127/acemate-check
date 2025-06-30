//
//  MySingletonBridge.swift
//  test01
//
//  Created by yang on 2025/6/27.
//

import Foundation

@objc public class MySingletonBridge: NSObject {

    // 暴露设置属性
    @objc public func setMyValue() {
        BluetoothPlugin.shared
    }

    // 暴露方法
    @objc public func callDoSomething() {
        BluetoothPlugin.shared.startScan()
    }
}
