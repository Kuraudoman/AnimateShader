// ==============================================================================
// gbuffers_water — Vertex Shader
// Handles water (with gentle wave motion), stained glass, ice, slime, honey,
// and glowing Nether portals!
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/waving.glsl"

in vec2 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

out vec2 vTexCoord;
out vec2 vLmCoord;
out vec4 vColor;
out vec3 vViewPos;
out vec3 vWorldPos;
out vec3 vViewNormal;
out vec3 vWorldNormal;
flat out int vBlockId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLmCoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor    = gl_Color;
    vBlockId  = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    vec3 worldPos  = playerPos + cameraPosition;

    vec3 viewNormal  = safeNormalize(gl_NormalMatrix * gl_Normal);
    vec3 worldNormal = safeNormalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);

    // Subtle animated surface wave motion using position-only mask so top and side water faces
    // sharing a vertex move identically (prevents black hairline cracks & corner pinholes on waterfalls)
    if (vBlockId == 10001) {
        float fy = fract(worldPos.y);
        float distFromInt = min(fy, 1.0 - fy);
        float surfaceMask = smoothstep(0.02, 0.06, distFromInt) * clamp(fy * 1.15, 0.0, 1.0);
        if (surfaceMask > 0.001) {
            float waveY = computeWaterVertexWave(worldPos, frameTimeCounter) * surfaceMask;
            playerPos.y += waveY;
            worldPos.y  += waveY;
            viewPos = gbufferModelView * vec4(playerPos, 1.0);
        }
    }

    vViewPos     = viewPos.xyz;
    vWorldPos    = worldPos;
    vViewNormal  = viewNormal;
    vWorldNormal = worldNormal;

    gl_Position = gl_ProjectionMatrix * viewPos;
}
