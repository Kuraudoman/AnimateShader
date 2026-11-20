// ==============================================================================
// Composite Pass 5 — Multi-Scale Tent Upsample & Combine (Tight + Wide Bloom)
// Reads colortex5 (half) & colortex7 (quarter) -> Writes half-res colortex6
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 bloomOut;

void main() {
    vec2 quarterTexel = 4.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec3 combined = bloomCombineMultiScale(colortex5, colortex7, vTexCoord, quarterTexel);
    bloomOut = vec4(combined, 1.0);
}
