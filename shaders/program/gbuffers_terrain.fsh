// ==============================================================================
// gbuffers_terrain — Fragment Shader
// Classifies anime materials (foliage, leaves, polished gems, selective colorful
// emissive pixels) into the 3-buffer G-buffer for deferred lighting.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/constants.glsl"
#include "/lib/common/math.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLmCoord;
in vec4 vColor;
in vec3 vViewNormal;
flat in int vBlockId;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 albedoOut;
layout(location = 1) out vec4 normalMatOut;
layout(location = 2) out vec4 lightExtraOut;

void main() {
    vec4 tex = texture(gtexture, vTexCoord);
    vec4 albedo = tex * vColor;

    if (albedo.a < alphaTestRef) {
        discard;
    }

    vec2 lm = clamp((vLmCoord - 0.03125) / 0.9375, 0.0, 1.0);
    float matId = MAT_DEFAULT;
    float matExtra = 0.0;
    float emissive = 0.0;

    float maxCh = max(tex.r, max(tex.g, tex.b));

    if (vBlockId == 10010 || vBlockId == 10012 || vBlockId == 10013) {
        matId = MAT_FOLIAGE;
    } else if (vBlockId == 10011) {
        matId = MAT_LEAVES;
    } else if (vBlockId == 10030) {
        matId = MAT_POLISHED;
    } else if (vBlockId == 10020) {
        // Warm golden emissives (torches, lanterns, glowstone, froglight, lit copper bulb, candles)
        matId = MAT_EMISSIVE;
        matExtra = EMIS_WARM_GOLD;
        emissive = smoothstep(0.28, 0.72, maxCh) * 0.95;
    } else if (vBlockId == 10021) {
        // Lava, fire, magma cracks
        matId = MAT_EMISSIVE;
        matExtra = EMIS_FIERY_LAVA;
        emissive = smoothstep(0.22, 0.65, tex.r) * 1.15;
    } else if (vBlockId == 10022) {
        // Soul lanterns/fire, sculk, trial spawner, vault
        matId = MAT_EMISSIVE;
        matExtra = EMIS_SOUL_CYAN;
        emissive = smoothstep(0.24, 0.66, max(tex.g, tex.b)) * 1.05;
    } else if (vBlockId == 10023) {
        // Sea lantern, glow lichen, glow berries, verdant froglight
        matId = MAT_EMISSIVE;
        matExtra = EMIS_SEA_AQUA;
        emissive = smoothstep(0.32, 0.75, maxCh) * 0.95;
    } else if (vBlockId == 10024) {
        // Amethyst clusters, crying obsidian, enchanting table, pearlescent froglight, open eyeblossom
        matId = MAT_EMISSIVE;
        matExtra = EMIS_MAGIC_VIOLET;
        float crystalMask = smoothstep(0.28, 0.72, max(tex.r, tex.b));
        emissive = crystalMask * 0.85;
    } else if (vBlockId == 10025) {
        // Ruby redstone torches/ore/dust/blocks
        matId = MAT_EMISSIVE;
        matExtra = EMIS_RUBY_RED;
        emissive = smoothstep(0.18, 0.56, tex.r - tex.g * 0.45) * 0.95;
    } else if (vBlockId == 10026) {
        // End rod, beacon, firefly bush
        matId = MAT_EMISSIVE;
        matExtra = EMIS_STAR_PEARL;
        emissive = smoothstep(0.35, 0.78, maxCh) * 1.10;
    } else if (vBlockId == 10027) {
        matId = MAT_PORTAL_END;
        emissive = 0.85;
    }

    albedoOut     = vec4(albedo.rgb, albedo.a);
    normalMatOut  = vec4(safeNormalize(vViewNormal), matId);
    lightExtraOut = vec4(lm, matExtra, emissive);
}
