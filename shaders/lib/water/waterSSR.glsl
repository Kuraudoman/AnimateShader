#ifndef ANIMATE_WATER_SSR_GLSL
#define ANIMATE_WATER_SSR_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Screen-Space Reflections (SSR) for Crystal Water & Glossy Ice
// Exact clip-space frustum-clipped raymarcher with perspective-invariant
// combined (screen-space + log-depth) stepping:
//   - Reflects full mountain & tree height regardless of camera proximity to water
//   - Reaches across the full render distance (`renderFar`) with 24-bit depth accuracy
//   - Rejects underwater seabed hits & foreground occluder smearing
//   - 6-step view-space binary refinement for razor-clean silhouettes
// ==============================================================================

float ssrLinearViewDistZ(float depth, mat4 projInv) {
    float zNdc  = depth * 2.0 - 1.0;
    float zNum  = projInv[2].z * zNdc + projInv[3].z;
    float wDen  = projInv[2].w * zNdc + projInv[3].w;
    float denom = max(abs(wDen), 1e-6) * (wDen >= 0.0 ? 1.0 : -1.0);
    return -(zNum / denom);
}

vec4 traceAnimeSSR(
    vec3 viewPos,
    vec3 viewNormal,
    float dither,
    float renderFar,
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

    // Compute reflection direction in world space and keep water rays smoothly above horizontal
    // so grazing wave troughs never flip back-facing or dive into the underwater seabed
    vec3 worldViewDir = safeNormalize((modelViewInv * vec4(viewDir, 0.0)).xyz);
    vec3 worldNorm    = safeNormalize((modelViewInv * vec4(nView, 0.0)).xyz);

    if (rejectBelowSurface) {
        float viewDotN = dot(worldViewDir, worldNorm);
        if (viewDotN > -0.02) {
            worldNorm = safeNormalize(mix(worldNorm, vec3(0.0, 1.0, 0.0), smoothstep(-0.02, 0.05, viewDotN)));
        }
    }

    vec3 worldRefl = reflect(worldViewDir, worldNorm);
    if (rejectBelowSurface && worldRefl.y < 0.002) {
        vec3 flatRefl = reflect(worldViewDir, vec3(0.0, 1.0, 0.0));
        worldRefl.y = max(flatRefl.y * 0.5, 0.002);
        worldRefl = safeNormalize(worldRefl);
    }

    // Transform reflection back to view space via transpose of upper-left 3x3
    // (gbufferModelViewInverse is rigid rotation, so transpose == inverse)
    vec3 reflDir = safeNormalize(transpose(mat3(modelViewInv)) * worldRefl);

    // Avoid reflecting straight back behind the camera
    if (reflDir.z > 0.35) return vec4(0.0);

    // Small normal bias avoids self-intersection without visibly shifting distant silhouettes
    vec3 startView = viewPos + nView * 0.015;
    vec4 startClip = proj * vec4(startView, 1.0);
    vec4 dirClip   = proj * vec4(reflDir, 0.0);
    if (startClip.w <= 1e-4) return vec4(0.0);

    // Trace across the full render distance regardless of how close the camera/water pixel is!
    float sMax = max(renderFar * 1.5, 320.0);

    // Exact homogeneous clip-space frustum exit distance (all 6 clip planes):
    // Inside frustum <=> a + s * b >= 0  =>  when b < 0, exit occurs at s = max(a, 0) / (-b)
    vec4 aXY = vec4(
        startClip.w + startClip.x, startClip.w - startClip.x,
        startClip.w + startClip.y, startClip.w - startClip.y
    );
    vec4 bXY = vec4(
        dirClip.w + dirClip.x, dirClip.w - dirClip.x,
        dirClip.w + dirClip.y, dirClip.w - dirClip.y
    );
    if (bXY.x < -1e-6) sMax = min(sMax, max(aXY.x, 0.0) / (-bXY.x));
    if (bXY.y < -1e-6) sMax = min(sMax, max(aXY.y, 0.0) / (-bXY.y));
    if (bXY.z < -1e-6) sMax = min(sMax, max(aXY.z, 0.0) / (-bXY.z));
    if (bXY.w < -1e-6) sMax = min(sMax, max(aXY.w, 0.0) / (-bXY.w));

    float aNear = startClip.w + startClip.z;
    float bNear = dirClip.w + dirClip.z;
    if (bNear < -1e-6) sMax = min(sMax, max(aNear, 0.0) / (-bNear));

    float aFar = startClip.w - startClip.z;
    float bFar = dirClip.w - dirClip.z;
    if (bFar < -1e-6) sMax = min(sMax, max(aFar, 0.0) / (-bFar));

    // Keep clip w strictly positive (safely in front of the camera near plane)
    if (dirClip.w < -1e-6) {
        sMax = min(sMax, max(startClip.w - 0.1, 0.0) / (-dirClip.w));
    }

    if (sMax <= 0.05) return vec4(0.0);
    sMax *= 0.999;

    vec4 endClip  = startClip + dirClip * sMax;
    vec3 startScr = (startClip.xyz / startClip.w) * 0.5 + 0.5;
    vec3 endScr   = (endClip.xyz   / max(endClip.w, 1e-4)) * 0.5 + 0.5;

    float screenLen = length(endScr.xy - startScr.xy);
    if (screenLen < 0.001) return vec4(0.0);

    float w0 = max(startClip.w, 1e-4);
    float w1 = max(endClip.w, 1e-4);
    float wd = dirClip.w;

    // Exact 2D screen-space velocity numerator: |d(scr.xy)/ds| = K / w(s)^2
    float K = 0.5 * length(dirClip.xy * w0 - startClip.xy * wd);
    float logDepthLen = abs(log(w1 / w0));

    // Perspective-invariant progress metric: M(s) = SCREEN_WEIGHT * scrDist(s) + logDepth(s)
    // Guarantees fine resolution in BOTH 2D screen space (thin trees/silhouettes) and
    // 3D relative depth (distant mountains even when water is < 0.2 blocks below camera!)
    const float SCREEN_WEIGHT = 10.0;
    const int   MAX_STEPS     = 56;
    float totalMetric = SCREEN_WEIGHT * screenLen + logDepthLen;
    float dM = totalMetric / float(MAX_STEPS - 1);

    vec3 waterPlayerPos = (modelViewInv * vec4(viewPos, 1.0)).xyz;

    // Initial jittered step prevents banding without creating holes
    float rate0   = (SCREEN_WEIGHT * K) / (w0 * w0) + abs(wd) / w0;
    float ds0     = clamp(dM / max(rate0, 1e-6), 0.01, sMax);
    float wMid0   = max(w0 + min(0.5 * ds0, sMax) * wd, 1e-4);
    float rateM0  = (SCREEN_WEIGHT * K) / (wMid0 * wMid0) + abs(wd) / wMid0;
    float dsInit  = clamp(dM / max(rateM0, 1e-6), 0.01, sMax);

    float s             = min((0.25 + 0.45 * dither) * dsInit, sMax);
    float prevS         = 0.0;
    float prevRayZ      = -startView.z;
    float prevValidS    = 0.0;
    float prevValidRayZ = -startView.z;

    bool hit = false;
    vec2 hitUV = vec2(0.0);

    for (int i = 0; i < MAX_STEPS; i++) {
        vec4 curClip = startClip + dirClip * s;
        if (curClip.w <= 1e-4) {
            break;
        }

        vec3 curScr = (curClip.xyz / curClip.w) * 0.5 + 0.5;
        if (curScr.x < 0.0 || curScr.x > 1.0 || curScr.y < 0.0 || curScr.y > 1.0) {
            break;
        }
        if (curScr.z <= 0.0 || curScr.z >= 0.999999) {
            break;
        }

        vec2 curUV = clamp(curScr.xy, vec2(0.0005), vec2(0.9995));
        float opaqueDepth = texture(depthOpaqueTex, curUV).r;
        float curRayZ = -(startView.z + reflDir.z * s);
        bool sampleAboveWater = true;

        // Sky is 1.0 in 24-bit depth buffer; using 0.999999 preserves distant mountains up to far!
        if (opaqueDepth < 0.999999) {
            // CRITICAL ABOVE-WATER CHECK #1:
            // Above-water opaque terrain has depthtex0 == depthtex1; underwater seabed has depthtex0 < depthtex1!
            if (rejectBelowSurface) {
                float allDepth = texture(depthAllTex, curUV).r;
                sampleAboveWater = (opaqueDepth - allDepth <= 1e-6);
            }

            // Fast depth test with tiny float32/24-bit depth slack before linearizing
            if (sampleAboveWater && curScr.z >= opaqueDepth - 1e-6) {
                vec3 sceneView = screenToView(curUV, opaqueDepth, projInv);
                float sceneDistZ = -sceneView.z;
                float depthDiff  = curRayZ - sceneDistZ;

                if (depthDiff >= -0.02) {
                    // CRITICAL ABOVE-WATER CHECK #2:
                    // Never reflect geometry physically below the water surface plane!
                    bool heightOk = true;
                    if (rejectBelowSurface) {
                        vec3 scenePlayerPos = (modelViewInv * vec4(sceneView, 1.0)).xyz;
                        heightOk = (scenePlayerPos.y >= waterPlayerPos.y - 0.08);
                    }

                    float stepZ = max(abs(curRayZ - prevRayZ), 0.5);
                    bool crossedFromWater = (prevValidRayZ <= sceneDistZ + 1.0) && (prevValidS < prevS);
                    float effStepZ = crossedFromWater ? max(curRayZ - prevValidRayZ, stepZ) : stepZ;
                    float maxThickness = max(effStepZ * 2.5 + sceneDistZ * 0.08, 1.5);

                    if (heightOk && depthDiff <= maxThickness) {
                        // 6-step binary search refinement in exact view-space distance s
                        float lo = crossedFromWater ? prevValidS : prevS;
                        float hi = s;
                        for (int j = 0; j < 6; j++) {
                            float mid = 0.5 * (lo + hi);
                            vec4 mClip = startClip + dirClip * mid;
                            vec3 mScr  = (mClip.xyz / max(mClip.w, 1e-4)) * 0.5 + 0.5;
                            vec2 mUV   = clamp(mScr.xy, vec2(0.0005), vec2(0.9995));
                            float mDepth = texture(depthOpaqueTex, mUV).r;
                            bool mValid = (mDepth < 0.999999);
                            if (mValid && rejectBelowSurface) {
                                float mAll = texture(depthAllTex, mUV).r;
                                mValid = (mDepth - mAll <= 1e-6);
                            }
                            if (mValid) {
                                float mSceneZ = ssrLinearViewDistZ(mDepth, projInv);
                                float mRayZ   = -(startView.z + reflDir.z * mid);
                                float mDiff   = mRayZ - mSceneZ;
                                if (mDiff >= -0.02 && mDiff <= maxThickness) {
                                    hi = mid;
                                } else {
                                    lo = mid;
                                }
                            } else {
                                lo = mid;
                            }
                        }

                        vec4 finalClip = startClip + dirClip * hi;
                        vec3 finalScr  = (finalClip.xyz / max(finalClip.w, 1e-4)) * 0.5 + 0.5;
                        vec2 finalUV   = clamp(finalScr.xy, vec2(0.0005), vec2(0.9995));
                        float fOpaque  = texture(depthOpaqueTex, finalUV).r;
                        bool fValid    = (fOpaque < 0.999999);
                        if (fValid && rejectBelowSurface) {
                            float fAll = texture(depthAllTex, finalUV).r;
                            fValid = (fOpaque - fAll <= 1e-6);
                        }
                        if (fValid) {
                            vec3 fView = screenToView(finalUV, fOpaque, projInv);
                            float fSceneZ = -fView.z;
                            float fRayZ   = -(startView.z + reflDir.z * hi);
                            bool fHeightOk = true;
                            if (rejectBelowSurface) {
                                vec3 fPlayer = (modelViewInv * vec4(fView, 1.0)).xyz;
                                fHeightOk = (fPlayer.y >= waterPlayerPos.y - 0.08);
                            }
                            float fMaxTol = max(effStepZ * 1.2 + fSceneZ * 0.06, 1.5);
                            if (fHeightOk && abs(fRayZ - fSceneZ) <= fMaxTol) {
                                hitUV = finalUV;
                                hit = true;
                                break;
                            }
                        }
                    }
                }
            }
        }

        prevS    = s;
        prevRayZ = curRayZ;
        if (sampleAboveWater) {
            prevValidS    = s;
            prevValidRayZ = curRayZ;
        }
        if (s >= sMax * 0.9995) {
            break;
        }

        // 2nd-order midpoint advance in invariant metric M(s)
        float wCur    = max(w0 + s * wd, 1e-4);
        float rateCur = (SCREEN_WEIGHT * K) / (wCur * wCur) + abs(wd) / wCur;
        float dsEst   = clamp(dM / max(rateCur, 1e-6), 0.01, sMax);
        float wMid    = max(w0 + min(s + 0.5 * dsEst, sMax) * wd, 1e-4);
        float rateMid = (SCREEN_WEIGHT * K) / (wMid * wMid) + abs(wd) / wMid;
        float ds      = clamp(dM / max(rateMid, 1e-6), 0.01, sMax);
        s = min(s + ds, sMax);
    }

    if (!hit) return vec4(0.0);

    // Smooth border fade into sky/cloud reflection (preserves tall mountain peaks near top edge)
    float edgeX = smoothstep(0.0, 0.04, hitUV.x) * smoothstep(1.0, 0.96, hitUV.x);
    float edgeY = smoothstep(0.0, 0.03, hitUV.y) * smoothstep(1.0, 0.95, hitUV.y);
    float edgeFade = edgeX * edgeY;
    float backFade = smoothstep(0.35, -0.10, reflDir.z);
    float confidence = clamp(edgeFade * backFade, 0.0, 1.0);

    vec3 reflColor = texture(sceneColorTex, hitUV).rgb;
    return vec4(reflColor, confidence);
#endif
}

#endif
