import Foundation

final class FBmGenerator {
    private let octaves: Int
    private let gain: Float
    private var values: [Float]
    private var counter: UInt64 = 0
    private let normalizationFactor: Float

    init(octaves: Int = 8, gain: Float = 0.5) {
        self.octaves = octaves
        self.gain = gain
        self.values = (0..<octaves).map { _ in Float.random(in: -1...1) }
        var sum: Float = 0
        var amp: Float = 1
        for _ in 0..<octaves { sum += amp; amp *= gain }
        self.normalizationFactor = 1.0 / sum
    }

    func nextSample() -> Float {
        counter &+= 1
        var k = 0
        var c = counter
        while (c & 1) == 0 && k < octaves - 1 {
            c >>= 1
            k += 1
        }
        values[k] = Float.random(in: -1...1)

        var sum: Float = 0
        var amp: Float = 1
        for v in values {
            sum += v * amp
            amp *= gain
        }
        return sum * normalizationFactor * 0.5
    }
}
