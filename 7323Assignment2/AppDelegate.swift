//
//  AppDelegate.swift
//  7323Assignment2
//
//  Created by shirley on 9/27/24.
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 音频会话配置
        configureAudioSession()
        
        return true
    }

    // 配置音频会话
    func configureAudioSession() {
        do {
            // 获取音频会话实例
            let audioSession = AVAudioSession.sharedInstance()
            
            // 设置音频会话类别和选项
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            
            // 激活音频会话
            try audioSession.setActive(true)
            
            print("Audio session successfully configured.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // 当用户丢弃场景时调用
    }
}




