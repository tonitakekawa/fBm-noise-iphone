#include <metal_stdlib>
using namespace metal;

struct FBmUniforms {
    float2 resolution;
    float timeOffsets[10];
};

float fbm_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float fbm_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = fbm_hash(i);
    float b = fbm_hash(i + float2(1.0, 0.0));
    float c = fbm_hash(i + float2(0.0, 1.0));
    float d = fbm_hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vertex float4 fbmVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 fbmFragment(
    float4 position [[position]],
    constant FBmUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = position.xy / uniforms.resolution;
    float total = 0.0;
    float amplitude = 1.0;
    float frequency = 4.0;
    float maxVal = 0.0;

    for (int i = 0; i < 8; i++) {
        float2 offset = float2(uniforms.timeOffsets[i], uniforms.timeOffsets[i] * 0.7);
        float2 p = uv * frequency + offset;
        total += fbm_noise(p) * amplitude;
        maxVal += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    total /= maxVal;
    return float4(total, total, total, 1.0);
}
