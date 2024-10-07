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
    var sampleRate: Float = 44100.0 // Define the sample rate
    var toneGenerator: ToneGenerator!
    var previousMagnitude: Float = 0.0 // Declare at the class level
    var gestureHistory: [String] = []
    var frequencyShiftHistory: [Float] = []
    let historyLength = 7
    let gestureHistoryMaxLength = 10
    var lastFrequencyShift: Float = 0
    var gestureConfidence: [String: Int] = ["No Gesture": 0, "Gesture Toward": 0, "Gesture Away": 0]
    let confidenceThreshold = 2 // Number of consistent detections needed to change gesture
    var lastGesture: String = "No Gesture"
    var sameDirectionCount: Int = 0
    let directionPersistenceThreshold = 3
    var gestureBuffer: [String] = []
    let gestureBufferSize = 5


    
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
    
    func movingAverage(newValue: Float) -> Float {
        frequencyShiftHistory.append(newValue)
        if frequencyShiftHistory.count > historyLength {
            frequencyShiftHistory.removeFirst()
        }
        return frequencyShiftHistory.reduce(0, +) / Float(frequencyShiftHistory.count)
    }


    func detectDopplerShift(fftData: [Float], baseFrequency: Float, sampleRate: Float, previousMagnitude: inout Float) -> String {
        let magnitudeSpectrum = fftData.map { abs($0) }

        guard let (maxIndex, maxValue) = magnitudeSpectrum.enumerated().max(by: { $0.element < $1.element }) else {
            print("fftData is empty or no max value found")
            return "No Gesture"
        }

        let fftSize = fftData.count * 2
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

        // Calculate peak magnitude in dB
        let peakMagnitudeInDB = 20 * log10(maxValue)

        // Calculate amplitude change
        let amplitudeChange = peakMagnitudeInDB - previousMagnitude
        previousMagnitude = peakMagnitudeInDB // Update for next call

        // Debug output
        print("Detected Frequency: \(detectedFrequency) Hz")
        print("Base Frequency: \(baseFrequency) Hz")
        print("Frequency Shift: \(frequencyShift) Hz")
        print("Peak Magnitude: \(peakMagnitudeInDB) dB")
        print("Amplitude Change: \(amplitudeChange) dB")

        // Adjust these thresholds based on your observations

        let frequencyThreshold: Float = 0.4
//        let amplitudeThreshold: Float = 0.2

        let frequencyShiftChange = movingAverage(newValue: frequencyShift - lastFrequencyShift)
        lastFrequencyShift = frequencyShift

        var instantGesture = "No Gesture"
        if abs(frequencyShiftChange) < frequencyThreshold {
            instantGesture = "No Gesture"
        } else if frequencyShiftChange > frequencyThreshold {
            instantGesture = "Gesture Away"
        } else if frequencyShiftChange < -frequencyThreshold {
            instantGesture = "Gesture Toward"
        }

        // Update gesture buffer
        gestureBuffer.append(instantGesture)
        if gestureBuffer.count > gestureBufferSize {
            gestureBuffer.removeFirst()
        }

        // Determine final gesture
        let gestureCount = gestureBuffer.reduce(into: [:]) { counts, gesture in
            counts[gesture, default: 0] += 1
        }
        let finalGesture = gestureCount.max(by: { $0.value < $1.value })?.key ?? "No Gesture"

        print("Instant Gesture: \(instantGesture), Final Gesture: \(finalGesture)")
        print("Frequency Shift Change: \(frequencyShiftChange)")
        print("-------------------")

        return finalGesture
    }

    func processMicrophoneBuffer(buffer: AVAudioPCMBuffer) {
        print("processMicrophoneBuffer called")
        if let channelData = buffer.floatChannelData?[0] {
            let frameLength = Int(buffer.frameLength)
            let bufferPointer = UnsafeBufferPointer(start: channelData, count: frameLength)
            let channelDataArray = Array(bufferPointer)
            let maxAmplitude = channelDataArray.max() ?? 0.0
            print("Max amplitude: \(maxAmplitude)")
        }
        
        let frameCount = min(buffer.frameLength, 8192)
        print("Buffer frame length: \(frameCount)")

        let fftMagnitudes = performFFT(on: buffer, frameCount: frameCount)
        print("FFT Magnitudes count: \(fftMagnitudes.count)")
        print("FFT max magnitude: \(fftMagnitudes.max() ?? 0)")

        if !fftMagnitudes.isEmpty {
            let gesture = detectDopplerShift(fftData: fftMagnitudes, baseFrequency: toneGenerator.frequency, sampleRate: sampleRate, previousMagnitude: &previousMagnitude)

            DispatchQueue.main.async {
                self.gestureLabel.text = "Gesture: \(gesture)"
                if let maxMagnitude = fftMagnitudes.max() {
                    let peakMagnitudeInDB = 20 * log10(maxMagnitude)
                    self.fftMagnitudeLabel.text = String(format: "Peak Magnitude: %.2f dB", peakMagnitudeInDB)
                }
            }

            print("Detected Gesture: \(gesture)")
            print("Base Frequency: \(toneGenerator.frequency)")
            print("-------------------")
        }
    }

    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setActive(true)
            sampleRate = Float(audioSession.sampleRate)
            print("Audio session is active with sample rate: \(sampleRate)")
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }

    
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


 
    func setupMicrophone() {
        let inputNode = audioEngine.inputNode
        let mainMixer = audioEngine.mainMixerNode

        // Get the input node's output format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Connect the input node to the main mixer node
        audioEngine.connect(inputNode, to: mainMixer, format: inputFormat)
        print("Input node connected to main mixer")

        // Install the tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { (buffer, time) in
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
    


    @IBAction func frequencySliderChanged(_ sender: UISlider) {
        let frequency = sender.value * 3000 + 17000 // Range: 17kHz - 20kHz
        print("Frequency changed to: \(frequency) Hz")

        toneGenerator.frequency = frequency

        toneGenerator.stopTone()

        toneGenerator.playTone(frequency: frequency)

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAudio()
    }
    
    deinit {
        print("ModuleBViewController is being deinitialized")
        stopAudio()
    }
    
    func stopAudio() {
        // Stop the audio engine
        audioEngine.stop()
        audioEngine.reset()
        
        // Stop the tone generator
        toneGenerator.stopTone()
        
        // Remove the microphone tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Deactivate the audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }


}
