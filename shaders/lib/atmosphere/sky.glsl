#ifndef ANIMATE_SKY_GLSL
#define ANIMATE_SKY_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"
#include "/lib/common/timeAndPalette.glsl"

// ==============================================================================
// Anime Fantasy Sky Dome
// Overworld: Makoto Shinkai multi-band sky, radiant Sun & Moon coronas,
//            twinkling multi-color stars, Milky Way nebula, dancing Aurora
//            Borealis, and periodic shooting stars.
// The End:   Swirling cosmic nebula vortex, aurora ring, starfield & End Flash.
// Nether:    Rich crimson-amber & rose-violet cavern atmosphere.
// ==============================================================================

vec3 renderStars(vec3 dir, float timeSec, float visibility) {
    if (visibility <= 0.001 || dir.y < -0.02) return vec3(0.0);

    vec3 stars = vec3(0.0);

    // Bright hero stars
    vec3 p = dir * 120.0;
    vec3 cell = floor(p);
    vec3 local = fract(p) - 0.5;
    float h = hash13(cell);

    if (h > 0.962) {
        vec3 jitter = vec3(hash13(cell + 11.3), hash13(cell + 27.9), hash13(cell + 53.1)) - 0.5;
        float d = length(local - jitter * 0.52);
        float core = exp(-d * d * 34.0);
        float twinkle = 0.68 + 0.32 * sin(timeSec * (2.2 + h * 5.0) + h * 120.0);

        float tintSel = fract(h * 73.13);
        vec3 starCol = vec3(0.95, 0.98, 1.15);
        if (tintSel < 0.25)      starCol = vec3(0.55, 0.88, 1.45);
        else if (tintSel < 0.50) starCol = vec3(1.42, 1.16, 0.68);
        else if (tintSel < 0.72) starCol = vec3(1.38, 0.74, 1.12);
        else if (tintSel < 0.88) starCol = vec3(0.50, 1.32, 1.24);

        stars += starCol * core * twinkle * 1.95;
    }

    // Fine cosmic stardust layer
    vec3 p2 = dir * 230.0;
    vec3 cell2 = floor(p2);
    vec3 local2 = fract(p2) - 0.5;
    float h2 = hash13(cell2 + 91.7);
    if (h2 > 0.955) {
        float d2 = length(local2);
        float core2 = exp(-d2 * d2 * 30.0);
        float twinkle2 = 0.75 + 0.25 * sin(timeSec * 3.4 + h2 * 80.0);
        stars += mix(vec3(0.68, 0.86, 1.28), vec3(1.22, 0.92, 1.16), fract(h2 * 31.7)) * core2 * twinkle2 * 0.85;
    }

    float horizonFade = smoothstep(0.0, 0.16, dir.y);
    return stars * horizonFade * visibility;
}

vec3 renderMilkyWay(vec3 dir, float timeSec, float visibility) {
#ifdef MILKY_WAY
    if (visibility <= 0.001 || dir.y < 0.0) return vec3(0.0);

    vec3 gDir = dir;
    gDir.yz = rot2D(0.52) * gDir.yz;
    gDir.xy = rot2D(0.45) * gDir.xy;

    float band = exp(-pow(gDir.y / 0.24, 2.0));
    if (band < 0.01) return vec3(0.0);

    vec2 uv = vec2(atan(gDir.z, gDir.x) * 2.1, gDir.y * 5.2);
    float n1 = fbm2D(uv * 1.35 + vec2(0.0, 1.2));
    float n2 = fbm2D(uv * 2.8 - vec2(n1 * 1.4, -0.8));
    float dustRift = smoothstep(0.34, 0.72, fbm2D(uv * 2.2 + vec2(4.2, -2.7)));

    float coreGlow = band * smoothstep(0.26, 0.84, n1 * 0.65 + n2 * 0.45);
    float riftMask = 1.0 - 0.48 * dustRift * exp(-pow(gDir.y / 0.085, 2.0));

    vec3 colIndigo = vec3(0.14, 0.30, 0.88);
    vec3 colRose   = vec3(0.76, 0.26, 0.84);
    vec3 colAqua   = vec3(0.24, 0.88, 1.12);

    vec3 nebula = mix(colIndigo, colRose, smoothstep(0.35, 0.75, n2));
    nebula = mix(nebula, colAqua, smoothstep(0.54, 0.86, n1) * 0.60);

    float sparkle = pow(valueNoise2D(uv * 18.0 + vec2(timeSec * 0.04, 0.0)), 6.0) * 2.2;
    nebula += vec3(0.95, 0.92, 1.30) * sparkle * band;

    float horizonFade = smoothstep(0.02, 0.24, dir.y);
    return nebula * coreGlow * riftMask * horizonFade * visibility * 0.42;
#else
    return vec3(0.0);
#endif
}

