import Foundation

/// The web `Snd` graph: oscillators and filtered noise into a master gain, a generated
/// stereo reverb on a wet send, a drone that opens with flow, and a soft compressor.
///
/// The render method is real-time safe after the first call (no allocation). Commands from
/// the main thread are queued and applied at the start of the next render.
public final class SynthEngine: @unchecked Sendable {
    public let sampleRate: Double

    private let lock = NSLock()
    private var commands: [Command]
    private var read = 0
    private var write = 0
    private var scratch: [Command] = []

    private var voices: [Voice]
    private var noise = SplitMix(0xA11CE)
    private var pad = Pad()
    private var reverb: DiffuseReverb
    private var compressor: Compressor

    private var master = 0.85
    private var masterTarget = 0.85
    private let masterCoeff: Double

    private let maxFrames = 8192
    private var wetBus: [Float]
    private var dryBus: [Float]

    public init(sampleRate: Double = 44100) {
        let rate = sampleRate > 0 ? sampleRate : 44100
        self.sampleRate = rate
        commands = Array(repeating: .mute(false, immediate: false), count: 64)
        scratch.reserveCapacity(64)
        voices = (0..<24).map { _ in Voice() }
        reverb = DiffuseReverb(sampleRate: rate)
        compressor = Compressor(sampleRate: rate)
        masterCoeff = 1 - exp(-1 / (0.03 * rate))
        wetBus = [Float](repeating: 0, count: maxFrames)
        dryBus = [Float](repeating: 0, count: maxFrames)
        pad.prepare(sampleRate: rate)
    }

    public func play(_ cue: SynthCue) {
        enqueue(.cue(cue))
    }

    public func setMood(live: Bool, title: Bool, flow: Int) {
        enqueue(.mood(live: live, title: title, flow: flow))
    }

    /// `immediate` skips the 30 ms web ramp, used when rebuilding the engine so a muted
    /// session does not blip. The flag is applied on the render thread with the other commands.
    public func setMuted(_ muted: Bool, immediate: Bool = false) {
        enqueue(.mute(muted, immediate: immediate))
    }

