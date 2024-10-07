//
//  AppDelegate.swift
//  7323Assignment2
//  team3AssignmentTwo
//  Team members: Shuangling Zhao, Tong Li, Ping He
//  Created by shirley on 9/27/24.
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Audio session configuration
        configureAudioSession()
        
        return true
    }

    // Configure the audio session
    func configureAudioSession() {
        do {
            // Get the instance of the audio session
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set the audio session category and options
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Activate the audio session
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
        // Called when the user discards a scene
    }
}
