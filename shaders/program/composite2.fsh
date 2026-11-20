// ==============================================================================
// Composite Pass 2 — Horizontal Separable Bloom Blur + Anamorphic Streak
// Reads half-res colortex5 -> Writes half-res colortex6
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex5;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 bloomOut;

void main() {
    vec2 halfTexel = 2.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec3 blurred = bloomSeparableBlur(colortex5, vTexCoord, vec2(halfTexel.x, 0.0), true);
    bloomOut = vec4(blurred, 1.0);
}
