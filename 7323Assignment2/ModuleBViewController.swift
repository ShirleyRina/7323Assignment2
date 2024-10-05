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
    
//    var audioEngine = AVAudioEngine()
//    var inputNode: AVAudioInputNode?
//    var sampleRate: Float = 44100.0 // Define the sample rate
    
    var audioEngine = AVAudioEngine()
    var sampleRate: Float = 44100.0 // Define the sample rate
    var toneGenerator: ToneGenerator!
    var previousMagnitude: Float = 0.0 // Declare at the class level

    
    @IBOutlet weak var fftMagnitudeLabel: UILabel!
    @IBOutlet weak var gestureLabel: UILabel!
    @IBOutlet weak var frequencySlider: UISlider!
    

    
//    let toneGenerator = ToneGenerator() // Tone generator instance

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        toneGenerator = ToneGenerator(audioEngine: audioEngine, sampleRate: Double(sampleRate))
        setupMicrophone()
        toneGenerator.playTone(frequency: 18000.0) // Start playing the tone

        // Test updating labels
        DispatchQueue.main.async {
            self.gestureLabel.text = "Test Gesture Label"
            self.fftMagnitudeLabel.text = "Test FFT Magnitude Label"
        }
    }


    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setActive(true)
            sampleRate = Float(audioSession.sampleRate)
            print("Audio session is active with sample rate: \(sampleRate)")
        } catch {
            print("Failed to set audio session category: \(error)")
        }
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

    func detectDopplerShift(fftData: [Float], baseFrequency: Float, sampleRate: Float, previousMagnitude: inout Float) -> String {
        let magnitudeSpectrum = fftData.map { abs($0) }

        guard let (maxIndex, maxValue) = magnitudeSpectrum.enumerated().max(by: { $0.element < $1.element }) else {
            print("fftData is empty or no max value found")
            return "No Gesture"
        }

        let fftSize = fftData.count * 2 // Because fftData is half the FFT size
        let frequencyResolution = sampleRate / Float(fftSize)
        var detectedFrequency = Float(maxIndex) * frequencyResolution

        // Peak Interpolation
        if maxIndex > 0 && maxIndex < magnitudeSpectrum.count - 1 {
            let alpha = magnitudeSpectrum[maxIndex - 1]
            let beta = magnitudeSpectrum[maxIndex]
            let gamma = magnitudeSpectrum[maxIndex + 1]

            let correction = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma)
            detectedFrequency += Float(correction) * frequencyResolution
        }

        let frequencyShift = detectedFrequency - baseFrequency
//        let frequencyShift = baseFrequency - detectedFrequency


        // Calculate peak magnitude in dB
        let peakMagnitudeInDB = 20 * log10(maxValue)

        // Calculate amplitude change
        let amplitudeChange = peakMagnitudeInDB - previousMagnitude
        previousMagnitude = peakMagnitudeInDB // Update for next call

        print("Max Value: \(maxValue)")
        print("Max Index: \(maxIndex)")
        print("Detected Frequency: \(detectedFrequency) Hz")
        print("Base Frequency: \(baseFrequency) Hz")
        print("Frequency Shift: \(frequencyShift) Hz")
        print("Peak Magnitude: \(peakMagnitudeInDB) dB")
        print("Amplitude Change: \(amplitudeChange) dB")

        let frequencyThreshold: Float = 5.0 // Adjust based on results
        let amplitudeThreshold: Float = 1.0 // Adjust based on results
