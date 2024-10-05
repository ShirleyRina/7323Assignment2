//
//  ModuleAViewController.swift
//  7323Assignment2
//
//  Created by shirley on 9/27/24.
//

import UIKit
import UIKit
import Accelerate // 用于 FFT
//import Novocaine
import AVFoundation




class ModuleAViewController: UIViewController {
    
    // Novocaine 实例，用于处理麦克风输入
    let audioManager = Novocaine.audioManager()

    // FFT 配置
    let fftSize: Int = 4096 // FFT 大小，必须是 2 的幂次
    var fft: FFTHelper!
    var microphoneInputBuffer: UnsafeMutablePointer<Float>!

    @IBOutlet weak var freqLabel1: UILabel!
    
    
    @IBOutlet weak var freqLabel2: UILabel!
    
    
    
    @IBOutlet weak var vowelLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Module A"
        configureAudioSession()
        
        // 初始化 FFT 帮助类
        fft = FFTHelper(fftSize: Int(Int32(fftSize)))
        microphoneInputBuffer = UnsafeMutablePointer<Float>.allocate(capacity: fftSize)

        // 开始处理音频输入
        startAudioProcessing()
    }
    
    // 配置音频会话的函数
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            // 设置音频会话类别和选项
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            // 激活音频会话
            try session.setActive(true)
            print("Audio session configured and activated.")
        } catch {
            print("Failed to configure and activate AVAudioSession: \(error)")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 停止音频输入或其他操作，例如暂停音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    
    func startAudioProcessing() {
        // 启动麦克风输入并处理 FFT
        audioManager?.inputBlock = { (data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) in
            
            // 确保 data 不为 nil
            guard let data = data else {
                // 如果 data 是 nil，跳过这次处理
                return
            }
            
            // 执行 FFT 分析
            self.fft.performFFT(data, numSamples: Int(numFrames))
            
            // 获取两个最大频率
            let (frequency1, frequency2) = self.getTwoLoudestFrequencies()
            
            // 在主线程更新 UI
            DispatchQueue.main.async {
                if frequency1 > 0 {
                    self.freqLabel1.text = String(format: "Frequency 1: %.2f Hz", frequency1)
                }
                if frequency2 > 0 {
                    self.freqLabel2.text = String(format: "Frequency 2: %.2f Hz", frequency2)
                }
                
                // 检测元音 'oooo' 和 'ahhhh'
                self.detectVowel(frequency1: frequency1, frequency2: frequency2)
            }
        }
        
        // 启动音频管理器
        audioManager?.play()
    }


    func getTwoLoudestFrequencies() -> (Float, Float) {
        // 使用 guard let 来安全解包 audioManager
        guard let audioManager = audioManager else {
            return (0.0, 0.0)  // 如果 audioManager 为 nil，返回默认值
        }
        
        let samplingRate = audioManager.samplingRate
        let magnitudes = fft.getFFTOutput()

        var max1: Float = 0.0
        var max2: Float = 0.0
        var freq1: Double = 0.0
        var freq2: Double = 0.0

        for i in 0..<fftSize / 2 {
            if magnitudes[i] > max1 {
                max2 = max1
                freq2 = freq1
                max1 = magnitudes[i]
                freq1 = Double(i) * samplingRate / Double(fftSize)
            } else if magnitudes[i] > max2 {
                max2 = magnitudes[i]
                freq2 = Double(i) * samplingRate / Double(fftSize)
            }
        }

        return (Float(freq1), Float(freq2))
    }




    func detectVowel(frequency1: Float, frequency2: Float) {
        // 检测元音
        if abs(frequency1 - 300) < 50 && abs(frequency2 - 800) < 50 {
            vowelLabel.text = "Vowel: ooooo"
        } else if abs(frequency1 - 600) < 50 && abs(frequency2 - 1200) < 50 {
            vowelLabel.text = "Vowel: ahhhh"
        } else {
            vowelLabel.text = "Vowel: ---"
        }
    }



    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
