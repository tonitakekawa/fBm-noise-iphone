import AVFoundation
import QuartzCore

class SyncedFBmPlayer {
    let source: SharedFBmSource
    private var audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    init(source: SharedFBmSource) {
        self.source = source
    }

    func start() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let source = self.source

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let bufL = UnsafeMutableBufferPointer<Float>(bufferList[0])
            let bufR = UnsafeMutableBufferPointer<Float>(bufferList[1])

            let now = CACurrentMediaTime()
            let sampleDuration = 1.0 / 44100.0

            for frame in 0..<Int(frameCount) {
                let t = now + Double(frame) * sampleDuration
                let sample = source.sample(at: t)
                bufL[frame] = sample + Float.random(in: -0.05...0.05)
                bufR[frame] = sample + Float.random(in: -0.05...0.05)
            }
            return noErr
        }

        sourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        audioEngine.stop()
        if let node = sourceNode {
            audioEngine.detach(node)
            sourceNode = nil
        }
    }
}
