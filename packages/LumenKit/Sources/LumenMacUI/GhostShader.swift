#if os(macOS)
    enum GhostShader {
        static let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float2 center;
            float2 viewport;
            float size;
            float rotation;
            float condensation;
            float hasTexture;
            float4 glow;
            float grainAmount;
            float bloom;
            float refraction;
            float progress;
            float wavelength;
            float intensity;
        };

        struct Varyings {
            float4 position [[position]];
            float2 uv;
        };

        vertex Varyings ghostVertex(uint vertexID [[vertex_id]], constant Uniforms &u [[buffer(0)]]) {
            float2 corner = float2(vertexID & 1, (vertexID >> 1) & 1);
            float2 local = (corner - 0.5) * u.size;
            float c = cos(u.rotation);
            float s = sin(u.rotation);
            float2 pixel = u.center + float2(local.x * c - local.y * s, local.x * s + local.y * c);
            Varyings out;
            out.position = float4(pixel.x / u.viewport.x * 2 - 1, 1 - pixel.y / u.viewport.y * 2, 0, 1);
            out.uv = corner;
            return out;
        }

        static float hash(float2 p) {
            return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
        }

        static float noise(float2 p) {
            float2 cell = floor(p);
            float2 f = fract(p);
            float2 u = f * f * (3 - 2 * f);
            return mix(mix(hash(cell), hash(cell + float2(1, 0)), u.x),
                       mix(hash(cell + float2(0, 1)), hash(cell + float2(1, 1)), u.x), u.y);
        }

        fragment float4 ghostFragment(
            Varyings in [[stage_in]],
            constant Uniforms &u [[buffer(0)]],
            texture2d<float> image [[texture(0)]]
        ) {
            constexpr sampler linear(filter::linear);
            float2 fromCenter = abs(in.uv - 0.5) * 2;
            float corner = 1 - smoothstep(0.86, 1.0, length(max(fromCenter - 0.86, 0.0)) / 0.14);
            float grain = mix(0.5, noise(in.uv * 18) * 0.6 + noise(in.uv * 41) * 0.4, u.grainAmount);
            float solid = smoothstep(grain - 0.12, grain + 0.12, u.condensation);
            float3 photo = u.hasTexture > 0.5 ? image.sample(linear, in.uv).rgb : u.glow.rgb;
            float rim = solid * (1 - solid) * 4;
            float3 color = mix(u.glow.rgb, photo, solid) + u.glow.rgb * rim * u.bloom;
            float alpha = corner * max(solid, 0.45 * (1 - solid));
            return float4(color * alpha, alpha);
        }

        fragment float4 rippleFragment(
            Varyings in [[stage_in]],
            constant Uniforms &u [[buffer(0)]],
            texture2d<float> screen [[texture(0)]]
        ) {
            constexpr sampler linear(filter::linear, address::clamp_to_edge);
            float2 offset = (in.uv - 0.5) * u.size;
            float reach = length(offset);
            float edgeFade = 1 - smoothstep(0.35 * u.size, 0.5 * u.size, reach);
            float phase = (reach - u.progress * 0.5 * u.size) / u.wavelength;
            float packet = exp(-phase * phase * 0.22);
            float crest = pow(0.5 + 0.5 * cos(phase * 6.2832), 3.0);
            float decay = (1 - u.progress) * (1 - u.progress);
            float light = saturate(u.intensity * packet * crest * decay * edgeFade);
            float3 color = mix(u.glow.rgb, float3(1), crest * 0.5);
            if (u.hasTexture < 0.5) {
                return float4(color * light, light);
            }
            float2 direction = reach > 0 ? offset / reach : float2(0);
            float bend = sin(phase * 6.2832) * packet * decay * u.refraction;
            float3 water = screen.sample(linear, (in.position.xy - direction * bend) / u.viewport).rgb;
            float waterAlpha = saturate(packet * decay * 2) * edgeFade;
            return float4(water * waterAlpha * (1 - light) + color * light, waterAlpha + light * (1 - waterAlpha));
        }

        fragment float4 lensFragment(
            Varyings in [[stage_in]],
            constant Uniforms &u [[buffer(0)]],
            texture2d<float> screen [[texture(0)]]
        ) {
            constexpr sampler linear(filter::linear, address::clamp_to_edge);
            float2 fromCenter = (in.uv - 0.5) * 2;
            float reach = length(fromCenter);
            float mask = 1 - smoothstep(0.75, 1.0, reach);
            float2 direction = reach > 0 ? fromCenter / reach : float2(0);
            float bend = u.refraction * sin(saturate(reach) * M_PI_F);
            float2 target = (in.position.xy - direction * bend) / u.viewport;
            return float4(screen.sample(linear, target).rgb * mask, mask);
        }
        """
    }
#endif
