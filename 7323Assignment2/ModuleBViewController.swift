//
//  ModuleBViewController.swift
//  7323Assignment2
//
//  Created by shirley on 9/27/24.
//

import UIKit
import Accelerate
import AVFoundation

class ModuleBViewController: UIViewController {
    
    var audioEngine = AVAudioEngine()
    var inputNode: AVAudioInputNode?
    var sampleRate: Float = 44100.0 // Define the sample rate
    
    @IBOutlet weak var fftMagnitudeLabel: UILabel!
    @IBOutlet weak var gestureLabel: UILabel!
    @IBOutlet weak var frequencySlider: UISlider!
    
    let toneGenerator = ToneGenerator() // Tone generator instance

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMicrophone()
    }
    
    // 音频播放方法
    func generateAudioBuffer(frequency: Float) {
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0) // Get a valid format from the engine

        let frameCount = AVAudioFrameCount(sampleRate * 2) // 2 seconds buffer
        if let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) {
            buffer.frameLength = frameCount
            
            let signal = buffer.floatChannelData![0]
            let phaseStep = Float(2.0 * Float.pi * frequency / Float(sampleRate))
            var phase: Float = 0
            
            for i in 0..<Int(frameCount) {
                signal[i] = sin(phase)
                phase += phaseStep
                if phase > 2.0 * Float.pi {
                    phase -= 2.0 * Float.pi
                }
            }
        }
    }

    func detectDopplerShift(fftData: [Float], baseFrequency: Float) -> String {
        guard let maxValue = fftData.max(), let maxIndex = fftData.firstIndex(of: maxValue) else {
            print("fftData is empty or no max value found")
            return "No Gesture"  // 如果无法找到最大值或 fftData 为空，返回默认值
        }
        
        // 正常处理逻辑
        print("Max value: \(maxValue), Index: \(maxIndex)")
        
        // 计算检测到的频率
        let detectedFrequency = Float(maxIndex) * sampleRate / Float(fftData.count)
        
        // 计算频率偏移
        let frequencyShift = detectedFrequency - baseFrequency
        let threshold: Float = 50.0 // 设置灵敏度阈值
        
        // 判断手势
        if frequencyShift > threshold {
            return "Gesture Toward"
        } else if frequencyShift < -threshold {
            return "Gesture Away"
        } else {
            return "No Gesture"
        }
    }

    
    func setupMicrophone() {
        inputNode = audioEngine.inputNode
        let inputFormat = inputNode!.inputFormat(forBus: 0)

        inputNode!.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { (buffer, time) in
            self.processMicrophoneBuffer(buffer: buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine failed to start")
        }
    }
    
    func processMicrophoneBuffer(buffer: AVAudioPCMBuffer) {
        // Step 1: Perform FFT on the microphone buffer
        let fftMagnitudes = performFFT(on: buffer)
        print("FFT Magnitudes: \(fftMagnitudes)")
        
        if !fftMagnitudes.isEmpty {
            // 如果有数据，继续处理
            let gesture = detectDopplerShift(fftData: fftMagnitudes, baseFrequency: toneGenerator.frequency)
            DispatchQueue.main.async {
                self.gestureLabel.text = "Gesture: \(gesture)"
            }
        } else {
            print("No FFT data")
        }
        
        // Step 2: Analyze FFT data and zoom into the peak magnitude
        let peakMagnitude = fftMagnitudes.max() ?? 0
        
        // Convert magnitude to decibels (optional step depending on your needs)
        let peakMagnitudeInDB = 20 * log10(peakMagnitude)
        
        // Step 3: Update the UI (e.g., displaying FFT peak)
        DispatchQueue.main.async {
            self.fftMagnitudeLabel.text = String(format: "Peak Magnitude: %.2f dB", peakMagnitudeInDB)
        }
        
        // Step 4: Detect Doppler shifts based on FFT data
        let gesture = detectDopplerShift(fftData: fftMagnitudes, baseFrequency: toneGenerator.frequency)
        
        // Update the gesture label on the main thread
        DispatchQueue.main.async {
            self.gestureLabel.text = "Gesture: \(gesture)"
        }
    }

    @IBAction func frequencySliderChanged(_ sender: UISlider) {
        let frequency = sender.value * 3000 + 17000 // Frequency range: 17kHz - 20kHz
        toneGenerator.playTone(frequency: frequency)
        generateAudioBuffer(frequency: frequency) // 每次频率变化时调用生成缓冲
    }
    
    func updateGestureLabel(fftData: [Float], baseFrequency: Float) {
        let gesture = detectDopplerShift(fftData: fftData, baseFrequency: baseFrequency)
        gestureLabel.text = "Gesture: \(gesture)"
    }
    
    func performFFT(on buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = buffer.frameLength
        let log2n = vDSP_Length(log2(Float(frameCount)))
        
        // 检查 buffer 是否有音频数据
        guard let channelData = buffer.floatChannelData?[0] else {
            print("No channel data available")
            return []
        }

        // 打印音频数据用于调试
        for i in 0..<Int(buffer.frameLength) {
            if channelData[i].isNaN || channelData[i].isInfinite {
                print("Invalid audio data at index \(i): \(channelData[i])")
            }
        }

        
        // Allocate memory for realp and imagp
        let realp = UnsafeMutablePointer<Float>.allocate(capacity: Int(frameCount / 2))
        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: Int(frameCount / 2))
        
        // Initialize DSPSplitComplex
        var splitComplex = DSPSplitComplex(realp: realp, imagp: imagp)
        
        // Create FFT setup
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        

        // Convert the input to a complex buffer (DSPSplitComplex)
        buffer.floatChannelData!.withMemoryRebound(to: DSPComplex.self, capacity: Int(frameCount)) { ptr in
            vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(frameCount / 2))
        }
        if buffer.frameLength > 0 {
            print("Buffer frame length: \(buffer.frameLength)")
        }

        
        // Perform FFT
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0.0, count: Int(frameCount / 2))
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))

        // 检查是否有 NaN 值
        for i in 0..<magnitudes.count {
            if magnitudes[i].isNaN || magnitudes[i].isInfinite {
                print("Invalid magnitude at index \(i): \(magnitudes[i])")
            }
        }

        do {
            try audioEngine.start()
            print("Audio engine started successfully")
        } catch {
            print("Error starting audio engine: \(error)")
        }

        
        // Free the allocated memory for realp and imagp
        realp.deallocate()
        imagp.deallocate()
        
        // Clean up FFT setup
        vDSP_destroy_fftsetup(fftSetup)
        print("Magnitudes: \(magnitudes)")
        return magnitudes
    }
}

