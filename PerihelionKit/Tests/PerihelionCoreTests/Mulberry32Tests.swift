import Testing

@testable import PerihelionCore

struct Mulberry32Tests {
    @Test(arguments: [
        (UInt32(20_261_110), [0.47585524804890156, 0.4372278384398669, 0.7736968537792563, 0.2937412660103291]),
        (UInt32(0), [0.26642920868471265, 0.0003297457005828619, 0.2232720274478197, 0.1462021479383111]),
        (UInt32.max, [0.8964226141106337, 0.189478256739676, 0.7156526781618595, 0.9440599093213677]),
    ])
    func matchesJavaScript(seed: UInt32, expected: [Double]) {
        var rng = Mulberry32(seed: seed)
        #expect(expected.map { _ in rng.next() } == expected)
    }
}
