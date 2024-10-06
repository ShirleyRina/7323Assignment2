import AVFoundation

class ToneGenerator {
    var audioEngine: AVAudioEngine
    var tonePlayer: AVAudioPlayerNode
    var sampleRate: Double
    var frequency: Float = 18000.0

    init(audioEngine: AVAudioEngine, sampleRate: Double) {
        self.audioEngine = audioEngine
        self.sampleRate = sampleRate
        self.tonePlayer = AVAudioPlayerNode()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)

        // Attach and connect the tonePlayer
        audioEngine.attach(tonePlayer)
        audioEngine.connect(tonePlayer, to: mainMixer, format: outputFormat)

    }

    func playTone(frequency: Float) {
        self.frequency = frequency
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)

        // Start the audio engine if not already running
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("Audio Engine started in playTone")
            } catch {
                print("AudioEngine failed to start: \(error)")
            }
        } else {
            print("Audio Engine is already running in playTone")
        }

        let buffer = generateToneBuffer(frequency: frequency, format: outputFormat)

        // Stop the tonePlayer before scheduling a new buffer
        if tonePlayer.isPlaying {
            tonePlayer.stop()
        }

        // Schedule the buffer
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        print("Buffer scheduled")

        // Start playback
        if !tonePlayer.isPlaying {
            tonePlayer.play()
            print("Tone Player started playing")
        } else {
            print("Tone Player is already playing")
        }
    }



    func stopTone() {
        if tonePlayer.isPlaying {
            tonePlayer.stop()
        }
    }

    func generateToneBuffer(frequency: Float, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * 2) // 2 seconds buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Failed to create AVAudioPCMBuffer")
        }
        buffer.frameLength = frameCount

        guard let signal = buffer.floatChannelData?[0] else {
            fatalError("Failed to access float channel data")
        }

        let phaseStep = Float(2.0 * Double.pi * Double(frequency) / sampleRate)
        var phase: Float = 0

        for i in 0..<Int(frameCount) {
            signal[i] = sin(phase)
//            signal[i] = 0.9 * sin(phase)
            phase += phaseStep
            if phase > Float(2.0 * Double.pi) {
                phase -= Float(2.0 * Double.pi)
            }
        }

        return buffer
    }
    
    deinit {
        print("ToneGenerator is being deinitialized")
        stopTone()
    }
}