//        let frequencyThreshold: Float = 0.5 // Lowered for higher sensitivity
//        let amplitudeThreshold: Float = 0.1 // Adjust based on observations


        var gesture = "No Gesture"
        if frequencyShift > frequencyThreshold && amplitudeChange > amplitudeThreshold {
            gesture = "Gesture Toward"
        } else if frequencyShift < -frequencyThreshold && amplitudeChange < -amplitudeThreshold {
            gesture = "Gesture Away"
        }


        return gesture
    }


    func setupMicrophone() {
        let inputNode = audioEngine.inputNode
        let mainMixer = audioEngine.mainMixerNode

        // Get the input node's output format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Connect the input node to the main mixer node
        audioEngine.connect(inputNode, to: mainMixer, format: inputFormat)
        print("Input node connected to main mixer")

        // Install the tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { (buffer, time) in
            self.processMicrophoneBuffer(buffer: buffer)
        }
        print("Microphone tap installed")

        // Start the audio engine after connecting all nodes
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("Audio Engine started in setupMicrophone")
            } catch {
                print("Audio Engine failed to start: \(error)")
            }
        }
    }
    

    
    func processMicrophoneBuffer(buffer: AVAudioPCMBuffer) {
        print("processMicrophoneBuffer called")
//        let frameCount = min(buffer.frameLength, 4096)
        let frameCount = min(buffer.frameLength, 8192)

        print("Buffer frame length: \(frameCount)")

        // Perform FFT on the buffer
        let fftMagnitudes = performFFT(on: buffer, frameCount: frameCount)
        print("FFT Magnitudes: \(fftMagnitudes)")

        if !fftMagnitudes.isEmpty {
            // Step 4: Analyze FFT data and calculate peak magnitude
            let peakMagnitude = fftMagnitudes.max() ?? 0
            let peakMagnitudeInDB = 20 * log10(peakMagnitude)

            // Step 3: Detect gesture based on FFT data
            let gesture = detectDopplerShift(fftData: fftMagnitudes, baseFrequency: toneGenerator.frequency, sampleRate: sampleRate, previousMagnitude: &previousMagnitude)

            // Update the UI
            DispatchQueue.main.async {
                if let gestureLabel = self.gestureLabel, let fftMagnitudeLabel = self.fftMagnitudeLabel {
                    gestureLabel.text = "Gesture: \(gesture)"
                    fftMagnitudeLabel.text = String(format: "Peak Magnitude: %.2f dB", peakMagnitudeInDB)
                } else {
                    print("Labels are nil")
                }
            }
        }
    }


    @IBAction func frequencySliderChanged(_ sender: UISlider) {
        let frequency = sender.value * 3000 + 17000 // Range: 17kHz - 20kHz


        // Stop the current tone
        toneGenerator.stopTone()

        // Play the tone with the new frequency
        toneGenerator.playTone(frequency: frequency)
    }
    
    func updateGestureLabel(fftData: [Float], baseFrequency: Float) {
//        let gesture = detectDopplerShift(fftData: fftData, baseFrequency: baseFrequency)
        let gesture = detectDopplerShift(fftData: fftData, baseFrequency: baseFrequency, sampleRate: sampleRate, previousMagnitude: &previousMagnitude)

//        gestureLabel.text = "Gesture: \(gesture)"
        // Update the gesture label on the main thread
        DispatchQueue.main.async {
            self.gestureLabel.text = "Gesture: \(gesture)"
        }

    }
    
    func performFFT(on buffer: AVAudioPCMBuffer, frameCount: AVAudioFrameCount) -> [Float] {
        // Original length of the data
        let originalLength = Int(frameCount)

        // Desired length after zero-padding (must be a power of two)
        let paddedLength = 16384 // Adjust as needed

        // Ensure that the padded length is greater than or equal to the original length
        guard paddedLength >= originalLength else {
            print("Padded length must be greater than or equal to the original length")
            return []
        }

        // Calculate log2n based on the padded length
        let log2n = vDSP_Length(log2(Float(paddedLength)))

        guard let channelData = buffer.floatChannelData?[0] else {
            print("No channel data available")
            return []
        }

        // Apply a Hann window to the original data
        var windowedData = [Float](repeating: 0.0, count: originalLength)
        var window = [Float](repeating: 0.0, count: originalLength)
        vDSP_hann_window(&window, vDSP_Length(originalLength), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData, 1, window, 1, &windowedData, 1, vDSP_Length(originalLength))

        // Zero-padding: Create a new array with the padded length
        var paddedData = [Float](repeating: 0.0, count: paddedLength)
        // Copy the windowed data into the paddedData array
        paddedData.replaceSubrange(0..<originalLength, with: windowedData)

        // Create FFT setup
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))!

        // Prepare the complex buffer
        var realp = [Float](repeating: 0.0, count: paddedLength / 2)
        var imagp = [Float](repeating: 0.0, count: paddedLength / 2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        // Convert to split complex format
        paddedData.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: paddedLength / 2) { typeConvertedTransferBuffer in
                vDSP_ctoz(typeConvertedTransferBuffer, 2, &splitComplex, 1, vDSP_Length(paddedLength / 2))
            }
        }

        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0.0, count: paddedLength / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(paddedLength / 2))

        // Normalize magnitudes
        var normalizedMagnitudes = [Float](repeating: 0.0, count: magnitudes.count)
        var scale: Float = 1.0 / Float(originalLength)
        vDSP_vsmul(magnitudes, 1, &scale, &normalizedMagnitudes, 1, vDSP_Length(magnitudes.count))

        vDSP_destroy_fftsetup(fftSetup)

        return normalizedMagnitudes
    }



}

