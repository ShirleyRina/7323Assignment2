//
//  ModuleAViewController.swift
//  7323Assignment2
//
//  Created by shirley on 9/27/24.
//
extension Int {
    func nextPowerOf2() -> Int {
        return 1 << (64 - self.leadingZeroBitCount)
    }
}
import UIKit
import UIKit
import Accelerate // 用于 FFT
import AVFoundation


class ModuleAViewController: UIViewController {
    
    // Novocaine 实例，用于处理麦克风输入
    let audioManager = Novocaine.audioManager()

    // FFT 配置
//    let fftSize: Int = 4096 // FFT 大小，必须是 2 的幂次
    var fftSize: Int = 256
    var fft: FFTHelper!
    var microphoneInputBuffer: UnsafeMutablePointer<Float>!

    @IBOutlet weak var freqLabel1: UILabel!
    
    
    @IBOutlet weak var freqLabel2: UILabel!
    
    
    
    @IBOutlet weak var vowelLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Module A"
        configureAudioSession()
        
        let session = AVAudioSession.sharedInstance()
        let bufferFrameSize = Int(session.sampleRate * session.ioBufferDuration)
        fftSize = 256 // 固定为256，因为这接近实际接收到的帧数
        print("Adjusted FFT size: \(fftSize)")
        
        // 初始化 FFT 帮助类
        fft = FFTHelper(fftSize: fftSize)
        microphoneInputBuffer = UnsafeMutablePointer<Float>.allocate(capacity: fftSize)

        // 开始处理音频输入
        startAudioProcessing()
    }

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            // 不要设置首选的IO缓冲区持续时间，让系统决定
            try session.setPreferredSampleRate(48000)
            try session.setActive(true)
            
            print("Audio session configured and activated.")
            print("Sample rate: \(session.sampleRate)")
            print("I/O buffer duration: \(session.ioBufferDuration)")
            print("Output latency: \(session.outputLatency)")
            print("Input latency: \(session.inputLatency)")
            print("Buffer frame size: \(session.sampleRate * session.ioBufferDuration)")
        } catch {
            print("Failed to configure and activate AVAudioSession: \(error)")
        }
    }

    func startAudioProcessing() {
        audioManager?.inputBlock = { [weak self] (data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) in
            guard let self = self, let data = data else {
                print("No audio data received or self is nil")
                return
            }
            
            let actualFrames = Int(numFrames)
            print("Received \(actualFrames) frames with \(numChannels) channels")
            print("Buffer size: \(actualFrames * Int(numChannels) * MemoryLayout<Float>.size) bytes")
            
            // 检查接收到的帧数是否符合预期
            if actualFrames < 1 || actualFrames > 1024 { // 假设的合理范围
                print("Warning: Unexpected number of frames received: \(actualFrames)")
                return
            }
            
            // 创建一个临时缓冲区，大小为实际接收到的帧数
            var tempBuffer = [Float](repeating: 0, count: actualFrames)
            memcpy(&tempBuffer, data, actualFrames * MemoryLayout<Float>.size)
            
            DispatchQueue.global(qos: .userInitiated).async {
                // 如果实际帧数小于FFT大小，用零填充
                if actualFrames < self.fftSize {
                    tempBuffer.append(contentsOf: [Float](repeating: 0, count: self.fftSize - actualFrames))
                }
                
                // 执行FFT
                self.fft.performFFT(&tempBuffer, numSamples: self.fftSize)
                
                let (frequency1, frequency2) = self.getTwoLoudestFrequencies()
                
                DispatchQueue.main.async {
                    self.freqLabel1.text = String(format: "Frequency 1: %.2f Hz", frequency1)
                    self.freqLabel2.text = String(format: "Frequency 2: %.2f Hz", frequency2)
                    self.detectVowel(frequency1: frequency1, frequency2: frequency2)
                }
            }
        }
        
        // 启动音频处理
        audioManager?.play()
        
        // 添加一些基本的状态检查
//        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            
//            if let isRunning = self.audioManager?.isRunning {
//                if !isRunning {
//                    print("Warning: Audio manager is not running")
//                }
//            } else {
//                print("Error: Unable to check audio manager status")
//            }
//            
//            // 检查采样率
//            if let samplingRate = self.audioManager?.samplingRate, samplingRate <= 0 {
//                print("Error: Invalid sampling rate: \(samplingRate)")
//            }
//        }
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
