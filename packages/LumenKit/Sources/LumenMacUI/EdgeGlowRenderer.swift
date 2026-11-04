#if os(macOS)
    import AppKit
    import LumenDomain
    import MetalKit
    import QuartzCore

    private struct EdgeGlowUniforms {
        var time: Float
        var proximity: Float
        var bandFraction = DesignTokens.Glow.bandFraction
        var intensity = DesignTokens.Glow.intensity
        var flowSpeed = DesignTokens.Glow.flowSpeed
        var noiseScale = DesignTokens.Glow.noiseScale
        var mirrored: Float
        var particleAmount: Float
        var particleCells = DesignTokens.Effects.particleCells
        var particleSpeed = DesignTokens.Effects.particleSpeed
        var padding = SIMD2<Float>(0, 0)
        var primary: SIMD4<Float>
        var secondary: SIMD4<Float>
        var highlight: SIMD4<Float>
    }

    private extension SIMD4<Float> {
        init(color: ColorToken) {
            self.init(color.red, color.green, color.blue, 1)
        }

        init(color: PaletteColor) {
            self.init(color.red, color.green, color.blue, 1)
        }
    }

    @MainActor
    final class EdgeGlowRenderer: NSObject, MTKViewDelegate {
        private static let proximitySmoothing: Float = 0.2
        var proximity: Float = 0
        private var displayedProximity: Float = 0
        var isMirrored = false
        var palette: GlowPalette?
        private let queue: MTLCommandQueue
        private let pipeline: MTLRenderPipelineState
        private let startTime = CACurrentMediaTime()
        private let onGPUTime: @Sendable (Double) -> Void

        init?(device: MTLDevice, pixelFormat: MTLPixelFormat, onGPUTime: @escaping @Sendable (Double) -> Void) {
            guard
                let queue = device.makeCommandQueue(),
                let library = try? device.makeLibrary(source: EdgeGlowShader.source, options: nil)
            else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "edgeGlowVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "edgeGlowFragment")
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            self.queue = queue
            self.pipeline = pipeline
            self.onGPUTime = onGPUTime
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

        func draw(in view: MTKView) {
            guard
                let pass = view.currentRenderPassDescriptor,
                let drawable = view.currentDrawable,
                let buffer = queue.makeCommandBuffer(),
                let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)
            else { return }
            displayedProximity += (proximity - displayedProximity) * Self.proximitySmoothing
            var uniforms = EdgeGlowUniforms(
                time: Float(CACurrentMediaTime() - startTime),
                proximity: displayedProximity,
                mirrored: isMirrored ? 1 : 0,
                particleAmount: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    ? 0
                    : DesignTokens.Effects.particleAmount,
                primary: palette.map { SIMD4(color: $0.primary) } ?? SIMD4(color: DesignTokens.Glow.primary),
                secondary: palette.map { SIMD4(color: $0.secondary) } ?? SIMD4(color: DesignTokens.Glow.secondary),
                highlight: palette.map { SIMD4(color: $0.highlight) } ?? SIMD4(color: DesignTokens.Glow.highlight)
            )
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<EdgeGlowUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            let report = onGPUTime
            buffer.addCompletedHandler { @Sendable completed in
                report((completed.gpuEndTime - completed.gpuStartTime) * 1000)
            }
            buffer.present(drawable)
            buffer.commit()
        }
    }
#endif
