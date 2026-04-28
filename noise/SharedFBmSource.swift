import Foundation
import QuartzCore

final class SharedFBmSource: @unchecked Sendable {
    let octaves: Int
    let gain: Float
    let normalizationFactor: Float

    private let baseInterval: Double = 1.0 / 44100.0
    private var octaveValues: [Float]
    private var nextUpdateTimes: [Double]
    private let lockPtr: UnsafeMutablePointer<os_unfair_lock>

    init(octaves: Int = 10, gain: Float = 0.5) {
        self.octaves = octaves
        self.gain = gain
        self.lockPtr = .allocate(capacity: 1)
        self.lockPtr.initialize(to: os_unfair_lock())

        let now = CACurrentMediaTime()
        self.octaveValues = (0..<octaves).map { _ in Float.random(in: -1...1) }
        self.nextUpdateTimes = (0..<octaves).map { k in
            now + (1.0 / 44100.0) * pow(2.0, Double(k))
        }

        var sum: Float = 0
        var amp: Float = 1.0
        for _ in 0..<octaves { sum += amp; amp *= gain }
        self.normalizationFactor = 1.0 / sum
    }

    deinit {
        lockPtr.deinitialize(count: 1)
        lockPtr.deallocate()
    }

    func sample(at time: Double) -> Float {
        os_unfair_lock_lock(lockPtr)
        defer { os_unfair_lock_unlock(lockPtr) }
        updateOctaves(to: time)
        return computeValue()
    }

    func octaveSnapshot() -> [Float] {
        os_unfair_lock_lock(lockPtr)
        defer { os_unfair_lock_unlock(lockPtr) }
        return octaveValues
    }

    private func updateOctaves(to time: Double) {
        for k in 0..<octaves {
            let interval = baseInterval * pow(2.0, Double(k))
            while nextUpdateTimes[k] <= time {
                octaveValues[k] = Float.random(in: -1...1)
                nextUpdateTimes[k] += interval
            }
        }
    }

    private func computeValue() -> Float {
        var sum: Float = 0
        var amp: Float = 1.0
        for v in octaveValues {
            sum += v * amp
            amp *= gain
        }
        return sum * normalizationFactor * 0.5
    }
}
