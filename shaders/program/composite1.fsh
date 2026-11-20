// ==============================================================================
// Composite Pass 1 — Bloom Bright-Pass Karis Downsample (Full -> Half colortex5)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 bloomOut;

void main() {
    vec2 fullTexel = 1.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec3 bright = bloomBrightPassDownsample(colortex0, vTexCoord, fullTexel);
    bloomOut = vec4(bright, 1.0);
}
