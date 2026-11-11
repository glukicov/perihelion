import Foundation

/// In-place radix-2 complex FFT. Inverse scales by `1/n`, so a round trip restores the input.
func fft(_ re: inout [Float], _ im: inout [Float], n: Int, inverse: Bool) {
    var j = 0
    var i = 1
    while i < n {
        var bit = n >> 1
        while j & bit != 0 {
            j ^= bit
            bit >>= 1
        }
        j ^= bit
        if i < j {
            re.swapAt(i, j)
            im.swapAt(i, j)
        }
        i += 1
    }

    var len = 2
    while len <= n {
        let angle = (inverse ? 2 : -2) * Float.pi / Float(len)
        let wRe = cos(angle)
        let wIm = sin(angle)
        let half = len >> 1
        var start = 0
        while start < n {
            var cRe: Float = 1
            var cIm: Float = 0
            for k in 0..<half {
                let a = start + k
                let b = a + half
                let tRe = re[b] * cRe - im[b] * cIm
                let tIm = re[b] * cIm + im[b] * cRe
                re[b] = re[a] - tRe
                im[b] = im[a] - tIm
                re[a] += tRe
                im[a] += tIm
                let nRe = cRe * wRe - cIm * wIm
                cIm = cRe * wIm + cIm * wRe
                cRe = nRe
            }
            start += len
        }
        len <<= 1
    }

    if inverse {
        let scale = 1 / Float(n)
        for k in 0..<n {
            re[k] *= scale
            im[k] *= scale
        }
    }
}

/// Uniformly partitioned convolution. `push` returns one sample, delayed by one block,
/// which is the overlap-add of `impulse` with the input.
final class PartitionedConvolver {
    let block: Int
    let nfft: Int
    let partitions: Int

    private var irRe: [Float]
    private var irIm: [Float]
    private var histRe: [Float]
    private var histIm: [Float]
    private var histWrite = 0

    private var collect: [Float]
    private var filled = 0
    private var overlap: [Float]
    private var out: [Float]
    private var outRead = 0
    private var outCount = 0

    private var re: [Float]
    private var im: [Float]
    private var accRe: [Float]
    private var accIm: [Float]

    init(impulse: [Float], block: Int = 256) {
        precondition(block > 0 && block & (block - 1) == 0, "block must be a power of two")
        self.block = block
        self.nfft = block * 2
        let parts = max(1, (max(impulse.count, 1) + block - 1) / block)
        self.partitions = parts
        irRe = [Float](repeating: 0, count: parts * nfft)
        irIm = [Float](repeating: 0, count: parts * nfft)
        histRe = [Float](repeating: 0, count: parts * nfft)
        histIm = [Float](repeating: 0, count: parts * nfft)
        collect = [Float](repeating: 0, count: block)
        overlap = [Float](repeating: 0, count: block)
        out = [Float](repeating: 0, count: block)
        re = [Float](repeating: 0, count: nfft)
        im = [Float](repeating: 0, count: nfft)
        accRe = [Float](repeating: 0, count: nfft)
        accIm = [Float](repeating: 0, count: nfft)
        install(impulse)
    }

    func push(_ x: Float) -> Float {
        collect[filled] = x
        filled += 1
        if filled == block {
            convolveBlock()
            filled = 0
        }
        if outCount > 0 {
            let y = out[outRead]
            outRead += 1
            if outRead == block { outRead = 0 }
            outCount -= 1
            return y
        }
        return 0
    }

    private func install(_ impulse: [Float]) {
        for p in 0..<partitions {
            for i in 0..<nfft {
                re[i] = 0
                im[i] = 0
            }
            let base = p * block
            let n = min(block, max(0, impulse.count - base))
            for i in 0..<n { re[i] = impulse[base + i] }
            fft(&re, &im, n: nfft, inverse: false)
            let offset = p * nfft
            for i in 0..<nfft {
                irRe[offset + i] = re[i]
                irIm[offset + i] = im[i]
            }
        }
    }

    private func convolveBlock() {
        for i in 0..<block {
            re[i] = collect[i]
            im[i] = 0
        }
        for i in block..<nfft {
            re[i] = 0
            im[i] = 0
        }
        fft(&re, &im, n: nfft, inverse: false)

        let history = histWrite * nfft
        for i in 0..<nfft {
            histRe[history + i] = re[i]
            histIm[history + i] = im[i]
        }
        histWrite += 1
        if histWrite == partitions { histWrite = 0 }

        for i in 0..<nfft {
            accRe[i] = 0
            accIm[i] = 0
        }

        var h = histWrite - 1
        if h < 0 { h = partitions - 1 }
        for p in 0..<partitions {
            let hb = h * nfft
            let ib = p * nfft
            for k in 0..<nfft {
                let ar = histRe[hb + k]
                let ai = histIm[hb + k]
                let br = irRe[ib + k]
                let bi = irIm[ib + k]
                accRe[k] += ar * br - ai * bi
                accIm[k] += ar * bi + ai * br
            }
            h -= 1
            if h < 0 { h = partitions - 1 }
        }

        for i in 0..<nfft {
            re[i] = accRe[i]
            im[i] = accIm[i]
        }
        fft(&re, &im, n: nfft, inverse: true)

        for i in 0..<block {
            out[i] = re[i] + overlap[i]
            overlap[i] = re[block + i]
        }
        outRead = 0
        outCount = block
    }
}

struct SplitMix {
    var state: UInt64

    init(_ seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 1
        if state == 0 { state = 0xA5A5A5A5A5A5A5A5 }
    }

    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let bits = (state >> 11) & 0x1F_FFFF_FFFF_FFFF
        return Double(bits) / Double(0x1F_FFFF_FFFF_FFFF)
    }
}

/// Stereo decaying-noise impulse, normalised the way a WebAudio `ConvolverNode` normalises
/// (`normalize = true`): RMS across both channels, then the Chromium calibration so a long
/// noise tail stays at a musical level instead of summing to a blast.
func makeReverbImpulses(sampleRate: Double, seconds: Double = 2.6, seed: UInt64 = 0xC0FFEE) -> (left: [Float], right: [Float]) {
    let n = max(1, Int((sampleRate * seconds).rounded()))
    var left = [Float](repeating: 0, count: n)
    var right = [Float](repeating: 0, count: n)
    var rng = SplitMix(seed)
    var power = 0.0
    let denom = Double(n)
    for i in 0..<n {
        let env = pow(1 - Double(i) / denom, 2.8)
        let l = (rng.unit() * 2 - 1) * env
        let r = (rng.unit() * 2 - 1) * env
        left[i] = Float(l)
        right[i] = Float(r)
        power += l * l + r * r
    }
    var rms = (power / Double(2 * n)).squareRoot()
    if !rms.isFinite || rms < 0.000125 { rms = 0.000125 }
    var scale = (1 / rms) * 0.00125
    scale *= 44100 / sampleRate
    let s = Float(scale)
    for i in 0..<n {
        left[i] *= s
        right[i] *= s
    }
    return (left, right)
}
