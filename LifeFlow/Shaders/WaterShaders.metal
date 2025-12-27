//
//  WaterShaders.metal
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//  Enhanced with SDF-based liquid physics, refraction, and Fresnel effects.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Signed Distance Functions

/// Rounded box SDF for vessel container
/// p: sample point, b: box half-dimensions, r: corner radius
float sdRoundedBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Vessel-specific SDF with tapered bottom
/// Creates a glass shape wider at top, narrower at bottom
float sdVessel(float2 p, float2 size) {
    // Normalize to -1 to 1 space
    float2 uv = p / size * 2.0;
    
    // Y ranges from -1 (top) to 1 (bottom)
    float y = uv.y;
    
    // Taper: wider at top (y=-1), narrower at bottom (y=1)
    // Top width factor: 1.0, Bottom width factor: 0.7
    float taper = mix(1.0, 0.7, (y + 1.0) * 0.5);
    
    // Adjust x coordinate for taper
    float adjustedX = uv.x / taper;
    
    // Rounded rectangle for the tapered vessel
    float2 boxSize = float2(0.9, 0.95);
    float cornerRadius = 0.15;
    
    return sdRoundedBox(float2(adjustedX, y), boxSize, cornerRadius);
}

/// Liquid plane SDF - defines water surface with tilt
/// Returns signed distance to the water surface plane
float sdLiquidPlane(float2 p, float2 size, float fillLevel, float2 tilt) {
    // Normalize coordinates to 0-1, Y flipped (0 = bottom, 1 = top)
    float2 uv = p / size;
    uv.y = 1.0 - uv.y;
    
    // Construct tilt-adjusted water surface
    // tilt.x = roll (left/right), tilt.y = pitch (forward/back, unused for 2D)
    
    // Water surface height at this X position
    // Negative tilt means device tilted left, water rises on LEFT (x=0)
    // So when x < 0.5, we add to the surface height if tilt is negative
    float tiltEffect = (0.5 - uv.x) * (-tilt.x) * 0.8;
    
    float surfaceHeight = fillLevel + tiltEffect;
    
    // Positive = above water, Negative = below water
    return uv.y - surfaceHeight;
}

// MARK: - Optical Effect Helpers

