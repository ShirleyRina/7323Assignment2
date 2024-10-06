//
//  FFTHelper.swift
//  7323Assignment2
//
//  Created by shirley on 10/4/24.
//

import Foundation
import Accelerate

class FFTHelper {

    private var fftSetup: FFTSetup
    private var log2n: vDSP_Length
    private var n: Int
    private var nOver2: Int
    private var window: [Float]
    private var windowSize: Int
    private var windowStride: vDSP_Stride
    private var realp: [Float]
    private var imagp: [Float]
    
    private var splitComplex: DSPSplitComplex

    // 初始化 FFT 设置

    init(fftSize: Int) {
        self.n = fftSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.nOver2 = fftSize / 2
        
        // FFT setup
        self.fftSetup = vDSP_create_fftsetup(self.log2n, FFTRadix(kFFTRadix2))!
        
        // 窗口大小
        self.windowSize = fftSize
        self.windowStride = 1
        
        // 创建窗口函数（Hanning 窗口）
        self.window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // 初始化实部和虚部
        self.realp = [Float](repeating: 0.0, count: nOver2)
        self.imagp = [Float](repeating: 0.0, count: nOver2)
        
        // 初始化复数结构
        self.splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
    }

    func performFFT(_ inputBuffer: UnsafeMutablePointer<Float>, numSamples: Int) {
        let actualSamples = min(numSamples, windowSize)
        var windowedInput = [Float](repeating: 0.0, count: windowSize)
        
        // 只处理实际的样本数
        vDSP_vmul(inputBuffer, 1, window, 1, &windowedInput, 1, vDSP_Length(actualSamples))
        
        // 将剩余的样本填充为 0
        if actualSamples < windowSize {
            windowedInput[actualSamples..<windowSize].withUnsafeMutableBufferPointer { buffer in
                buffer.baseAddress?.initialize(repeating: 0, count: windowSize - actualSamples)
            }
        }

        // 将实部复制到复数结构中，虚部保持为 0
        windowedInput.withUnsafeBufferPointer { pointer in
            pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: windowSize) {
                vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(nOver2))
            }
        }

        // 执行 FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // 归一化 FFT 输出
        var scale: Float = 1.0 / Float(2 * nOver2)
        vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(nOver2))
        vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(nOver2))
    }
    // 获取频率对应的振幅值
    func getFFTOutput() -> [Float] {
        var magnitudes = [Float](repeating: 0.0, count: nOver2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(nOver2))
        return magnitudes
    }

    deinit {
        // 销毁 FFT setup
        vDSP_destroy_fftsetup(fftSetup)
    }
}
