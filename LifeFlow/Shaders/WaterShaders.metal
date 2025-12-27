//
//  WaterShaders.metal
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Water Surface Shader
// Creates a dynamic, fluid water effect with waves, caustics, and tilt response

[[stitchable]] half4 waterEffect(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float fillLevel,
    float tiltAngle
) {
    // Normalize coordinates to 0-1 range
    float2 uv = position / size;
    
    // Flip Y so 0 is bottom, 1 is top
    uv.y = 1.0 - uv.y;
    
    // Multi-frequency wave animation for organic movement
    float wave1 = sin(uv.x * 8.0 + time * 2.5) * 0.02;
    float wave2 = sin(uv.x * 12.0 - time * 1.8) * 0.012;
    float wave3 = sin(uv.x * 20.0 + time * 3.2) * 0.006;
    float totalWave = wave1 + wave2 + wave3;
    
    // Tilt effect - INVERTED for correct gravity simulation
    // When tilting left (negative angle from CoreMotion), water should rise on LEFT
    // Negate tiltAngle to correct the direction
    float tiltEffect = (0.5 - uv.x) * (-tiltAngle) * 1.0;
    
    // Water surface line
    float waterSurface = fillLevel + tiltEffect + totalWave;
    
    // Check if we're below water surface
    if (uv.y > waterSurface) {
        return half4(0.0, 0.0, 0.0, 0.0); // Transparent above water
    }
    
    // Depth from surface (0 at surface, increases toward bottom)
    float depth = (waterSurface - uv.y) / waterSurface;
    depth = clamp(depth, 0.0, 1.0);
    
    // --- WATER COLOR GRADIENT ---
    // Natural ocean blues: surface bright cyan, deep dark blue
    half3 surfaceColor = half3(0.3, 0.75, 1.0);   // Bright cyan
    half3 midColor = half3(0.1, 0.5, 0.9);        // Clear blue
    half3 deepColor = half3(0.0, 0.2, 0.55);      // Deep ocean
    
    // Smooth blend based on depth
    half3 waterColor;
    if (depth < 0.4) {
        float t = depth / 0.4;
        waterColor = mix(surfaceColor, midColor, t);
    } else {
        float t = (depth - 0.4) / 0.6;
        waterColor = mix(midColor, deepColor, t);
    }
    
    // --- CAUSTIC LIGHT PATTERNS ---
    // Creates the beautiful dancing light effect seen in real water
    float caustic1 = sin(uv.x * 30.0 + uv.y * 20.0 + time * 1.8);
    float caustic2 = sin(uv.x * 22.0 - uv.y * 28.0 - time * 1.4);
    float caustic3 = cos(uv.x * 35.0 + uv.y * 15.0 + time * 2.2);
    float caustics = (caustic1 * caustic2 + caustic3) * 0.5 + 0.5;
    caustics = pow(caustics, 4.0) * 0.5; // Sharpen peaks
    
    // Caustics stronger near surface, fade with depth
    caustics *= (1.0 - depth * 0.8);
    
    // Add caustics as bright highlights
    waterColor += half3(caustics * 0.4, caustics * 0.5, caustics * 0.3);
    
    // --- SHIMMER EFFECT ---
    // Moving highlight band across water
    float shimmerPos = fract(time * 0.15);
    float shimmerDist = abs(uv.x - shimmerPos);
    float shimmer = exp(-shimmerDist * 15.0) * 0.3 * (1.0 - depth * 0.5);
    waterColor += half3(shimmer);
    
    // --- SURFACE HIGHLIGHT ---
    // Bright glow right at water line
    float surfaceDist = abs(uv.y - waterSurface);
    float surfaceGlow = exp(-surfaceDist * 100.0) * 0.7;
    waterColor += half3(surfaceGlow * 0.8, surfaceGlow, surfaceGlow * 0.9);
    
    // --- BUBBLE HINTS ---
    // Procedural bubble-like bright spots
    float bubbleNoise = fract(sin(uv.x * 80.0 + floor(time * 0.5) * 17.0) * 2000.0);
    float bubbleY = fract(time * 0.25 + bubbleNoise * 3.0);
    float bubbleDist = length(float2(uv.x - fract(bubbleNoise * 7.0), uv.y - bubbleY * waterSurface * 0.9));
    float bubble = exp(-bubbleDist * 150.0) * step(bubbleNoise, 0.08) * 0.4;
    waterColor += half3(bubble);
    
    // --- DEPTH DARKENING ---
    // Natural light absorption in water
    waterColor *= (1.0 - depth * 0.25);
    
    // Final alpha (slightly translucent at surface for glass feel)
    float alpha = 0.88 + depth * 0.1;
    
    return half4(waterColor, alpha);
}