    public func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        var done = 0
        while done < frames {
            let n = min(maxFrames, frames - done)
            renderChunk(left: left.advanced(by: done), right: right.advanced(by: done), frames: n)
            done += n
        }
    }

    public func pull(_ frames: Int) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { lp in
            right.withUnsafeMutableBufferPointer { rp in
                render(left: lp.baseAddress!, right: rp.baseAddress!, frames: frames)
            }
        }
        for i in 0..<frames { left[i] = 0.5 * (left[i] + right[i]) }
        return left
    }

    private func renderChunk(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        drain()
        let dt = 1 / sampleRate
        for i in 0..<frames {
            master += (masterTarget - master) * masterCoeff
            pad.advance()

            var dry = pad.filtered
            var wet = pad.filtered + pad.shimmer

            for v in voices.indices where voices[v].active {
                let (d, w) = voices[v].sample(dt: dt, sampleRate: sampleRate, noise: &noise)
                dry += d
                wet += w
            }

            dry *= master
            wet *= master
            let tail = reverb.process(wet)
            var l = Float(dry + tail.0)
            var r = Float(dry + tail.1)
            compressor.process(&l, &r)
            if !l.isFinite { l = 0 }
            if !r.isFinite { r = 0 }
            left[i] = min(1, max(-1, l))
            right[i] = min(1, max(-1, r))
        }
    }

    private func drain() {
        scratch.removeAll(keepingCapacity: true)
        lock.lock()
        while read != write {
            scratch.append(commands[read])
            read = (read + 1) % commands.count
        }
        lock.unlock()
        for command in scratch { apply(command) }
    }

    private func enqueue(_ command: Command) {
        lock.lock()
        commands[write] = command
        write = (write + 1) % commands.count
        if write == read { read = (read + 1) % commands.count }
        lock.unlock()
    }

    private func apply(_ command: Command) {
        switch command {
        case .mute(let muted, let immediate):
            masterTarget = muted ? 0 : 0.85
            if immediate { master = masterTarget }
        case .mood(let live, let title, let flow):
            let levels = PadLevels.levels(live: live, title: title, flow: flow)
            pad.gainTarget = levels.gain
            pad.cutoffTarget = levels.cutoff
            pad.shimmerTarget = levels.shimmer
        case .cue(let cue):
            schedule(cue)
        }
    }

    private func schedule(_ cue: SynthCue) {
        switch cue {
        case .release:
            noise(f: 900, to: 2800, dur: 0.17, gain: 0.1, q: 0.8)
        case .pluck(let step, let bell):
            let f = SynthScale.frequency(forStep: step)
            tone(f, wave: .triangle, dur: 0.75, gain: 0.2, wet: 0.6)
            tone(f * 2, dur: 0.45, gain: 0.06, wet: 0.5, at: 0.012)
            if bell {
                tone(f * 3, dur: 1.3, gain: 0.05, wet: 0.9, at: 0.03)
                tone(f * 4.02, dur: 1.1, gain: 0.03, wet: 0.9, at: 0.05)
            }
        case .newBest:
            tone(1174.66, dur: 0.5, gain: 0.07, wet: 0.9, at: 0.25)
            tone(1567.98, dur: 0.7, gain: 0.07, wet: 0.9, at: 0.37)
        case .recapture:
            tone(196, wave: .triangle, dur: 0.3, gain: 0.14, wet: 0.4)
        case .flowLost:
            tone(392, to: 311, wave: .triangle, dur: 0.2, gain: 0.09, wet: 0.4)
        case .knock:
            tone(190, to: 92, wave: .triangle, dur: 0.09, gain: 0.22)
        case .fuse(let left):
            tone(1250 + (1.5 - left) * 320, wave: .square, dur: 0.035, gain: 0.028)
        case .supernova:
            noise(kind: .lowpass, f: 3200, to: 110, dur: 0.9, gain: 0.3, wet: 0.6)
            tone(140, to: 38, dur: 0.8, gain: 0.26)
        case .plate:
            for (k, f) in [293.66, 440, 587.33, 739.99].enumerated() {
                tone(f, dur: 1.7, attack: 0.35, gain: 0.045, wet: 0.9, at: 0.15 + Double(k) * 0.09)
            }
        case .died(let inNebula):
            if inNebula { noise(kind: .lowpass, f: 1400, to: 90, dur: 0.6, gain: 0.25, wet: 0.5) }
            tone(220, to: 104, wave: .triangle, dur: 0.8, gain: 0.16, wet: 0.8)
            tone(164.81, to: 78, dur: 0.9, gain: 0.14, wet: 0.8, at: 0.07)
        case .chime:
            tone(587.33, to: 880, wave: .triangle, dur: 0.14, gain: 0.12, wet: 0.5)
        }
    }

    private func tone(
        _ f: Double, to: Double? = nil, wave: Wave = .sine, dur: Double = 0.3, attack: Double = 0.008,
        gain: Double = 0.2, wet: Double = 0, at: Double = 0
    ) {
        var voice = takeVoice()
        voice.active = true
        voice.wave = wave
        voice.phase = 0
        voice.f0 = f
        voice.f1 = to ?? f
        voice.glide = to != nil
        voice.age = -at
        voice.dur = dur
        voice.attack = attack
        voice.peak = gain
        voice.wet = wet
        voice.useFilter = false
        voices[voice.index] = voice
    }

    private func noise(
        kind: FilterKind = .bandpass, f: Double, to: Double? = nil, dur: Double, gain: Double,
        q: Double = 1, wet: Double = 0, at: Double = 0
    ) {
        var voice = takeVoice()
        voice.active = true
        voice.wave = .noise
        voice.age = -at
        voice.dur = dur
        voice.attack = 0.008
        voice.peak = gain
        voice.wet = wet
        voice.useFilter = true
        voice.filterKind = kind
        voice.filterF0 = f
        voice.filterF1 = to ?? f
        voice.filterGlide = to != nil
        voice.filterQ = q
        voice.filter = Biquad()
        voice.filter.set(kind: kind, freq: f, q: q, sampleRate: sampleRate)
        voices[voice.index] = voice
    }

    private func takeVoice() -> Voice {
        if let i = voices.indices.first(where: { !voices[$0].active }) {
            var voice = voices[i]
            voice.index = i
            return voice
        }
        var quietest = 0
        var level = Double.greatestFiniteMagnitude
        for i in voices.indices {
            let remaining = voices[i].envelope
            if remaining < level {
                level = remaining
                quietest = i
            }
        }
        var voice = voices[quietest]
        voice.index = quietest
        return voice
    }
}