vec3 renderFantasyAurora(vec3 dir, float timeSec, float visibility) {
#ifdef FANTASY_AURORA
    if (visibility <= 0.001 || dir.y <= 0.03) return vec3(0.0);

    vec2 p = dir.xz / (dir.y + 0.28);
    float t = timeSec * 0.14;

    vec3 accum = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        float fi = float(i) / 5.0;
        float heightScale = 0.85 + fi * 0.48;
        vec2 q = p * (0.44 * heightScale);

        // Sweeping luminous curtain ribbons visible across horizon-to-mid sky
        float wave1 = sin(q.x * 1.45 + t * 1.10 + fi * 1.4) * 0.58;
        float wave2 = cos(q.x * 2.65 - t * 0.78 + q.y * 0.42) * 0.32;
        float ribbonCoord = (q.y - 0.55) * 0.85 + wave1 + wave2 + 0.32 * sin(fi * 2.9 + t * 0.38);

        float ribbon = exp(-abs(ribbonCoord) * 4.8);
        float rays = 0.52 + 0.48 * valueNoise2D(vec2(q.x * 5.8 + t * 0.9, fi * 2.1 - t * 0.32));
        float fineCurtain = 0.62 + 0.38 * sin(q.x * 13.0 + wave1 * 6.5 + t * 1.8);

        // Iridescent emerald-mint -> luminous cyan -> amethyst-violet -> sakura-pink
        vec3 colBottom = vec3(0.10, 1.28, 0.74);
        vec3 colMid    = vec3(0.16, 0.82, 1.38);
        vec3 colTop    = vec3(1.05, 0.34, 1.25);
        vec3 curtainCol = mix(colBottom, colMid, smoothstep(0.0, 0.52, fi));
        curtainCol = mix(curtainCol, colTop, smoothstep(0.45, 1.0, fi));

        float verticalProfile = smoothstep(0.0, 0.22, fi + 0.14) * (1.0 - 0.30 * fi);
        accum += curtainCol * ribbon * rays * fineCurtain * verticalProfile;
    }

    float horizonMask = smoothstep(0.04, 0.20, dir.y) * smoothstep(0.95, 0.42, dir.y);
    float distFade = exp(-length(p) * 0.12);
    return accum * horizonMask * distFade * visibility * AURORA_STRENGTH * 0.34;
#else
    return vec3(0.0);
#endif
}

vec3 renderShootingStars(vec3 dir, float timeSec, float visibility) {
#ifdef SHOOTING_STARS
    if (visibility <= 0.001 || dir.y < 0.06) return vec3(0.0);

    vec3 glow = vec3(0.0);
    for (int i = 0; i < 2; i++) {
        float period = (i == 0) ? 11.0 : 17.0;
        float cycle = floor(timeSec / period);
        float localT = fract(timeSec / period);

        float activeDuration = 0.12;
        if (localT < activeDuration) {
            float progress = localT / activeDuration;
            float seed = cycle * 19.37 + float(i) * 71.13;

            vec3 startDir = normalize(vec3(
                hash12(vec2(seed, 1.7)) * 2.0 - 1.0,
                0.30 + hash12(vec2(seed, 3.1)) * 0.55,
                hash12(vec2(seed, 5.9)) * 2.0 - 1.0
            ));
            vec3 tangent = normalize(cross(startDir, vec3(0.15, 1.0, -0.2)));
            vec3 travelDir = normalize(tangent - vec3(0.0, 0.45, 0.0));

            vec3 headPos = normalize(startDir + travelDir * (progress * 0.42));
            vec3 delta = dir - headPos;
            float along = dot(delta, -travelDir);
            vec3 perp = delta - (-travelDir) * along;
            float perpDist = length(perp);

            float tailLen = 0.12;
            if (along >= -0.008 && along <= tailLen) {
                float tailFade = smoothstep(tailLen, 0.0, along) * smoothstep(-0.008, 0.003, along);
                float width = mix(0.0024, 0.0005, clamp(along / tailLen, 0.0, 1.0));
                float streak = exp(-pow(perpDist / width, 2.0)) * tailFade;
                float env = sin(progress * PI);
                vec3 mCol = (i == 0) ? vec3(0.85, 1.25, 1.85) : vec3(1.65, 0.95, 1.35);
                glow += mCol * streak * env * 3.0;
            }
        }
    }
    return glow * visibility;
#else
    return vec3(0.0);
#endif
}

