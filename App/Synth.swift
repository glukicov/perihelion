import AVFoundation
import PerihelionAudio
import QuartzCore

/// Plays `SynthEngine` through `AVAudioEngine`.
///
/// The session is `.ambient` with mix-with-others: sound is heard while the ring switch
/// is set to ring, stays silent when the phone is muted, and does not stop other audio.
/// The engine is created only after the session is active; building it earlier is a common
/// reason a game stays silent even with the ringer on.
@MainActor
final class Synth {
    private var engine: AVAudioEngine?
    private var dsp: SynthEngine
    private var source: AVAudioSourceNode?
    private var started = false
    private var muted = false
    private var live = false
    private var titleMood = true
    private var flow = 0
    private var rate = 44100.0
    private var retryAt = 0.0

    init() {
        dsp = SynthEngine(sampleRate: 44100)
    }

    func setMuted(_ muted: Bool) {
        self.muted = muted
        dsp.setMuted(muted)
    }

    func setMood(live: Bool, title: Bool, flow: Int) {
        self.live = live
        self.titleMood = title
        self.flow = flow
        dsp.setMood(live: live, title: title, flow: flow)
    }

    func play(_ cue: SynthCue) {
        ensureRunning()
        dsp.play(cue)
    }

    func prepare() {
        ensureRunning()
    }

    func resume() {
        let hardware = AVAudioSession.sharedInstance().sampleRate
        if started, hardware > 0, abs(hardware - rate) > 1 {
            tearDown()
        }
        ensureRunning()
    }

    func keepAlive() {
        guard started, let engine, !engine.isRunning else { return }
        let now = CACurrentMediaTime()
        guard now >= retryAt else { return }
        retryAt = now + 0.5
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            tearDown()
            ensureRunning()
        }
    }

    private func ensureRunning() {
        if started {
            keepAlive()
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let engine = AVAudioEngine()
            let outputRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let sessionRate = session.sampleRate
            let rate = outputRate > 8000 ? outputRate : (sessionRate > 8000 ? sessionRate : 44100)
            try install(on: engine, sampleRate: rate)
            engine.mainMixerNode.outputVolume = 1
            self.engine = engine
            self.rate = rate
            try engine.start()
            started = true
        } catch {
            tearDown()
        }
    }

    private func install(on engine: AVAudioEngine, sampleRate: Double) throws {
        let dsp = SynthEngine(sampleRate: sampleRate)
        dsp.setMuted(muted, immediate: true)
        dsp.setMood(live: live, title: titleMood, flow: flow)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw SynthError.noFormat
        }
        let node = AVAudioSourceNode(format: format) { @Sendable _, _, frameCount, audioBufferList in
            Synth.render(dsp, frames: frameCount, list: audioBufferList)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.dsp = dsp
        source = node
    }

    private nonisolated static func render(
        _ dsp: SynthEngine, frames: AVAudioFrameCount, list: UnsafeMutablePointer<AudioBufferList>
    ) {
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        guard let first = buffers.first, let left = first.mData?.assumingMemoryBound(to: Float.self) else { return }
        let count = Int(frames)
        if buffers.count > 1, let data = buffers[1].mData {
            dsp.render(left: left, right: data.assumingMemoryBound(to: Float.self), frames: count)
        } else {
            dsp.render(left: left, right: left, frames: count)
        }
    }

    private func tearDown() {
        engine?.stop()
        if let engine, let source { engine.detach(source) }
        engine = nil
        source = nil
        started = false
    }
}

private enum SynthError: Error {
    case noFormat
}
