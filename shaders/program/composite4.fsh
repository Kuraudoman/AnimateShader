// ==============================================================================
// Composite Pass 4 — Wide Kawase Bloom Downsample (Half -> Quarter colortex7)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex5;
uniform float viewWidth;
uniform float viewHeight;

in vec2 vTexCoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 bloomOut;

void main() {
    vec2 halfTexel = 2.0 / max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec3 wide = bloomWideDownsample(colortex5, vTexCoord, halfTexel);
    bloomOut = vec4(wide, 1.0);
}
