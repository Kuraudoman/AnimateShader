// ==============================================================================
// gbuffers_terrain — Vertex Shader
// Handles static blocks, cutout foliage with wind waving, and block IDs.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/waving.glsl"

in vec2 mc_Entity;
in vec2 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

out vec2 vTexCoord;
out vec2 vLmCoord;
out vec4 vColor;
out vec3 vViewNormal;
flat out int vBlockId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmCoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor    = gl_Color;
    vViewNormal = safeNormalize(gl_NormalMatrix * gl_Normal);
    vBlockId  = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    // Gentle wind sway for grass, flowers, crops, leaves, cherry blossoms, vines, kelp
    if (vBlockId >= 10010 && vBlockId <= 10013) {
        vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
        vec3 worldPos = playerPos + cameraPosition;
        vec3 waveOffset = computeFoliageWaveOffset(worldPos, vBlockId, vTexCoord, mc_midTexCoord, frameTimeCounter, rainStrength);
        playerPos += waveOffset;
        viewPos = gbufferModelView * vec4(playerPos, 1.0);
    }

    gl_Position = gl_ProjectionMatrix * viewPos;
}