private enum Command: Equatable {
    case cue(SynthCue)
    case mood(live: Bool, title: Bool, flow: Int)
    case mute(Bool, immediate: Bool)
}

private enum Wave {
    case sine, triangle, square, noise
}

enum FilterKind {
    case lowpass, bandpass
}

struct Biquad {
    var b0 = 1.0
    var b1 = 0.0
    var b2 = 0.0
    var a1 = 0.0
    var a2 = 0.0
    var z1 = 0.0
    var z2 = 0.0

    mutating func set(kind: FilterKind, freq: Double, q: Double, sampleRate: Double) {
        let f = min(max(freq, 20), sampleRate * 0.45)
        let w0 = 2 * Double.pi * f / sampleRate
        let cosw = cos(w0)
        let alpha = sin(w0) / (2 * max(q, 0.05))
        let b0r: Double
        let b1r: Double
        let b2r: Double
        let a0r: Double
        let a1r: Double
        let a2r: Double
        switch kind {
        case .lowpass:
            b0r = (1 - cosw) / 2
            b1r = 1 - cosw
            b2r = (1 - cosw) / 2
            a0r = 1 + alpha
            a1r = -2 * cosw
            a2r = 1 - alpha
        case .bandpass:
            b0r = alpha
            b1r = 0
            b2r = -alpha
            a0r = 1 + alpha
            a1r = -2 * cosw
            a2r = 1 - alpha
        }
        b0 = b0r / a0r
        b1 = b1r / a0r
        b2 = b2r / a0r
        a1 = a1r / a0r
        a2 = a2r / a0r
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        if abs(z1) < 1e-20 { z1 = 0 }
        if abs(z2) < 1e-20 { z2 = 0 }
        return y
    }
}

private struct Voice {
    var index = 0
    var active = false
    var wave: Wave = .sine
    var phase = 0.0
    var f0 = 440.0
    var f1 = 440.0
    var glide = false
    var age = 0.0
    var dur = 0.3
    var attack = 0.008
    var peak = 0.2
    var wet = 0.0
    var useFilter = false
    var filterKind: FilterKind = .bandpass
    var filterF0 = 1000.0
    var filterF1 = 1000.0
    var filterGlide = false
    var filterQ = 1.0
    var filter = Biquad()

    var envelope: Double {
        let t = age
        if t < 0 || t >= dur { return 0 }
        let a = max(attack, 1e-4)
        let peak = max(self.peak, 1e-4)
        if t < a { return 0.0001 * pow(peak / 0.0001, t / a) }
        return peak * pow(0.0001 / peak, (t - a) / max(dur - a, 1e-4))
    }

    mutating func sample(dt: Double, sampleRate: Double, noise: inout SplitMix) -> (Double, Double) {
        age += dt
        let env = envelope
        if age >= dur {
            active = false
            return (0, 0)
        }
        if env == 0 { return (0, 0) }

        let freq = glide && f0 > 0 && f1 > 0 && dur > 0
            ? f0 * pow(f1 / f0, min(max(age / dur, 0), 1))
            : f0
        var sample: Double
        switch wave {
        case .sine:
            sample = sin(phase * 2 * Double.pi)
            phase += freq / sampleRate
        case .triangle:
            let x = phase - floor(phase)
            sample = 1 - 4 * abs(x - 0.5)
            phase += freq / sampleRate
        case .square:
            sample = (phase - floor(phase)) < 0.5 ? 1 : -1
            phase += freq / sampleRate
        case .noise:
            sample = noise.unit() * 2 - 1
            if useFilter {
                let f = filterGlide && dur > 0
                    ? filterF0 * pow(max(filterF1, 1) / max(filterF0, 1), min(max(age / dur, 0), 1))
                    : filterF0
                filter.set(kind: filterKind, freq: f, q: filterQ, sampleRate: sampleRate)
                sample = filter.process(sample)
            }
        }
        if phase >= 1 { phase -= floor(phase) }
        let shaped = sample * env
        return (shaped, shaped * wet)
    }
}

