// ==============================================================================
// Shadow Pass — Vertex Shader
// Synchronizes foliage waving with gbuffers_terrain and applies non-linear
// shadow distortion for crisp near-player shadows.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/shadowDistort.glsl"
#include "/lib/common/waving.glsl"

in vec2 mc_Entity;
in vec2 mc_midTexCoord;

uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

out vec2 vTexCoord;
out vec4 vColor;
flat out int vBlockId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor = gl_Color;
    vBlockId = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    // Apply synchronized foliage waving in world space so shadows move with leaves
    if (vBlockId >= 10010 && vBlockId <= 10013) {
        vec3 playerPos = (shadowModelViewInverse * viewPos).xyz;
        vec3 worldPos = playerPos + cameraPosition;
        vec3 waveOffset = computeFoliageWaveOffset(worldPos, vBlockId, vTexCoord, mc_midTexCoord, frameTimeCounter, rainStrength);
        playerPos += waveOffset;
        viewPos = shadowModelView * vec4(playerPos, 1.0);
    }

    vec4 clipPos = gl_ProjectionMatrix * viewPos;
    clipPos.xyz = distortShadowClipPos(clipPos.xyz);
    gl_Position = clipPos;
}
