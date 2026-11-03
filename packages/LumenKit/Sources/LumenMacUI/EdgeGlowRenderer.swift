#if os(macOS)
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
        var padding: Float = 0
        var primary = SIMD4(color: DesignTokens.Glow.primary)
        var secondary = SIMD4(color: DesignTokens.Glow.secondary)
        var highlight = SIMD4(color: DesignTokens.Glow.highlight)
    }

    private extension SIMD4<Float> {
        init(color: ColorToken) {
            self.init(color.red, color.green, color.blue, 1)
        }
    }

    @MainActor
    final class EdgeGlowRenderer: NSObject, MTKViewDelegate {
        var proximity: Float = 0
        var isMirrored = false
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
            var uniforms = EdgeGlowUniforms(
                time: Float(CACurrentMediaTime() - startTime),
                proximity: proximity,
                mirrored: isMirrored ? 1 : 0
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