private struct Pad {
    var phase: [Double] = [0, 0, 0, 0, 0, 0]
    var gain = 0.0
    var gainTarget = 0.0
    var cutoff = 420.0
    var cutoffTarget = 420.0
    var shimmer = 0.0
    var shimmerTarget = 0.0
    var filter = Biquad()
    var filtered = 0.0
    var shimmerSample = 0.0
    var gainCoeff = 0.0
    var toneCoeff = 0.0
    var sampleRate = 44100.0
    var sinceFilter = 0

    mutating func prepare(sampleRate: Double) {
        self.sampleRate = sampleRate
        gainCoeff = 1 - exp(-1 / (0.5 * sampleRate))
        toneCoeff = 1 - exp(-1 / (0.7 * sampleRate))
        filter.set(kind: .lowpass, freq: cutoff, q: 0.7, sampleRate: sampleRate)
    }

    mutating func advance() {
        gain += (gainTarget - gain) * gainCoeff
        cutoff += (cutoffTarget - cutoff) * toneCoeff
        shimmer += (shimmerTarget - shimmer) * toneCoeff
        let rates = [73.42, 110.3, 146.83, 220.6, 587.33, 881.0]
        let sr = sampleRate
        for i in 0..<6 {
            phase[i] += rates[i] / sr
            if phase[i] >= 1 { phase[i] -= 1 }
        }
        let sum = sin(phase[0] * 2 * .pi) * 0.5
            + sin(phase[1] * 2 * .pi) * 0.3
            + triangle(phase[2]) * 0.16
            + sin(phase[3] * 2 * .pi) * 0.1
        sinceFilter += 1
        if sinceFilter >= 64 {
            sinceFilter = 0
            filter.set(kind: .lowpass, freq: cutoff, q: 0.7, sampleRate: sr)
        }
        filtered = filter.process(sum * gain)
        shimmerSample = (sin(phase[4] * 2 * .pi) + sin(phase[5] * 2 * .pi)) * shimmer
    }
}

private func triangle(_ phase: Double) -> Double {
    let x = phase - floor(phase)
    return 1 - 4 * abs(x - 0.5)
}

/// Wet send at a quarter of the output rate, through the generated impulse.
private struct DiffuseReverb {
    var left: PartitionedConvolver
    var right: PartitionedConvolver
    var lowpass = 0.0
    let follow: Double
    var bucket = 0
    var sub = 0
    var previousL = 0.0
    var previousR = 0.0
    var nextL = 0.0
    var nextR = 0.0
    let factor = 4

    init(sampleRate: Double) {
        let reverbRate = sampleRate / Double(factor)
        let impulses = makeReverbImpulses(sampleRate: reverbRate)
        left = PartitionedConvolver(impulse: impulses.left, block: 256)
        right = PartitionedConvolver(impulse: impulses.right, block: 256)
        let cutoff = 0.45 * (sampleRate / Double(factor * 2))
        follow = 1 - exp(-2 * Double.pi * cutoff / sampleRate)
    }

    mutating func process(_ wet: Double) -> (Double, Double) {
        lowpass += follow * (wet * 0.5 - lowpass)
        bucket += 1
        if bucket == factor {
            bucket = 0
            previousL = nextL
            previousR = nextR
            nextL = Double(left.push(Float(lowpass)))
            nextR = Double(right.push(Float(lowpass)))
            sub = 0
        } else {
            sub += 1
        }
        let t = Double(sub) / Double(factor)
        return (previousL + (nextL - previousL) * t, previousR + (nextR - previousR) * t)
    }
}

private struct Compressor {
    var detector: Float = -90
    let threshold: Float = -24
    let knee: Float = 30
    let ratio: Float = 12
    let attack: Float
    let release: Float

    init(sampleRate: Double) {
        attack = Float(1 - exp(-1 / (0.003 * sampleRate)))
        release = Float(1 - exp(-1 / (0.25 * sampleRate)))
    }

    mutating func process(_ l: inout Float, _ r: inout Float) {
        let mag = max(abs(l), abs(r))
        let db = 20 * log10(max(mag, 1e-8))
        detector += (db - detector) * (db > detector ? attack : release)
        let reduction = curve(detector) - detector
        let gain = pow(10, reduction / 20)
        l *= gain
        r *= gain
    }

    func curve(_ x: Float) -> Float {
        let half = knee / 2
        if x < threshold - half { return x }
        if x > threshold + half { return threshold + (x - threshold) / ratio }
        let k = x - threshold + half
        return x + (1 / ratio - 1) * (k * k) / (2 * knee)
    }
}
