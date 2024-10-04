//
//  ToneGenerator.swift
//  7323Assignment2
//
//  Created by Tong Li on 10/4/24.
//

import AVFoundation

class ToneGenerator {
    var audioEngine = AVAudioEngine()
    var tonePlayer = AVAudioPlayerNode()
    var sampleRate: Double = 44100.0
    var frequency: Float = 18000.0 // Default 18kHz tone
    
    func playTone(frequency: Float) {
        self.frequency = frequency
        let mainMixer = audioEngine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)
        let buffer = generateToneBuffer(frequency: frequency)
        
        audioEngine.attach(tonePlayer)
        audioEngine.connect(tonePlayer, to: mainMixer, format: format)
        
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        
        do {
            try audioEngine.start()
            tonePlayer.play()
        } catch {
            print("Tone could not be played.")
        }
    }
    
    func generateToneBuffer(frequency: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * 2) // 2 seconds buffer
        let buffer = AVAudioPCMBuffer(pcmFormat: tonePlayer.outputFormat(forBus: 0), frameCapacity: frameCount)!
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
        return buffer
    }
}
