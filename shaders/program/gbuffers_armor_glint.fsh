// ==============================================================================
// gbuffers_armor_glint — Fragment Shader
// Writes iridescent violet-cyan anime enchantment glow additively into colortex3
// without corrupting normals or lightmaps!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;
uniform float frameTimeCounter;

in vec2 vTexCoord;
in vec4 vColor;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 glowOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    float intensity = luma(tex.rgb) * tex.a;
    if (intensity < 0.01) discard;

    // Subtle iridescent anime prism shimmer across enchantment sheen
    float wave = sin(vTexCoord.x * 12.0 + vTexCoord.y * 8.0 + frameTimeCounter * 2.2) * 0.5 + 0.5;
    vec3 tint = mix(vec3(0.88, 0.52, 1.45), vec3(0.45, 0.95, 1.45), wave);
    vec3 glint = srgbToLinear(tex.rgb) * tint * (1.35 * EMISSIVE_GLOW);

    glowOut = vec4(glint, clamp(tex.a, 0.0, 1.0));
}
