#if os(macOS)
    enum EdgeGlowShader {
        static let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float time;
            float proximity;
            float bandFraction;
            float intensity;
            float flowSpeed;
            float noiseScale;
            float mirrored;
            float padding;
            float4 primary;
            float4 secondary;
            float4 highlight;
        };

        struct Varyings {
            float4 position [[position]];
            float2 uv;
        };

        vertex Varyings edgeGlowVertex(uint vertexID [[vertex_id]]) {
            float2 uv = float2((vertexID << 1) & 2, vertexID & 2);
            Varyings out;
            out.position = float4(uv * float2(2, -2) + float2(-1, 1), 0, 1);
            out.uv = uv;
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

        static float fbm(float2 p) {
            float value = 0;
            float amplitude = 0.5;
            for (int octave = 0; octave < 4; octave++) {
                value += amplitude * noise(p);
                p *= 2.02;
                amplitude *= 0.5;
            }
            return value;
        }

        fragment float4 edgeGlowFragment(Varyings in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
            float distanceToEdge = u.mirrored > 0.5 ? in.uv.x : 1 - in.uv.x;
            float band = max(u.bandFraction * u.proximity, 0.001);
            float flow = fbm(float2(in.uv.y * u.noiseScale, distanceToEdge * u.noiseScale - u.time * u.flowSpeed));
            float falloff = exp(-distanceToEdge / (band * (0.5 + flow)));
            float stripFade = 1 - smoothstep(0.6, 1.0, distanceToEdge);
        float alpha = saturate(u.intensity * u.proximity * falloff) * stripFade;
            float3 color = mix(u.primary.rgb, u.secondary.rgb, flow);
            color = mix(color, u.highlight.rgb, falloff * falloff * 0.6);
            return float4(color * alpha, alpha);
        }
        """
    }
#endif
