import AVFoundation

/// A small piece of the web game's synth: the life cues only.
/// The full score (plucks, drone, whooshes) is still ahead.
@MainActor
final class Synth {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var attached = false
    private var started = false
    private let muted: Bool

    init() {
        let stored = UserDefaults.standard.object(forKey: "perihelion.muted")
        if let number = stored as? NSNumber {
            muted = number.boolValue
        } else if let text = stored as? String {
            muted = text == "1"
        } else {
            muted = false
        }
    }

    func lifeRestored() {
        render(duration: 0.48) { time in
            let first = Self.tone(frequency: 587.33, time: time, duration: 0.34)
            let second = Self.tone(frequency: 880, time: time - 0.09, duration: 0.36)
            return (first + second) * 0.11
        }
    }

    func lifeLost() {
        let duration = 0.26
        let frames = Int(Self.sampleRate * duration)
        var phase = 0.0
        var samples = [Double](repeating: 0, count: frames)
        for index in 0..<frames {
            let time = Double(index) / Self.sampleRate
            let glide = min(max(time / duration, 0), 1)
            let frequency = 392 * pow(294 / 392, glide)
            phase += 2 * Double.pi * frequency / Self.sampleRate
            samples[index] = sin(phase) * Self.envelope(time, duration) * 0.1
        }
        let rendered = samples
        render(duration: duration) { time in
            guard !rendered.isEmpty else { return 0 }
            let index = min(max(Int(time * Self.sampleRate), 0), rendered.count - 1)
            return rendered[index]
        }
    }

    private func render(duration: Double, sample: (Double) -> Double) {
        guard !muted else { return }
        guard prepare(), let format = format else { return }
        let frames = Int(Self.sampleRate * duration)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channels = buffer.floatChannelData else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        let samples = channels[0]
        for index in 0..<frames {
            samples[index] = Float(sample(Double(index) / Self.sampleRate))
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func prepare() -> Bool {
        if started { return true }
        if !attached {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else { return false }
            self.format = format
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            attached = true
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            player.play()
            started = true
            return true
        } catch {
            started = false
            return false
        }
    }

    private static let sampleRate = 44_100.0

    private static func tone(frequency: Double, time: Double, duration: Double) -> Double {
        guard time >= 0, time <= duration else { return 0 }
        return sin(2 * Double.pi * frequency * time) * envelope(time, duration)
    }

    private static func envelope(_ time: Double, _ duration: Double) -> Double {
        guard time >= 0, time <= duration else { return 0 }
        let attack = 0.012
        if time < attack { return time / attack }
        return exp(-3.2 * (time - attack) / max(duration - attack, 0.001))
    }
}
