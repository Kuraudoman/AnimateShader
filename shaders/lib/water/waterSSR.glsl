#ifndef ANIMATE_WATER_SSR_GLSL
#define ANIMATE_WATER_SSR_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Screen-Space Reflections (SSR) for Crystal Water & Glossy Ice
// Fast adaptive raymarch + binary refinement with silky screen-edge fade.
// ==============================================================================

vec4 traceAnimeSSR(
    vec3 viewPos,
    vec3 viewNormal,
    float dither,
    sampler2D sceneColorTex,
    sampler2D depthTex,
    mat4 proj,
    mat4 projInv
) {
#ifndef WATER_SSR
    return vec4(0.0);
#else
    vec3 viewDir = safeNormalize(viewPos);
    vec3 reflDir = reflect(viewDir, safeNormalize(viewNormal));

    // Avoid reflecting straight back into the camera where screen info cannot exist
    if (reflDir.z > 0.25) return vec4(0.0);

    const int MAX_STEPS = 24;
    float stepLen = clamp(-viewPos.z * 0.06, 0.35, 2.8);
    vec3 rayPos = viewPos + reflDir * (0.18 + stepLen * dither * 0.5);
    vec3 prevPos = viewPos;

    bool hit = false;
    vec2 hitUV = vec2(0.0);

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 screenP = viewToScreen(rayPos, proj);
        if (screenP.x < 0.002 || screenP.x > 0.998 || screenP.y < 0.002 || screenP.y > 0.998) {
            break;
        }
        if (screenP.z <= 0.0 || screenP.z >= 1.0) {
            break;
        }

        float sceneDepth = texture(depthTex, screenP.xy).r;
        if (sceneDepth < 0.9999 && screenP.z > sceneDepth) {
            vec3 sceneView = screenToView(screenP.xy, sceneDepth, projInv);
            float thickness = abs(rayPos.z - sceneView.z);
            if (thickness < max(stepLen * 2.4, 2.2)) {
                // 4-step binary refinement for crisp reflection edges
                vec3 a = prevPos;
                vec3 b = rayPos;
                for (int j = 0; j < 4; j++) {
                    vec3 mid = 0.5 * (a + b);
                    vec3 midScr = viewToScreen(mid, proj);
                    float midDepth = texture(depthTex, clamp(midScr.xy, vec2(0.001), vec2(0.999))).r;
                    if (midScr.z > midDepth) {
                        b = mid;
                    } else {
                        a = mid;
                    }
                }
                vec3 finalScr = viewToScreen(b, proj);
                hitUV = finalScr.xy;
                hit = true;
                break;
            }
        }

        prevPos = rayPos;
        stepLen *= 1.18;
        rayPos += reflDir * stepLen;
    }

    if (!hit) return vec4(0.0);

    // Smooth vignette fade near screen borders so reflections dissolve cleanly into sky
    vec2 edge = smoothstep(vec2(0.0), vec2(0.12), hitUV) * smoothstep(vec2(1.0), vec2(0.88), hitUV);
    float edgeFade = edge.x * edge.y;
    float backFade = smoothstep(0.25, -0.15, reflDir.z);
    float confidence = clamp(edgeFade * backFade, 0.0, 1.0);

    vec3 reflColor = texture(sceneColorTex, hitUV).rgb;
    return vec4(reflColor, confidence);
#endif
}

#endif
