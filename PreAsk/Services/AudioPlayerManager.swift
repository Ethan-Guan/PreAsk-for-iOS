import Foundation
import AVFoundation
import Combine

enum AudioPlaybackState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case error(String)
    
    static func == (lhs: AudioPlaybackState, rhs: AudioPlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.ready, .ready), (.playing, .playing), (.paused, .paused):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var state: AudioPlaybackState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var synthesizedText: String = ""
    @Published var waveSamples: [CGFloat] = []
    @Published var waveActivated: [TimeInterval] = []

    static let waveDotCount = 60
    static let waveHoldDuration: TimeInterval = 2.0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioFileURL: URL?

    override private init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioPlayer] AVAudioSession setup failed: \(error)")
        }
    }

    func load(audioData: Data, text: String) {
        stop()

        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            synthesizedText = text
            currentTime = 0
            
            waveSamples = analyzeWaveform(from: audioData, sampleCount: AudioPlayerManager.waveDotCount)
            waveActivated = Array(repeating: -1.0, count: AudioPlayerManager.waveDotCount)

            state = .ready
        } catch {
            state = .error("音频加载失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 波形分析
    private func analyzeWaveform(from data: Data, sampleCount: Int) -> [CGFloat] {
        guard sampleCount > 0 else { return [] }
        
        // 尝试从音频数据中提取波形
        // 使用AVAudioFile读取音频样本
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        do {
            try data.write(to: tempURL)
            let audioFile = try AVAudioFile(forReading: tempURL)
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                           sampleRate: audioFile.fileFormat.sampleRate, 
                                           channels: 1, 
                                           interleaved: true) else {
                return generateFallbackWaveform(count: sampleCount)
            }
            
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return generateFallbackWaveform(count: sampleCount)
            }
            
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else {
                return generateFallbackWaveform(count: sampleCount)
            }
            
            // 计算波形样本
            var samples: [CGFloat] = []
            let framesPerSample = max(1, Int(frameCount) / sampleCount)
            
            for i in 0..<sampleCount {
                let startFrame = i * framesPerSample
                let endFrame = min(startFrame + framesPerSample, Int(frameCount))
                
                var maxAmplitude: Float = 0
                for j in startFrame..<endFrame {
                    let amplitude = abs(channelData[j])
                    if amplitude > maxAmplitude {
                        maxAmplitude = amplitude
                    }
                }
                
                // 归一化到0-1，添加最小高度
                let normalized = min(1, max(CGFloat(maxAmplitude), 0.15))
                samples.append(normalized)
            }
            
            return samples
            
        } catch {
            print("[AudioPlayer] Waveform analysis failed: \(error)")
            return generateFallbackWaveform(count: sampleCount)
        }
    }
    
    // 备用波形生成（当无法分析真实音频时）
    private func generateFallbackWaveform(count: Int) -> [CGFloat] {
        var samples: [CGFloat] = []
        for i in 0..<count {
            let t = Double(i) / Double(count)
            // 生成类似语音的波形，有一些变化
            let base = 0.3 + 0.4 * sin(t * .pi * 3)
            let variation = 0.2 * sin(t * .pi * 8)
            let value = max(0.15, min(1, base + variation))
            samples.append(CGFloat(value))
        }
        return samples
    }

    func play() {
        guard let player = audioPlayer else { return }
        player.play()
        state = .playing
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        state = .paused
        stopTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopTimer()
        currentTime = 0
        duration = 0
        waveSamples = []
        waveActivated = []
        state = .idle
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setLoading() {
        stop()
        state = .loading
    }

    func setError(_ message: String) {
        state = .error(message)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            let time = player.currentTime
            self.currentTime = time
            if self.duration > 0 {
                let progress = time / self.duration
                let idx = Int(progress * CGFloat(AudioPlayerManager.waveDotCount))
                if idx >= 0 && idx < AudioPlayerManager.waveDotCount {
                    var activated = self.waveActivated
                    if activated.count != AudioPlayerManager.waveDotCount {
                        activated = Array(repeating: -1.0, count: AudioPlayerManager.waveDotCount)
                    }
                    activated[idx] = Date().timeIntervalSinceReferenceDate
                    self.waveActivated = activated
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stopTimer()
            self.currentTime = self.duration
            self.state = .ready
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.state = .error("音频解码错误：\(error?.localizedDescription ?? "未知错误")")
        }
    }
}
