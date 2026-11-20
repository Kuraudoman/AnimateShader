// ==============================================================================
// gbuffers_hand — Fragment Shader
// Tags hand geometry with MAT_HAND so deferred skips fog/SSAO/wrong-depth shadow
// and gently illuminates held torches/lanterns!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

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
    float maxHeld = float(max(heldBlockLightValue, heldBlockLightValue2));
    float emissive = 0.0;
    if (maxHeld > 0.5) {
        float bright = smoothstep(0.45, 0.88, max(albedo.r, max(albedo.g, albedo.b)));
        emissive = bright * (maxHeld / 15.0) * 0.45;
    }

    albedoOut     = albedo;
    normalMatOut  = vec4(safeNormalize(vViewNormal), MAT_HAND);
    lightExtraOut = vec4(lm, EMIS_WARM_GOLD, emissive);
}
