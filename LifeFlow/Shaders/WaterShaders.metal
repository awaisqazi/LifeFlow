#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Sum-of-sines surface model for turbulent but stable liquid motion.
static inline float waveHeight(float x, float time, float tilt) {
    float y = sin(x * 3.0 + time * 1.5 + tilt * 2.0) * 0.05;
    y += sin(x * 7.0 - time * 1.0) * 0.02;
    y += sin(x * 15.0 + time * 3.0) * 0.005;
    return y;
}

[[stitchable]] half4 waterEffect(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float fillLevel,
    float tiltAngle
) {
    float2 safeSize = max(size, float2(1.0, 1.0));
    float2 uv = position / safeSize;
    float clampedFill = clamp(fillLevel, 0.0, 1.0);

    // In UV space y=0 is top, y=1 is bottom.
    float surfaceLevel = (1.0 - clampedFill) + (uv.x - 0.5) * tiltAngle * 0.3;
    float currentLevel = surfaceLevel + waveHeight(uv.x, time, tiltAngle);

    // Water body.
    if (uv.y > currentLevel) {
        float depthRange = max(0.0001, 1.0 - currentLevel);
        float depth = clamp((uv.y - currentLevel) / depthRange, 0.0, 1.0);

        half3 deepColor = half3(0.0, 0.1, 0.4);
        half3 waterColor = mix(color.rgb, deepColor, half(depth * 0.6));

        // Rim/specular light near the surface.
        float grad = waveHeight(uv.x + 0.01, time, tiltAngle) - waveHeight(uv.x - 0.01, time, tiltAngle);
        float rim = smoothstep(0.0, 0.1, grad + 0.02) * (1.0 - depth * 5.0);

        return half4(waterColor + half(rim * 0.4), 0.9);
    }

    // Foam edge.
    float foamThickness = 0.015;
    if (uv.y > currentLevel - foamThickness) {
        float alpha = smoothstep(currentLevel - foamThickness, currentLevel, uv.y) * 0.6;
        return half4(1.0, 1.0, 1.0, half(alpha));
    }

    // Air.
    return half4(0.0, 0.0, 0.0, 0.0);
}

[[stitchable]] half4 glassRefraction(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float refractiveIndex,
    float thickness
) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float2 center = float2(0.5, 0.5);
    float2 fromCenter = uv - center;
    float distFromCenter = length(fromCenter);

    float edgeThickness = smoothstep(0.0, 0.5, distFromCenter) * thickness;
    float2 normal = normalize(fromCenter + 0.0001);
    float eta = 1.0 / max(refractiveIndex, 1.0);
    float2 offset = normal * (1.0 - eta) * edgeThickness * 0.1;

    float2 posR = (uv + offset * 1.00) * size;
    float2 posG = (uv + offset * 1.02) * size;
    float2 posB = (uv + offset * 1.04) * size;

    half4 colorR = layer.sample(posR);
    half4 colorG = layer.sample(posG);
    half4 colorB = layer.sample(posB);

    half4 refractedColor;
    refractedColor.r = colorR.r;
    refractedColor.g = colorG.g;
    refractedColor.b = colorB.b;
    refractedColor.a = (colorR.a + colorG.a + colorB.a) / 3.0;

    float cosTheta = clamp(1.0 - distFromCenter * 1.5, 0.0, 1.0);
    float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - cosTheta, 5.0);

    half3 glassTint = half3(0.9, 0.95, 1.0);
    refractedColor.rgb = mix(refractedColor.rgb, glassTint, half(fresnel * 0.3));

    return refractedColor;
}
