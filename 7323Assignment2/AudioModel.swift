//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps: Double) {
        print("Microphone processing started with FPS: \(withFps)")
        
        if let audioManager = self.audioManager {
            audioManager.inputBlock = self.handleMicrophone
            print("Input block set for microphone")
        } else {
            print("Audio manager is nil")
        }
        
        Timer.scheduledTimer(timeInterval: 1.0 / withFps, target: self,
                             selector: #selector(self.runEveryInterval),
                             userInfo: nil,
                             repeats: true)
    }

    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager {
                print("Starting audio manager")
                manager.play()
            } else {
                print("Audio manager is nil, cannot start")
            }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    @objc private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
    print("handleMicrophone called with \(numFrames) frames and \(numChannels) channels")
        
        if let arrayData = data {
            // 打印前 10 个麦克风输入样本，确认数据被接收
            for i in 0..<min(10, Int(numFrames)) {
                print("Microphone data sample \(i): \(arrayData[i])")
            }
            
            // 将接收到的音频数据添加到 circular buffer
            self.inputBuffer?.addNewFloatData(arrayData, withNumSamples: Int64(numFrames))
        } else {
            print("No microphone data received")
        }
    }
    
    
}
