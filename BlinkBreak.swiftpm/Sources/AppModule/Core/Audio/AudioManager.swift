@preconcurrency import AVFoundation

/// Synthesized cyberpunk audio engine — no external files needed.
/// Generates all sound effects procedurally using AVAudioEngine + tone synthesis.
@MainActor
final class AudioManager {
    static let shared = AudioManager()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let sampleRate: Double = 44100
    private var isSetup = false
    
    // Background music
    private var bgTimer: Timer?
    private var bgVolume: Float = 0.08
    
    private init() {}
    
    // MARK: - Setup
    
    func setup() {
        guard !isSetup else { return }
        isSetup = true
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioManager: Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Sound Effects (Synthesized)
    
    /// Digital "pew" laser sound — short, high-pitched sweep
    func playLaser() {
        playTone(
            startFreq: 1800,
            endFreq: 800,
            duration: 0.08,
            volume: 0.12,
            waveform: .square
        )
    }
    
    /// Enemy destroyed — crunchy burst
    func playExplosion() {
        playTone(startFreq: 400, endFreq: 60, duration: 0.15, volume: 0.15, waveform: .noise)
        playTone(startFreq: 1200, endFreq: 200, duration: 0.1, volume: 0.08, waveform: .sine)
    }
    
    /// Player hit damage — deep bass thud
    func playDamage() {
        playTone(startFreq: 120, endFreq: 40, duration: 0.2, volume: 0.2, waveform: .sine)
        playTone(startFreq: 300, endFreq: 80, duration: 0.15, volume: 0.1, waveform: .noise)
    }
    
    /// Barrel roll activated — ascending chime
    func playBarrelRoll() {
        playTone(startFreq: 600, endFreq: 1400, duration: 0.15, volume: 0.1, waveform: .sine)
    }
    
    /// Game over — descending doom tone
    func playGameOver() {
        playTone(startFreq: 500, endFreq: 80, duration: 0.5, volume: 0.15, waveform: .sine)
        playTone(startFreq: 350, endFreq: 60, duration: 0.4, volume: 0.1, waveform: .square)
    }
    
    /// Achievement / Level Up — positive bell
    func playLevelUp() {
        playTone(startFreq: 400, endFreq: 600, duration: 0.1, volume: 0.15, waveform: .sine)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(startFreq: 600, endFreq: 880, duration: 0.3, volume: 0.15, waveform: .sine)
        }
    }
    
    /// Hyperjump — dramatic ascending sweep
    func playHyperJump() {
        playTone(startFreq: 200, endFreq: 3000, duration: 0.6, volume: 0.15, waveform: .sine)
        playTone(startFreq: 100, endFreq: 1500, duration: 0.5, volume: 0.08, waveform: .square)
    }
    
    /// Shield warning beep
    func playShieldWarning() {
        playTone(startFreq: 880, endFreq: 880, duration: 0.08, volume: 0.1, waveform: .square)
    }
    
    // MARK: - Engine Hum (Background)
    
    func startEngineHum() {
        setup()
        stopEngineHum()
        
        // Periodic low rumble pulse
        bgTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playTone(startFreq: 55, endFreq: 50, duration: 1.8, volume: self?.bgVolume ?? 0.05, waveform: .sine)
            }
        }
        bgTimer?.fire()
    }
    
    func stopEngineHum() {
        bgTimer?.invalidate()
        bgTimer = nil
    }
    
    // MARK: - Synth Engine
    
    private enum Waveform {
        case sine, square, noise
    }
    
    private func playTone(startFreq: Double, endFreq: Double, duration: Double, volume: Float, waveform: Waveform) {
        let sampleCount = Int(sampleRate * duration)
        guard sampleCount > 0 else { return }
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        
        let data = buffer.floatChannelData![0]
        
        var phase: Double = 0
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleCount)
            let freq = startFreq + (endFreq - startFreq) * t
            let envelope = Float(1.0 - t) * volume // Linear fade out
            
            let sample: Float
            switch waveform {
            case .sine:
                sample = Float(sin(phase)) * envelope
            case .square:
                sample = (sin(phase) > 0 ? 1.0 : -1.0) * envelope * 0.5
            case .noise:
                sample = Float.random(in: -1...1) * envelope
            }
            
            data[i] = sample
            phase += 2.0 * Double.pi * freq / sampleRate
        }
        
        // Play on a new audio player each time (fire and forget)
        nonisolated(unsafe) let sendableBuffer = buffer
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let engine = AVAudioEngine()
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                try engine.start()
                player.scheduleBuffer(sendableBuffer, completionHandler: nil)
                player.play()
                
                // Keep engine alive for duration
                Thread.sleep(forTimeInterval: duration + 0.1)
                player.stop()
                engine.stop()
            } catch {
                // Silent fail — audio is non-critical
            }
        }
    }
}
