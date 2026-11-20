#ifndef ANIMATE_WATER_SSR_GLSL
#define ANIMATE_WATER_SSR_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Screen-Space Reflections (SSR) for Crystal Water & Glossy Ice
// Perspective screen-space stepping + above-water depth validation (rejects
// underwater seabed hits!) + binary search refinement for silky continuous
// reflections with ZERO shattered/floating block artifacts.
// ==============================================================================

vec4 traceAnimeSSR(
    vec3 viewPos,
    vec3 viewNormal,
    float dither,
    sampler2D sceneColorTex,
    sampler2D depthAllTex,
    sampler2D depthOpaqueTex,
    mat4 proj,
    mat4 projInv,
    mat4 modelViewInv,
    bool rejectBelowSurface
) {
#ifndef WATER_SSR
    return vec4(0.0);
#else
    vec3 viewDir = safeNormalize(viewPos);
    vec3 nView   = safeNormalize(viewNormal);

    // Compute reflection direction in world space and clamp upward on water so wave troughs
    // never reflect downward into the underwater seabed!
    vec3 worldViewDir = safeNormalize((modelViewInv * vec4(viewDir, 0.0)).xyz);
    vec3 worldNorm    = safeNormalize((modelViewInv * vec4(nView, 0.0)).xyz);
    vec3 worldRefl    = reflect(worldViewDir, worldNorm);
    if (rejectBelowSurface && worldRefl.y < 0.005) {
        worldRefl.y = abs(worldRefl.y) * 0.35 + 0.005;
        worldRefl = safeNormalize(worldRefl);
    }

    // Transform reflection back to view space via transpose of upper-left 3x3
    // (gbufferModelViewInverse is rigid rotation, so transpose == inverse)
    vec3 reflDir = safeNormalize(transpose(mat3(modelViewInv)) * worldRefl);

    // Avoid reflecting straight back behind the camera
    if (reflDir.z > 0.15) return vec4(0.0);

    // Compute perspective-correct ray endpoints in screen space
    float maxRayDist = clamp(-viewPos.z * 2.5 + 32.0, 24.0, 140.0);
    // Clip ray length so it never crosses behind the near plane (z > -0.1)
    if (reflDir.z > 0.001) {
        maxRayDist = min(maxRayDist, (-viewPos.z - 0.15) / reflDir.z);
    }
    if (maxRayDist <= 0.5) return vec4(0.0);

    vec3 startView = viewPos + nView * 0.04;
    vec3 endView   = startView + reflDir * maxRayDist;

    vec3 startScr = viewToScreen(startView, proj);
    vec3 endScr   = viewToScreen(endView, proj);

    vec3 rayDelta = endScr - startScr;
    float screenLen = length(rayDelta.xy);
    if (screenLen < 0.002) return vec4(0.0);

    // Normalize screen travel so we march cleanly across the visible viewport
    float clipScale = 1.0;
    if (rayDelta.x > 1e-5)  clipScale = min(clipScale, (1.0 - startScr.x) / rayDelta.x);
    if (rayDelta.x < -1e-5) clipScale = min(clipScale, (0.0 - startScr.x) / rayDelta.x);
    if (rayDelta.y > 1e-5)  clipScale = min(clipScale, (1.0 - startScr.y) / rayDelta.y);
    if (rayDelta.y < -1e-5) clipScale = min(clipScale, (0.0 - startScr.y) / rayDelta.y);
    clipScale = clamp(clipScale, 0.0, 1.0);

    const int MAX_STEPS = 44;
    float invSteps = 1.0 / float(MAX_STEPS);

    vec3 waterPlayerPos = (modelViewInv * vec4(viewPos, 1.0)).xyz;

    // Mild dither (0.25 step) prevents banding without creating noisy missing-pixel holes
    float prevT = 0.0;
    bool hit = false;
    vec2 hitUV = vec2(0.0);

    for (int i = 1; i <= MAX_STEPS; i++) {
        // Gentle quadratic progression: fine near water surface, covers full horizon smoothly
        float u = (float(i) - 0.60 + 0.25 * dither) * invSteps;
        float t = clipScale * (0.26 * u + 0.74 * u * u);

        vec3 curScr = startScr + rayDelta * t;
        if (curScr.x < 0.002 || curScr.x > 0.998 || curScr.y < 0.002 || curScr.y > 0.998) {
            break;
        }
        if (curScr.z <= 0.0 || curScr.z >= 0.9998) {
            break;
        }

        float opaqueDepth = texture(depthOpaqueTex, curScr.xy).r;
        if (opaqueDepth >= 0.9998) {
            prevT = t;
            continue;
        }

        // CRITICAL ABOVE-WATER CHECK #1:
        // Above-water opaque terrain has depthtex0 == depthtex1; underwater seabed has depthtex0 < depthtex1!
        if (rejectBelowSurface) {
            float allDepth = texture(depthAllTex, curScr.xy).r;
            if (opaqueDepth - allDepth > 1e-6) {
                prevT = t;
                continue;
            }
        }

        if (curScr.z > opaqueDepth) {
            vec3 rayView   = screenToView(curScr.xy, curScr.z, projInv);
            vec3 sceneView = screenToView(curScr.xy, opaqueDepth, projInv);

            // CRITICAL ABOVE-WATER CHECK #2:
            // Never reflect geometry physically below the water surface plane!
            if (rejectBelowSurface) {
                vec3 scenePlayerPos = (modelViewInv * vec4(sceneView, 1.0)).xyz;
                if (scenePlayerPos.y < waterPlayerPos.y - 0.08) {
                    prevT = t;
                    continue;
                }
            }

            float rayDistZ   = -rayView.z;
            float sceneDistZ = -sceneView.z;
            float depthDiff  = rayDistZ - sceneDistZ;

            // Compute exact step depth delta from prevT -> t (never stale across skipped steps)
            vec3 prevScr  = startScr + rayDelta * prevT;
            vec3 prevView = screenToView(clamp(prevScr.xy, vec2(0.001), vec2(0.999)), clamp(prevScr.z, 0.0001, 0.9998), projInv);
            float stepZ   = max(abs(rayDistZ - (-prevView.z)), 0.6);
            float maxThickness = clamp(stepZ * 3.8 + sceneDistZ * 0.16, 3.0, 48.0);

            if (depthDiff >= 0.0 && depthDiff < maxThickness) {
                // 5-step binary search refinement between prevT and t for razor-clean silhouettes
                float lo = prevT;
                float hi = t;
                for (int j = 0; j < 5; j++) {
                    float mid = 0.5 * (lo + hi);
                    vec3 mScr = startScr + rayDelta * mid;
                    vec2 mUV  = clamp(mScr.xy, vec2(0.001), vec2(0.999));
                    float mDepth = texture(depthOpaqueTex, mUV).r;
                    bool mValid = (mDepth < 0.9998);
                    if (mValid && rejectBelowSurface) {
                        float mAll = texture(depthAllTex, mUV).r;
                        mValid = (mDepth - mAll <= 1e-6);
                    }
                    if (mValid && mScr.z > mDepth) {
                        hi = mid;
                    } else {
                        lo = mid;
                    }
                }

                vec3 finalScr = startScr + rayDelta * hi;
                vec2 finalUV  = clamp(finalScr.xy, vec2(0.001), vec2(0.999));
                float fOpaque = texture(depthOpaqueTex, finalUV).r;
                bool fValid = (fOpaque < 0.9998);
                if (fValid && rejectBelowSurface) {
                    float fAll = texture(depthAllTex, finalUV).r;
                    fValid = (fOpaque - fAll <= 1e-6);
                }
                if (fValid) {
                    bool heightOk = true;
                    if (rejectBelowSurface) {
                        vec3 fView = screenToView(finalUV, fOpaque, projInv);
                        vec3 fPlayer = (modelViewInv * vec4(fView, 1.0)).xyz;
                        heightOk = (fPlayer.y >= waterPlayerPos.y - 0.08);
                    }
                    if (heightOk) {
                        hitUV = finalUV;
                        hit = true;
                        break;
                    }
                }
            }
        }

        prevT = t;
    }

    if (!hit) return vec4(0.0);

    // Smooth border fade into sky/cloud reflection
    vec2 edge = smoothstep(vec2(0.0), vec2(0.08), hitUV) * smoothstep(vec2(1.0), vec2(0.92), hitUV);
    float edgeFade = edge.x * edge.y;
    float backFade = smoothstep(0.15, -0.20, reflDir.z);
    float confidence = clamp(edgeFade * backFade, 0.0, 1.0);

    vec3 reflColor = texture(sceneColorTex, hitUV).rgb;
    return vec4(reflColor, confidence);
#endif
}

#endif
