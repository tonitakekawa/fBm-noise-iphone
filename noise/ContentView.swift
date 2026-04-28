import SwiftUI
import AVFoundation

enum NoiseType: String, CaseIterable {
    case white = "White"
    case fbm = "fBm"
    case syncedFbm = "Synced"
}

struct ContentView: View {
    @State private var activeNoise: NoiseType?
    @State private var audioEngine = AVAudioEngine()
    @State private var sourceNode: AVAudioSourceNode?
    @State private var syncedPlayer: SyncedFBmPlayer?
    @State private var sharedSource: SharedFBmSource?

    var body: some View {
        ZStack {
            if activeNoise == .syncedFbm, let source = sharedSource {
                FBmMetalView(source: source)
                    .ignoresSafeArea()
            }

            VStack(spacing: 32) {
                if activeNoise != .syncedFbm {
                    Image(systemName: activeNoise != nil ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(activeNoise != nil ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))

                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(NoiseType.allCases, id: \.self) { type in
                        let isActive = activeNoise == type
                        Button {
                            if isActive {
                                stopAll()
                            } else {
                                play(type)
                            }
                        } label: {
                            Text(isActive ? "Stop" : type.rawValue)
                                .font(.title3.bold())
                                .frame(minWidth: 80, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isActive ? .red : .blue)
                    }
                }
                .padding()
                .background(
                    activeNoise == .syncedFbm
                        ? AnyShapeStyle(.ultraThinMaterial)
                        : AnyShapeStyle(.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .onDisappear {
            stopAll()
        }
    }

    private var statusText: String {
        guard let noise = activeNoise else { return "Stopped" }
        return "Playing \(noise.rawValue)"
    }

    private func play(_ type: NoiseType) {
        stopAll()
        switch type {
        case .white:
            playSimpleNoise(type: .white)
        case .fbm:
            playSimpleNoise(type: .fbm)
        case .syncedFbm:
            playSynced()
        }
    }

    private func playSimpleNoise(type: NoiseType) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

        let node: AVAudioSourceNode
        switch type {
        case .white:
            node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
                let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let bufL = UnsafeMutableBufferPointer<Float>(bufferList[0])
                let bufR = UnsafeMutableBufferPointer<Float>(bufferList[1])
                for frame in 0..<Int(frameCount) {
                    bufL[frame] = Float.random(in: -0.5...0.5)
                    bufR[frame] = Float.random(in: -0.5...0.5)
                }
                return noErr
            }
        case .fbm:
            let genL = FBmGenerator(octaves: 10, gain: 0.5)
            let genR = FBmGenerator(octaves: 10, gain: 0.5)
            node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
                let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let bufL = UnsafeMutableBufferPointer<Float>(bufferList[0])
                let bufR = UnsafeMutableBufferPointer<Float>(bufferList[1])
                for frame in 0..<Int(frameCount) {
                    bufL[frame] = genL.nextSample()
                    bufR[frame] = genR.nextSample()
                }
                return noErr
            }
        default:
            return
        }

        sourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            activeNoise = type
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func playSynced() {
        let source = SharedFBmSource(octaves: 10, gain: 0.5)
        sharedSource = source

        let player = SyncedFBmPlayer(source: source)
        player.start()
        syncedPlayer = player
        activeNoise = .syncedFbm
    }

    private func stopAll() {
        audioEngine.stop()
        if let node = sourceNode {
            audioEngine.detach(node)
            sourceNode = nil
        }

        syncedPlayer?.stop()
        syncedPlayer = nil
        sharedSource = nil
        activeNoise = nil
    }
}

#Preview {
    ContentView()
}
