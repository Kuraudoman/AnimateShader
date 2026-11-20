#ifndef ANIMATE_MATH_GLSL
#define ANIMATE_MATH_GLSL

#include "/lib/common/constants.glsl"

// ==============================================================================
// Color Space & Luminance Utilities
// ==============================================================================
float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 srgbToLinear(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 linearToSrgb(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

vec3 adjustSaturation(vec3 c, float sat) {
    float l = luma(c);
    return max(mix(vec3(l), c, sat), vec3(0.0));
}

// Selective vibrance: boosts muted/natural colors while preventing hyper-saturated clipping
vec3 adjustVibrance(vec3 c, float vibrance) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float sat = (maxC > 1e-4) ? (maxC - minC) / maxC : 0.0;
    float boost = mix(vibrance, 1.0 + (vibrance - 1.0) * 0.35, sat);
    return adjustSaturation(c, boost);
}

// ==============================================================================
// Safe Vector & Matrix Helpers
// ==============================================================================
vec3 safeNormalize(vec3 v) {
    float len2 = dot(v, v);
    return (len2 > 1e-8) ? v * inversesqrt(len2) : vec3(0.0, 1.0, 0.0);
}

mat2 rot2D(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

vec3 projectAndDivide(mat4 projMat, vec3 pos) {
    vec4 homo = projMat * vec4(pos, 1.0);
    return homo.xyz / max(abs(homo.w), 1e-6) * (homo.w >= 0.0 ? 1.0 : -1.0);
}

vec3 screenToView(vec2 uv, float depth, mat4 projInv) {
    vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
    return projectAndDivide(projInv, ndc);
}

vec3 viewToScreen(vec3 viewPos, mat4 proj) {
    vec3 ndc = projectAndDivide(proj, viewPos);
    return ndc * 0.5 + 0.5;
}

float linearizeDepth(float depth, float nearPlane, float farPlane) {
    float z = depth * 2.0 - 1.0;
    return (2.0 * nearPlane * farPlane) / max(farPlane + nearPlane - z * (farPlane - nearPlane), 1e-4);
}

// ==============================================================================
// Procedural Noise & Dithering (Zero external textures, zero banding)
// ==============================================================================

// Jorge Jimenez Interleaved Gradient Noise (fast, visually crisp blue-noise-like pattern)
float interleavedGradientNoise(vec2 pixelCoord) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(pixelCoord, magic.xy)));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float valueNoise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);

    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);

    return mix(nxy0, nxy1, u.z);
}

float fbm2D(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.80, 0.60, -0.60, 0.80);
    for (int i = 0; i < 4; i++) {
        v += amp * valueNoise2D(p);
        p = rot * p * 2.03 + vec2(17.1, 31.7);
        amp *= 0.5;
    }
    return v;
}

float fbm3D(vec3 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        v += amp * valueNoise3D(p);
        p = p * 2.02 + vec3(13.7, 29.3, 47.1);
        amp *= 0.5;
    }
    return v;
}

// Smooth minimum for organic blending
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / max(k, 1e-4), 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Vogel Disk Spiral offset for soft shadow PCF
vec2 vogelDiskSample(int index, int sampleCount, float phi) {
    const float GOLDEN_ANGLE = 2.39996323;
    float r = sqrt((float(index) + 0.5) / float(sampleCount));
    float theta = float(index) * GOLDEN_ANGLE + phi;
    return vec2(cos(theta), sin(theta)) * r;
}

#endif
