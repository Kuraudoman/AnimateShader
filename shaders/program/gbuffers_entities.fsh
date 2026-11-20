// ==============================================================================
// gbuffers_entities — Fragment Shader
// Preserves entity hit/creeper flash (entityColor) and crisp readable nametags.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;
uniform vec4 entityColor;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLmCoord;
in vec4 vColor;
in vec3 vViewNormal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 albedoOut;
layout(location = 1) out vec4 normalMatOut;
layout(location = 2) out vec4 lightExtraOut;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    if (albedo.a < alphaTestRef) {
        discard;
    }

    // Apply vanilla hit-flash / creeper charge flash
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);

    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    float matId = MAT_ENTITY;
    float emissive = 0.0;

    // Keep fullbright glowing entities (glow squid, blaze, allay, magma cube, nametags) vivid
    if (lm.x > 0.96 && lm.y > 0.96) {
        emissive = 0.45;
    }

    albedoOut     = albedo;
    normalMatOut  = vec4(safeNormalize(vViewNormal), matId);
    lightExtraOut = vec4(lm, EMIS_STAR_PEARL, emissive);
}
