//
//  ModuleAViewController.swift
//  7323Assignment2
//
//  Created by shirley on 9/27/24.
//

import UIKit
import Accelerate
import AVFoundation


class ModuleAViewController: UIViewController {
    
    // Novocaine instance used for handling microphone input
    //let audioManager = Novocaine.audioManager()

    let AUDIO_BUFFER_SIZE = 1024 * 4
    let audio = AudioModel(buffer_size: 1024 * 4)

    @IBOutlet weak var freqLabel1: UILabel!
    
    
    @IBOutlet weak var freqLabel2: UILabel!
    
    
    
    @IBOutlet weak var vowelLabel: UILabel!
    
    
    // Threshold for locking in frequencies
        let magnitudeThreshold: Float = 0.05

        override func viewDidLoad() {
            super.viewDidLoad()
            
            // Setup UI for frequency display
            //setupLabels()

            // Start microphone processing
            audio.startMicrophoneProcessing(withFps: 10)
            audio.play()
            // Start a timer to update the frequency labels
            Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(self.updateLabels), userInfo: nil, repeats: true)
        }

       
    @objc
    func updateLabels() {
        // Print FFT data
        print("FFT Data: \(self.audio.fftData)")

        // Find the two largest frequencies and update labels
        if let (freq1, freq2) = findTwoLargestFrequencies() {
            print("Found frequencies: \(freq1), \(freq2)")
            
            DispatchQueue.main.async { // Ensure UI updates on the main thread
                self.freqLabel1.text = String(format: "Freq 1: %.2f Hz", freq1)
                self.freqLabel2.text = String(format: "Freq 2: %.2f Hz", freq2)
                
                // Distinguish between 'ooooo' and 'ahhhh'
                if self.detectVowel(freq1: freq1, freq2: freq2) == "ooooo" {
                    self.vowelLabel.text = "Detected: ooooo"
                } else {
                    self.vowelLabel.text = "Detected: ahhhh"
                }
            }
        } else {
            print("No valid frequencies detected.")
        }
    }



        func findTwoLargestFrequencies() -> (Float, Float)? {
            let fftData = self.audio.fftData
            
            // Peak detection: find two largest peaks in FFT data, 50Hz apart
            let sampleRate: Float = 44100.0
            let binWidth = sampleRate / Float(AUDIO_BUFFER_SIZE)
            
            var max1: (index: Int, magnitude: Float) = (-1, 0.0)
            var max2: (index: Int, magnitude: Float) = (-1, 0.0)
            
            for i in 1..<(fftData.count / 2) {
                let magnitude = fftData[i]
                
                if magnitude > max1.magnitude {
                    max2 = max1 // Shift the first max to the second
                    max1 = (i, magnitude)
                } else if magnitude > max2.magnitude && abs(binWidth * Float(i) - binWidth * Float(max1.index)) >= 50.0 {
                    max2 = (i, magnitude)
                }
            }
            
            // Convert FFT bin indices to frequencies
            let freq1 = binWidth * Float(max1.index)
            let freq2 = binWidth * Float(max2.index)
            
            if max1.magnitude > magnitudeThreshold && max2.magnitude > magnitudeThreshold {
                return (freq1, freq2)
            }
            return nil
        }

        func detectVowel(freq1: Float, freq2: Float) -> String {
            // Simple detection based on frequency patterns
            // "ooooo" usually has lower formant frequencies than "ahhhh"
            if freq1 < 500 && freq2 < 1000 {
                return "ooooo"
            } else {
                return "ahhhh"
            }
        }
    }
