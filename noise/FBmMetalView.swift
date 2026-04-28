import SwiftUI
import MetalKit

#if os(iOS)
struct FBmMetalView: UIViewRepresentable {
    let source: SharedFBmSource

    func makeCoordinator() -> FBmMetalRenderer {
        FBmMetalRenderer(source: source)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        context.coordinator.setup(device: view.device!)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
#elseif os(macOS)
struct FBmMetalView: NSViewRepresentable {
    let source: SharedFBmSource

    func makeCoordinator() -> FBmMetalRenderer {
        FBmMetalRenderer(source: source)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        context.coordinator.setup(device: view.device!)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
#endif

class FBmMetalRenderer: NSObject, MTKViewDelegate {
    let source: SharedFBmSource
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?

    init(source: SharedFBmSource) {
        self.source = source
    }

    func setup(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
        guard let library = device.makeDefaultLibrary() else { return }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fbmVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "fbmFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipelineState,
              let commandQueue,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else { return }

        let size = view.drawableSize
        var snapshot = source.octaveSnapshot()
        while snapshot.count < 10 { snapshot.append(0) }

        var uniforms: [Float] = [Float(size.width), Float(size.height)]
        uniforms.append(contentsOf: snapshot.prefix(10))

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipelineState)
        uniforms.withUnsafeBytes { ptr in
            encoder.setFragmentBytes(ptr.baseAddress!, length: ptr.count, index: 0)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
