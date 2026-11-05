#if os(macOS)
    import LumenDomain
    import MetalKit

    private struct GhostUniforms {
        var center: SIMD2<Float>
        var viewport: SIMD2<Float>
        var size: Float
        var rotation: Float
        var condensation: Float
        var hasTexture: Float
        var glow: SIMD4<Float>
    }

    @MainActor
    final class GhostRenderer: NSObject, MTKViewDelegate {
        var texture: MTLTexture?
        var nextPose: (() -> GhostPose?)?
        private let queue: MTLCommandQueue
        private let pipeline: MTLRenderPipelineState
        private let fallbackTexture: MTLTexture?

        init?(device: MTLDevice, pixelFormat: MTLPixelFormat) {
            guard
                let queue = device.makeCommandQueue(),
                let library = try? device.makeLibrary(source: GhostShader.source, options: nil)
            else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "ghostVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "ghostFragment")
            let attachment = descriptor.colorAttachments[0]
            attachment?.pixelFormat = pixelFormat
            attachment?.isBlendingEnabled = true
            attachment?.sourceRGBBlendFactor = .one
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.sourceAlphaBlendFactor = .one
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            self.queue = queue
            self.pipeline = pipeline
            fallbackTexture = device.makeTexture(descriptor: .texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: 1,
                height: 1,
                mipmapped: false
            ))
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

        func draw(in view: MTKView) {
            let pose = nextPose?()
            guard
                let pass = view.currentRenderPassDescriptor,
                let drawable = view.currentDrawable,
                let buffer = queue.makeCommandBuffer(),
                let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)
            else { return }
            if let pose {
                draw(pose, in: view, with: encoder)
            }
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }

        private func draw(_ pose: GhostPose, in view: MTKView, with encoder: MTLRenderCommandEncoder) {
            let scale = Float(view.drawableSize.width / max(view.bounds.width, 1))
            let token = DesignTokens.Glow.primary
            var uniforms = GhostUniforms(
                center: SIMD2(Float(pose.center.x), Float(pose.center.y)) * scale,
                viewport: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                size: Float(pose.size) * scale,
                rotation: Float(pose.rotation),
                condensation: Float(pose.condensation),
                hasTexture: texture == nil ? 0 : 1,
                glow: SIMD4(token.red, token.green, token.blue, 1)
            )
            let length = MemoryLayout<GhostUniforms>.stride
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentTexture(texture ?? fallbackTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
    }
#endif
