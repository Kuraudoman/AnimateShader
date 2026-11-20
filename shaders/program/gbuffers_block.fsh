// ==============================================================================
// gbuffers_block — Fragment Shader
// Supports signs (including glowing signs), chests, conduits, and End portals.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform int blockEntityId;

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

    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    float matId = MAT_BLOCK_ENT;
    float matExtra = 0.0;
    float emissive = 0.0;

    if (blockEntityId == 10027) {
        // Cosmic swirling End Portal / End Gateway!
        matId = MAT_PORTAL_END;
        emissive = 0.9;
    } else if (blockEntityId == 10023) {
        matId = MAT_EMISSIVE;
        matExtra = EMIS_SEA_AQUA;
        emissive = 0.75;
    } else if (blockEntityId == 10024) {
        matId = MAT_EMISSIVE;
        matExtra = EMIS_MAGIC_VIOLET;
        emissive = smoothstep(0.30, 0.75, max(albedo.r, albedo.b)) * 0.55;
    } else if (blockEntityId == 10026) {
        matId = MAT_EMISSIVE;
        matExtra = EMIS_STAR_PEARL;
        emissive = 0.85;
    } else if (lm.x > 0.95 && lm.y > 0.95) {
        // Glowing sign text (max block & sky lightmap)
        emissive = 0.55;
        matExtra = EMIS_STAR_PEARL;
    }

    albedoOut     = albedo;
    normalMatOut  = vec4(safeNormalize(vViewNormal), matId);
    lightExtraOut = vec4(lm, matExtra, emissive);
}
