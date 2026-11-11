import Testing
@testable import PerihelionAudio

struct SynthTests {
    @Test func fftRoundTrip() {
        var re: [Float] = [0, 1, 0, -0.5, 0.25, 0, 0, 0]
        var im = [Float](repeating: 0, count: re.count)
        let original = re
        fft(&re, &im, n: re.count, inverse: false)
        fft(&re, &im, n: re.count, inverse: true)
        for i in re.indices {
            #expect(abs(re[i] - original[i]) < 1e-5)
            #expect(abs(im[i]) < 1e-5)
        }
    }

    @Test func convolverReproducesTheImpulse() {
        let block = 256
        var impulse = [Float](repeating: 0, count: block + 4)
        impulse[0] = 0.5
        impulse[2] = -0.25
        impulse[block] = 0.125
        let convolver = PartitionedConvolver(impulse: impulse, block: block)
        var output = [Float](repeating: 0, count: block * 3)
        for i in output.indices {
            output[i] = convolver.push(i == 0 ? 1 : 0)
        }
        let latency = block - 1
        #expect(abs(output[latency] - 0.5) < 1e-3)
        #expect(abs(output[latency + 2] - (-0.25)) < 1e-3)
        #expect(abs(output[latency + block] - 0.125) < 1e-3)
        #expect(abs(output[latency + 1]) < 1e-3)
    }

    @Test func padLevelsMatchTheWeb() {
        #expect(PadLevels.levels(live: true, title: false, flow: 0) == PadLevels(gain: 0.07, cutoff: 420, shimmer: 0))
        let full = PadLevels.levels(live: true, title: false, flow: 7)
        #expect(abs(full.gain - 0.12) < 1e-9)
        #expect(full.cutoff == 1320)
        #expect(abs(full.shimmer - 0.012) < 1e-12)
        #expect(PadLevels.levels(live: false, title: true, flow: 4).gain == 0.045)
        #expect(PadLevels.levels(live: false, title: false, flow: 4).gain == 0.02)
        #expect(PadLevels.levels(live: true, title: false, flow: 0).cutoff == 420)
    }

    @Test func pluckStepsClimbThePentatonic() {
        #expect(SynthScale.frequency(forStep: SynthScale.pluckStep(flow: 0, starIndex: 3)) == 293.66)
        #expect(SynthScale.frequency(forStep: SynthScale.pluckStep(flow: 6, starIndex: 1)) == 659.25)
        #expect(SynthScale.pluckStep(flow: 7, starIndex: 0) == 7)
        #expect(SynthScale.pluckStep(flow: 7, starIndex: 5) == 8)
        #expect(SynthScale.frequency(forStep: 8) == 880)
        #expect(SynthScale.pluckStep(flow: 7, starIndex: 99) == 7 + (99 % 4))
    }

    @Test func knockIsShortAndDry() {
        let engine = SynthEngine(sampleRate: 44100)
        engine.play(.knock)
        let early = rms(engine.pull(4410))
        let late = rms(engine.pull(4410))
        #expect(early > 0.01)
        #expect(late < early * 0.25)
    }

    @Test func pluckHasABodyAndAReverbTail() {
        let engine = SynthEngine(sampleRate: 44100)
        engine.play(.pluck(step: 4, bell: false))
        _ = engine.pull(2205)
        let body = rms(engine.pull(13230))
        _ = engine.pull(22050)
        let tail = rms(engine.pull(8820))
        #expect(body > 0.01)
        #expect(tail > 0.0003)
        #expect(tail < body)
    }

    @Test func muteSilencesAPluck() {
        let engine = SynthEngine(sampleRate: 44100)
        engine.setMuted(true, immediate: true)
        engine.play(.pluck(step: 2, bell: true))
        #expect(rms(engine.pull(22050)) < 1e-5)
    }

    @Test func theSameNotesRenderIdentically() {
        func take() -> [Float] {
            let engine = SynthEngine(sampleRate: 22050)
            engine.setMood(live: true, title: false, flow: 3)
            engine.play(.pluck(step: 3, bell: true))
            engine.play(.knock)
            return engine.pull(4000)
        }
        #expect(take() == take())
    }

    @Test func playIsLouderThanTheDeadDroneOnceItOpens() {
        func settled(_ live: Bool, flow: Int) -> Float {
            let engine = SynthEngine(sampleRate: 22050)
            engine.setMood(live: live, title: false, flow: flow)
            _ = engine.pull(22050)
            return rms(engine.pull(4096))
        }
        #expect(settled(true, flow: 7) > settled(false, flow: 0) * 1.4)
    }
}

private func rms(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    var sum = 0.0
    for sample in samples { sum += Double(sample) * Double(sample) }
    return Float((sum / Double(samples.count)).squareRoot())
}
