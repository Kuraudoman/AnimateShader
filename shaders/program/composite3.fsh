// ==============================================================================
// Composite Pass 3 — Vertical Separable Bloom Blur (Tight Silky Inner Halo)
// Reads half-res colortex6 -> Writes half-res colortex5
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex6;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 bloomOut;

void main() {
    vec2 halfTexel = 2.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec3 blurred = bloomSeparableBlur(colortex6, vTexCoord, vec2(0.0, halfTexel.y), false);
    bloomOut = vec4(blurred, 1.0);
}
