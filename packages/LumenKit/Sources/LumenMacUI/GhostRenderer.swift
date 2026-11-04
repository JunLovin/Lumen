#if os(macOS)
    import AppKit
    import IOSurface
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
        var grainAmount: Float
        var bloom: Float
        var refraction: Float
        var progress: Float = 0
        var wavelength: Float = 0
        var intensity: Float = 0
    }

    private struct Ripple {
        let center: MacPoint
        let startedAt: CFTimeInterval
        let onFinished: () -> Void
    }

    @MainActor
    final class GhostRenderer: NSObject, MTKViewDelegate {
        var texture: MTLTexture?
        var palette: GlowPalette?
        var tuning = MotionTuning()
        var lensSurface: (() -> IOSurfaceRef?)?
        var nextPose: (() -> GhostPose?)?
        private let queue: MTLCommandQueue
        private let pipeline: MTLRenderPipelineState
        private let lensPipeline: MTLRenderPipelineState
        private let ripplePipeline: MTLRenderPipelineState
        private var ripple: Ripple?
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
            descriptor.fragmentFunction = library.makeFunction(name: "lensFragment")
            guard let lensPipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            descriptor.fragmentFunction = library.makeFunction(name: "rippleFragment")
            guard let ripplePipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            self.ripplePipeline = ripplePipeline
            self.queue = queue
            self.pipeline = pipeline
            self.lensPipeline = lensPipeline
            fallbackTexture = device.makeTexture(descriptor: .texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: 1,
                height: 1,
                mipmapped: false
            ))
        }

        func playRipple(at center: MacPoint, onFinished: @escaping () -> Void) {
            ripple = Ripple(center: center, startedAt: CACurrentMediaTime(), onFinished: onFinished)
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
            drawRipple(in: view, with: encoder)
            if let pose {
                draw(pose, in: view, with: encoder)
            }
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }

        private func draw(_ pose: GhostPose, in view: MTKView, with encoder: MTLRenderCommandEncoder) {
            let scale = Float(view.drawableSize.width / max(view.bounds.width, 1))
            var uniforms = GhostUniforms(
                center: SIMD2(Float(pose.center.x), Float(pose.center.y)) * scale,
                viewport: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                size: Float(pose.size) * scale,
                rotation: Float(pose.rotation),
                condensation: Float(pose.condensation),
                hasTexture: texture == nil ? 0 : 1,
                glow: glow,
                grainAmount: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 1,
                bloom: tuning.bloom,
                refraction: DesignTokens.Lens.refractionPoints * scale
            )
            drawLens(uniforms, in: view, with: encoder)
            let length = MemoryLayout<GhostUniforms>.stride
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentTexture(texture ?? fallbackTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        private var glow: SIMD4<Float> {
            let token = DesignTokens.Glow.primary
            return palette.map { SIMD4($0.primary.red, $0.primary.green, $0.primary.blue, 1) }
                ?? SIMD4(token.red, token.green, token.blue, 1)
        }

        private func drawRipple(in view: MTKView, with encoder: MTLRenderCommandEncoder) {
            guard let ripple else { return }
            let progress = Float(CACurrentMediaTime() - ripple.startedAt) / tuning.rippleSeconds
            guard progress < 1 else {
                self.ripple = nil
                ripple.onFinished()
                return
            }
            let scale = Float(view.drawableSize.width / max(view.bounds.width, 1))
            let screen = screenTexture(of: view)
            var uniforms = GhostUniforms(
                center: SIMD2(Float(ripple.center.x), Float(ripple.center.y)) * scale,
                viewport: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                size: tuning.rippleMacRadius * 2 * scale,
                rotation: 0,
                condensation: 0,
                hasTexture: screen == nil ? 0 : 1,
                glow: glow,
                grainAmount: 0,
                bloom: 0,
                refraction: DesignTokens.Lens.refractionPoints * scale,
                progress: progress,
                wavelength: tuning.rippleWavelength * scale,
                intensity: tuning.rippleIntensity
            )
            let length = MemoryLayout<GhostUniforms>.stride
            encoder.setRenderPipelineState(ripplePipeline)
            encoder.setVertexBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentTexture(screen ?? fallbackTexture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        private func screenTexture(of view: MTKView) -> MTLTexture? {
            guard let surface = lensSurface?(), let device = view.device else { return nil }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: IOSurfaceGetWidth(surface),
                height: IOSurfaceGetHeight(surface),
                mipmapped: false
            )
            return device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
        }

        private func drawLens(_ ghost: GhostUniforms, in view: MTKView, with encoder: MTLRenderCommandEncoder) {
            guard let screen = screenTexture(of: view) else { return }
            var uniforms = ghost
            uniforms.size = ghost.size * DesignTokens.Lens.radiusFraction * 2
            uniforms.rotation = 0
            let length = MemoryLayout<GhostUniforms>.stride
            encoder.setRenderPipelineState(lensPipeline)
            encoder.setVertexBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentBytes(&uniforms, length: length, index: 0)
            encoder.setFragmentTexture(screen, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
    }
#endif