vec3 renderAnimeSky(
    vec3 worldDir,
    AnimeLightingState st,
    float timeSec,
    float endFlashVal,
    vec3 endFlashWorldDir
) {
    vec3 dir = safeNormalize(worldDir);
    float up = dir.y;

#if defined(DIMENSION_NETHER)
    float hMix = clamp(up * 0.5 + 0.5, 0.0, 1.0);
    vec3 sky = mix(st.skyHorizon, st.skyMid, smoothstep(0.0, 0.55, hMix));
    sky = mix(sky, st.skyZenith, smoothstep(0.45, 1.0, hMix));
    float emberNoise = fbm2D(dir.xz / (abs(up) + 0.4) * 2.2 + vec2(0.0, timeSec * 0.08));
    sky += vec3(0.42, 0.12, 0.06) * smoothstep(0.48, 0.86, emberNoise) * 0.45;
    return sky;

#elif defined(DIMENSION_END)
    float upAbs = abs(up);
    vec3 sky = mix(st.skyHorizon, st.skyMid, smoothstep(0.0, 0.36, upAbs));
    sky = mix(sky, st.skyZenith, smoothstep(0.28, 0.85, upAbs));

    // Swirling Cosmic Galaxy Vortex & Luminous Astral Ring overhead
    if (up > 0.02) {
        vec2 p = dir.xz / (up + 0.22);
        float r = length(p);
        float ang = atan(p.y, p.x);
        float swirl = fbm2D(vec2(r * 1.5 - timeSec * 0.04, ang * 2.0 + r * 2.4));
        float ring = exp(-pow((r - 1.25) / 0.38, 2.0));
        float coreVortex = exp(-r * r * 1.4);

        vec3 ringCol = mix(vec3(0.42, 0.16, 0.95), vec3(0.18, 0.78, 1.18), swirl);
        sky += ringCol * ring * (0.45 + 0.65 * swirl) * smoothstep(0.02, 0.22, up) * 0.48;
        sky += vec3(0.75, 0.42, 1.18) * coreVortex * (0.35 + 0.45 * swirl) * 0.38;
    }

    sky += renderStars(dir, timeSec, 1.25);
    sky += renderMilkyWay(dir, timeSec, 0.95);
    sky += renderFantasyAurora(dir, timeSec, 0.72);

    // Minecraft 26.3 End Flash dramatic violet-cyan surge
    if (endFlashVal > 0.001) {
        float flashDot = max(dot(dir, safeNormalize(endFlashWorldDir)), 0.0);
        float flashCore = pow(flashDot, 56.0) * 1.85 + pow(flashDot, 10.0) * 0.36;
        sky += vec3(0.72, 0.42, 1.38) * flashCore * endFlashVal;
    }
    return sky;

#else
    float elev = max(up, 0.0);

    // Smooth three-stop Makoto Shinkai gradient
    vec3 sky = mix(st.skyHorizon, st.skyMid, pow(clamp(elev, 0.0, 1.0), 0.44));
    sky = mix(sky, st.skyZenith, pow(clamp(elev, 0.0, 1.0), 1.10));

    if (up < 0.0) {
        vec3 lowerTint = mix(st.skyHorizon * 0.82, st.ambientGround * 0.85, clamp(-up * 2.8, 0.0, 1.0));
        sky = lowerTint;
    }

    // Warm sunward scattering & sunset twilight glow arc
    float sunDot = dot(dir, st.sunDir);
    float sunCos = max(sunDot, 0.0);
    float horizonBand = exp(-abs(up) * 5.0);

    float sunScatter = pow(sunCos, 5.5) * (0.26 + 0.68 * st.sunsetFactor) * (1.0 - st.rainMix * 0.72);
    sky += st.skyGlowColor * sunScatter * (0.44 + 0.56 * horizonBand) * smoothstep(-0.22, 0.08, st.sunElev);

    // Makoto Shinkai pastel magenta-violet anti-solar glow during sunset / magic hour
    float antiSun = max(dot(dir, -st.sunDir), 0.0);
    vec3 beltOfVenus = vec3(0.72, 0.28, 0.62) * pow(antiSun, 2.2) * horizonBand * (st.sunsetFactor + st.twilightFactor) * 0.38;
    sky += beltOfVenus * (1.0 - st.rainMix * 0.75);

    // Night Sky Wonders: Milky Way, Multi-Color Stars, Dancing Aurora, Shooting Stars
    float nightSkyVis = smoothstep(0.10, -0.05, st.sunElev) * (1.0 - st.rainMix * 0.85);
    float twilightStarVis = smoothstep(0.14, -0.04, st.sunElev) * (1.0 - st.rainMix * 0.85);

    sky += renderMilkyWay(dir, timeSec, nightSkyVis);
    sky += renderStars(dir, timeSec, twilightStarVis);
    sky += renderFantasyAurora(dir, timeSec, nightSkyVis);
    sky += renderShootingStars(dir, timeSec, nightSkyVis);

    // --- RADIANT ANIME SUN DISC + CORONA + 6-POINT STARBURST ---
    float sunVis = smoothstep(-0.08, 0.03, st.sunDir.y) * (1.0 - st.rainMix * 0.88);
    if (sunVis > 0.001 && sunDot > 0.0) {
        float sunAngleDist = acos(clamp(sunDot, -1.0, 1.0));
        float sunDisc = smoothstep(0.036, 0.025, sunAngleDist);
        float coronaInner = exp(-sunAngleDist * 14.0) * 1.10;
        float coronaOuter = exp(-sunAngleDist * 4.2) * 0.26;

        vec3 upRef = abs(st.sunDir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 sRight = normalize(cross(upRef, st.sunDir));
        vec3 sUp = cross(st.sunDir, sRight);
        vec2 sunLocal = vec2(dot(dir, sRight), dot(dir, sUp));
        float rayAngle = atan(sunLocal.y, sunLocal.x);
        float starburst = pow(abs(cos(rayAngle * 3.0)), 14.0) * exp(-sunAngleDist * 9.5) * 0.42;

        vec3 sunDiscCol = mix(vec3(3.2, 2.8, 2.1), vec3(3.6, 1.45, 0.65), st.sunsetFactor);
        vec3 sunHaloCol = mix(vec3(1.35, 1.08, 0.68), vec3(1.75, 0.62, 0.34), st.sunsetFactor);

        sky += sunDiscCol * sunDisc * sunVis;
        sky += sunHaloCol * (coronaInner + coronaOuter + starburst) * sunVis;
    }

    // --- LUMINOUS FANTASY MOON DISC + HALO ---
    float moonDot = dot(dir, st.moonDir);
    float moonVis = smoothstep(-0.08, 0.04, st.moonDir.y) * (1.0 - st.rainMix * 0.82);
    if (moonVis > 0.001 && moonDot > 0.0) {
        float moonAngleDist = acos(clamp(moonDot, -1.0, 1.0));
        float moonRadius = 0.034;
        float moonDisc = smoothstep(moonRadius + 0.004, moonRadius - 0.004, moonAngleDist);

        vec3 mUpRef = abs(st.moonDir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 mRight = normalize(cross(mUpRef, st.moonDir));
        vec3 mUp = cross(st.moonDir, mRight);
        vec2 mUV = vec2(dot(dir, mRight), dot(dir, mUp)) / moonRadius;
        float craters = 0.84 + 0.16 * fbm2D(mUV * 3.4 + vec2(2.4, 5.1));
        float limbGlow = 0.88 + 0.24 * smoothstep(0.4, 1.0, length(mUV));

        float moonHalo = exp(-moonAngleDist * 10.5) * 0.52 + exp(-moonAngleDist * 3.5) * 0.14;
        vec3 moonDiscCol = vec3(1.85, 2.18, 2.65) * craters * limbGlow;
        vec3 moonHaloCol = vec3(0.32, 0.62, 1.18);

        sky = mix(sky, moonDiscCol, moonDisc * moonVis);
        sky += moonHaloCol * moonHalo * moonVis * (0.75 + 0.20 * NIGHT_BRIGHTNESS);
    }

    return sky;
#endif
}

#endif