/// Fresnel approximation (Schlick's approximation)
/// Returns reflection coefficient based on view angle
float fresnelSchlick(float cosTheta, float F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

/// Generate smooth noise for caustics
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// MARK: - Main Water Effect Shader (colorEffect)

[[stitchable]] half4 waterEffect(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float fillLevel,
    float tiltAngle
) {
    // Normalized coordinates
    float2 uv = position / size;
    uv.y = 1.0 - uv.y; // Flip Y: 0 = bottom, 1 = top
    
    // --- SDF-BASED LIQUID CALCULATION ---
    
    // Multi-frequency wave animation for organic water surface
    float wave1 = sin(uv.x * 8.0 + time * 2.5) * 0.018;
    float wave2 = sin(uv.x * 12.0 - time * 1.8) * 0.010;
    float wave3 = sin(uv.x * 20.0 + time * 3.2) * 0.005;
    float totalWave = wave1 + wave2 + wave3;
    
    // Tilt effect using rotation-inspired math
    // Negative tiltAngle = tilted left = water rises on left
    float tiltEffect = (0.5 - uv.x) * (-tiltAngle) * 1.0;
    
    // Water surface with SDF-like smooth edge
    float waterSurface = fillLevel + tiltEffect + totalWave;
    
    // Signed distance to water surface (positive = above, negative = below)
    float liquidSDF = uv.y - waterSurface;
    
    // Smooth anti-aliased edge (SDF-based)
    float edgeSmooth = 0.008; // Pixel-width smoothing
    float waterMask = 1.0 - smoothstep(-edgeSmooth, edgeSmooth, liquidSDF);
    
    // If completely above water, return transparent
    if (waterMask < 0.001) {
        return half4(0.0, 0.0, 0.0, 0.0);
    }
    
    // --- DEPTH CALCULATION ---
    float depth = clamp((waterSurface - uv.y) / max(waterSurface, 0.01), 0.0, 1.0);
    
    // --- WATER COLOR GRADIENT (Ocean Blues) ---
    half3 surfaceColor = half3(0.35, 0.78, 1.0);   // Bright cyan
    half3 midColor = half3(0.12, 0.52, 0.92);      // Clear blue
    half3 deepColor = half3(0.02, 0.22, 0.58);     // Deep ocean
    
    half3 waterColor;
    if (depth < 0.35) {
        float t = depth / 0.35;
        waterColor = mix(surfaceColor, midColor, t);
    } else {
        float t = (depth - 0.35) / 0.65;
        waterColor = mix(midColor, deepColor, t);
    }
    
    // --- CAUSTIC LIGHT PATTERNS (SDF-enhanced) ---
    float caustic1 = sin(uv.x * 28.0 + uv.y * 18.0 + time * 1.6);
    float caustic2 = sin(uv.x * 20.0 - uv.y * 26.0 - time * 1.2);
    float caustic3 = cos(uv.x * 32.0 + uv.y * 14.0 + time * 2.0);
    float caustics = (caustic1 * caustic2 + caustic3) * 0.5 + 0.5;
    caustics = pow(caustics, 4.5) * 0.55;
    
    // Caustics stronger near surface
    caustics *= (1.0 - depth * 0.75);
    waterColor += half3(caustics * 0.45, caustics * 0.55, caustics * 0.35);
    
    // --- FRESNEL EFFECT ---
    // Surface normal approximation (pointing up with tilt adjustment)
    float2 normal = normalize(float2(-tiltEffect * 2.0, 1.0));
    float cosTheta = clamp(dot(normalize(float2(0, 1)), normal), 0.0, 1.0);
    
    // Fresnel: more reflective at edges
    float fresnel = fresnelSchlick(cosTheta, 0.04);
    
    // Edge fresnel based on distance from water surface
    float edgeFresnel = 1.0 - smoothstep(0.0, 0.15, abs(liquidSDF));
    fresnel = max(fresnel, edgeFresnel * 0.3);
    
    // Add subtle reflection/highlight from fresnel
    waterColor += half3(fresnel * 0.15);
    
    // --- SHIMMER EFFECT ---
    float shimmerPos = fract(time * 0.12);
    float shimmerDist = abs(uv.x - shimmerPos);
    float shimmer = exp(-shimmerDist * 12.0) * 0.25 * (1.0 - depth * 0.5);
    waterColor += half3(shimmer);
    
    // --- SURFACE HIGHLIGHT (bright line at water surface) ---
    float surfaceGlow = exp(-abs(liquidSDF) * 80.0) * 0.8;
    waterColor += half3(surfaceGlow * 0.9, surfaceGlow, surfaceGlow * 0.95);
    
    // --- PROCEDURAL BUBBLES ---
    float bubbleNoise = fract(sin(uv.x * 75.0 + floor(time * 0.4) * 19.0) * 1800.0);
    float bubbleY = fract(time * 0.2 + bubbleNoise * 2.5);
    float bubbleDist = length(float2(uv.x - fract(bubbleNoise * 6.0), uv.y - bubbleY * waterSurface * 0.85));
    float bubble = exp(-bubbleDist * 140.0) * step(bubbleNoise, 0.06) * 0.35;
    waterColor += half3(bubble);
    
    // --- DEPTH ATTENUATION ---
    waterColor *= (1.0 - depth * 0.2);
    
    // --- FINAL ALPHA with Fresnel enhancement ---
    float alpha = 0.90 + depth * 0.08 + fresnel * 0.05;
    alpha *= waterMask;
    
    return half4(waterColor, alpha);
}

// MARK: - Glass Refraction Shader (layerEffect)
// This shader can sample the background and apply refraction distortion

[[stitchable]] half4 glassRefraction(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float refractiveIndex,
    float thickness
) {
    float2 uv = position / size;
    
    // Center coordinates for radial calculations
    float2 center = float2(0.5, 0.5);
    float2 fromCenter = uv - center;
    float distFromCenter = length(fromCenter);
    
    // Glass thickness varies - thicker at edges (for vessel shape)
    float edgeThickness = smoothstep(0.0, 0.5, distFromCenter) * thickness;
    
    // Surface normal approximation (pointing outward from center)
    float2 normal = normalize(fromCenter);
    
    // Refraction offset based on Snell's Law approximation
    // η (eta) = refractive index ratio (air/glass ≈ 1/1.5)
    float eta = 1.0 / refractiveIndex;
    float2 offset = normal * (1.0 - eta) * edgeThickness * 0.1;
    
    // --- CHROMATIC ABERRATION ---
    // Sample R, G, B channels at slightly different offsets
    float2 uvR = uv + offset * 1.00;
    float2 uvG = uv + offset * 1.02;
    float2 uvB = uv + offset * 1.04;
    
    // Convert back to pixel coordinates for sampling
    float2 posR = uvR * size;
    float2 posG = uvG * size;
    float2 posB = uvB * size;
    
    half4 colorR = layer.sample(posR);
    half4 colorG = layer.sample(posG);
    half4 colorB = layer.sample(posB);
    
    half4 refractedColor;
    refractedColor.r = colorR.r;
    refractedColor.g = colorG.g;
    refractedColor.b = colorB.b;
    refractedColor.a = (colorR.a + colorG.a + colorB.a) / 3.0;
    
    // --- FRESNEL for glass edges ---
    float cosTheta = 1.0 - distFromCenter * 1.5;
    cosTheta = clamp(cosTheta, 0.0, 1.0);
    float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - cosTheta, 5.0);
    
    // Blend in a subtle glass tint at edges
    half3 glassTint = half3(0.9, 0.95, 1.0);
    refractedColor.rgb = mix(refractedColor.rgb, glassTint, fresnel * 0.3);
    
    // Increase alpha at edges for glass volume
    refractedColor.a = max(refractedColor.a, half(fresnel * 0.4));
    
    return refractedColor;
}
