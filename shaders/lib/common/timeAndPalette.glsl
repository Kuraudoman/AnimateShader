#ifndef ANIMATE_TIME_AND_PALETTE_GLSL
#define ANIMATE_TIME_AND_PALETTE_GLSL

#include "/lib/settings.glsl"
#include "/lib/common/math.glsl"

// ==============================================================================
// Anime Fantasy Color Science & Time-of-Day State (Linear HDR Calibrated)
// Rich Makoto Shinkai cobalt skies, vivid rose-gold sunsets, jewel-sapphire
// starry nights with bright, crystal-clear moonlit terrain (never too dark!).
// ==============================================================================

struct AnimeLightingState {
    vec3 sunDir;
    vec3 moonDir;
    vec3 activeLightDir;

    float sunElev;
    float dayFactor;
    float nightFactor;
    float sunsetFactor;
    float twilightFactor;
    float rainMix;

    vec3 skyZenith;
    vec3 skyMid;
    vec3 skyHorizon;
    vec3 skyGlowColor;

    vec3 directColor;
    vec3 ambientSky;
    vec3 ambientGround;
    vec3 shadowTint;
    vec3 rimColor;
    vec3 fogColorAnime;
    vec3 cloudLitColor;
    vec3 cloudShadowColor;
    vec3 godrayColor;
};

AnimeLightingState computeAnimeLightingState(
    vec3 sunWorldDir,
    vec3 moonWorldDir,
    float rainStrengthVal,
    float thunderStrengthVal,
    float endFlashVal
) {
    AnimeLightingState st;
    st.sunDir = safeNormalize(sunWorldDir);
    st.moonDir = safeNormalize(moonWorldDir);
    st.sunElev = st.sunDir.y;

    st.dayFactor = smoothstep(-0.07, 0.14, st.sunElev);
    st.nightFactor = 1.0 - st.dayFactor;
    st.sunsetFactor = exp(-pow((st.sunElev - 0.03) / 0.145, 2.0));
    st.twilightFactor = exp(-pow((st.sunElev + 0.065) / 0.125, 2.0));
    st.rainMix = clamp(rainStrengthVal, 0.0, 1.0);

    st.activeLightDir = (st.sunElev >= -0.04) ? st.sunDir : st.moonDir;

#if defined(DIMENSION_NETHER)
    // --- THE NETHER: Rich Crimson-Amber & Violet-Rose Cavern ---
    st.activeLightDir = normalize(vec3(0.25, 0.92, 0.28));
    st.dayFactor = 0.0;
    st.nightFactor = 0.0;
    st.sunsetFactor = 0.0;
    st.twilightFactor = 0.0;

    st.skyZenith        = vec3(0.11, 0.025, 0.055);
    st.skyMid           = vec3(0.28, 0.065, 0.085);
    st.skyHorizon       = vec3(0.55, 0.16,  0.095);
    st.skyGlowColor     = vec3(0.95, 0.36,  0.14);

    st.directColor      = vec3(0.68, 0.30, 0.18);
    st.ambientSky       = vec3(0.28, 0.12, 0.18) * CAVE_BRIGHTNESS;
    st.ambientGround    = vec3(0.36, 0.13, 0.08) * CAVE_BRIGHTNESS;
    st.shadowTint       = vec3(0.32, 0.16, 0.38);
    st.rimColor         = vec3(1.10, 0.45, 0.20);
    st.fogColorAnime    = vec3(0.32, 0.09, 0.11);
    st.cloudLitColor    = vec3(0.85, 0.34, 0.18);
    st.cloudShadowColor = vec3(0.22, 0.07, 0.14);
    st.godrayColor      = vec3(0.95, 0.36, 0.16);
    return st;

#elif defined(DIMENSION_END)
    // --- THE END: Deep Cosmic Velvet-Indigo Nebula & Starlit Aurora ---
    st.activeLightDir = normalize(vec3(0.32, 0.84, 0.44));
    st.dayFactor = 0.0;
    st.nightFactor = 1.0;
    st.sunsetFactor = 0.0;
    st.twilightFactor = 0.0;

    float flashBoost = clamp(endFlashVal, 0.0, 1.0);
    float endBright = max(NIGHT_BRIGHTNESS, 1.0);

    st.skyZenith        = vec3(0.010, 0.006, 0.036);
    st.skyMid           = vec3(0.032, 0.016, 0.092);
    st.skyHorizon       = vec3(0.085, 0.042, 0.185) + vec3(0.14, 0.08, 0.26) * flashBoost;
    st.skyGlowColor     = vec3(0.45,  0.22,  0.88)  + vec3(0.30, 0.42, 0.80) * flashBoost;

    // Bright readable lighting on End islands while keeping deep cosmic night sky
    st.directColor      = (vec3(0.42, 0.36, 0.68) + vec3(0.28, 0.40, 0.62) * flashBoost) * (0.65 * endBright);
    st.ambientSky       = vec3(0.13, 0.11, 0.26) * endBright;
    st.ambientGround    = vec3(0.08, 0.07, 0.16) * endBright;
    st.shadowTint       = vec3(0.22, 0.18, 0.52);
    st.rimColor         = vec3(0.55, 0.82, 1.35) + vec3(0.30, 0.18, 0.55) * flashBoost;
    st.fogColorAnime    = vec3(0.06, 0.035, 0.135);
    st.cloudLitColor    = vec3(0.65, 0.42, 1.05);
    st.cloudShadowColor = vec3(0.10, 0.06, 0.22);
    st.godrayColor      = vec3(0.55, 0.35, 1.15);
    return st;

#else
    // --- OVERWORLD: 4 Calibrated Linear-HDR Anime Fantasy Palettes ---
    vec3 dayZenith, dayMid, dayHorizon;
    vec3 sunsetZenith, sunsetMid, sunsetHorizon, sunsetGlow;
    vec3 nightZenith, nightMid, nightHorizon;
    vec3 daySun, sunsetSun, moonLight;
    vec3 dayAmbSky, dayAmbGround, dayShadowTint;
    vec3 nightAmbSky, nightAmbGround, nightShadowTint;

    #if COLOR_PALETTE == 1
        // 1: Sakura Fantasy (樱花幻境)
        dayZenith       = vec3(0.045, 0.14, 0.56);
        dayMid          = vec3(0.18,  0.34, 0.78);
        dayHorizon      = vec3(0.72,  0.52, 0.70);
        sunsetZenith    = vec3(0.085, 0.055, 0.28);
        sunsetMid       = vec3(0.68,  0.18,  0.42);
        sunsetHorizon   = vec3(1.22,  0.40,  0.28);
        sunsetGlow      = vec3(1.55,  0.54,  0.44);
        nightZenith     = vec3(0.008, 0.009, 0.042);
        nightMid        = vec3(0.024, 0.022, 0.088);
        nightHorizon    = vec3(0.072, 0.052, 0.148);

        daySun          = vec3(1.18, 0.98, 0.88);
        sunsetSun       = vec3(1.38, 0.52, 0.44);
        moonLight       = vec3(0.36, 0.44, 0.70);

        dayAmbSky       = vec3(0.20, 0.26, 0.48);
        dayAmbGround    = vec3(0.16, 0.12, 0.17);
        dayShadowTint   = vec3(0.34, 0.38, 0.82);
        nightAmbSky     = vec3(0.12, 0.11, 0.24);
        nightAmbGround  = vec3(0.08, 0.07, 0.15);
        nightShadowTint = vec3(0.28, 0.24, 0.58);

    #elif COLOR_PALETTE == 2
        // 2: Emerald Ghibli (翠林物语)
        dayZenith       = vec3(0.028, 0.18, 0.56);
        dayMid          = vec3(0.11,  0.42, 0.78);
        dayHorizon      = vec3(0.50,  0.76, 0.82);
        sunsetZenith    = vec3(0.055, 0.10, 0.28);
        sunsetMid       = vec3(0.66,  0.26, 0.20);
        sunsetHorizon   = vec3(1.25,  0.56, 0.20);
        sunsetGlow      = vec3(1.55,  0.76, 0.28);
        nightZenith     = vec3(0.005, 0.014, 0.040);
        nightMid        = vec3(0.015, 0.036, 0.086);
        nightHorizon    = vec3(0.040, 0.088, 0.145);

        daySun          = vec3(1.20, 1.06, 0.78);
        sunsetSun       = vec3(1.42, 0.62, 0.24);
        moonLight       = vec3(0.32, 0.50, 0.66);

        dayAmbSky       = vec3(0.16, 0.32, 0.48);
        dayAmbGround    = vec3(0.13, 0.17, 0.12);
        dayShadowTint   = vec3(0.26, 0.50, 0.76);
        nightAmbSky     = vec3(0.09, 0.16, 0.24);
        nightAmbGround  = vec3(0.06, 0.11, 0.14);
        nightShadowTint = vec3(0.20, 0.38, 0.58);

    #elif COLOR_PALETTE == 3
        // 3: Ethereal Violet (暮光星海)
        dayZenith       = vec3(0.036, 0.10, 0.54);
        dayMid          = vec3(0.14,  0.28, 0.78);
        dayHorizon      = vec3(0.48,  0.56, 0.86);
        sunsetZenith    = vec3(0.070, 0.040, 0.28);
        sunsetMid       = vec3(0.52,  0.14,  0.48);
        sunsetHorizon   = vec3(1.06,  0.32,  0.46);
        sunsetGlow      = vec3(1.42,  0.48,  0.74);
        nightZenith     = vec3(0.006, 0.008, 0.044);
        nightMid        = vec3(0.022, 0.026, 0.098);
        nightHorizon    = vec3(0.056, 0.068, 0.172);

        daySun          = vec3(1.12, 1.02, 0.96);
        sunsetSun       = vec3(1.30, 0.48, 0.62);
        moonLight       = vec3(0.34, 0.48, 0.76);

        dayAmbSky       = vec3(0.18, 0.24, 0.50);
        dayAmbGround    = vec3(0.13, 0.12, 0.20);
        dayShadowTint   = vec3(0.30, 0.34, 0.84);
        nightAmbSky     = vec3(0.10, 0.13, 0.26);
        nightAmbGround  = vec3(0.07, 0.08, 0.17);
        nightShadowTint = vec3(0.24, 0.28, 0.64);

    #else
        // 0: Shinkai Azure (新海诚星穹 — Signature Vibrant Cobalt & Coral-Gold)
        dayZenith       = vec3(0.020, 0.115, 0.58);  // Deep electric Makoto Shinkai cobalt zenith
        dayMid          = vec3(0.095, 0.34,  0.82);  // Pure luminous azure mid-sky
        dayHorizon      = vec3(0.46,  0.72,  0.94);  // Airy sky-blue horizon
        sunsetZenith    = vec3(0.055, 0.052, 0.27);  // Deep indigo-violet zenith
        sunsetMid       = vec3(0.64,  0.16,  0.36);  // Iconic Shinkai rose-magenta twilight
        sunsetHorizon   = vec3(1.28,  0.42,  0.16);  // Blazing tangerine-coral horizon
        sunsetGlow      = vec3(1.62,  0.60,  0.26);  // Radiant amber-gold sun scatter
        nightZenith     = vec3(0.004, 0.011, 0.044); // Deep jewel-sapphire starry night zenith!
        nightMid        = vec3(0.014, 0.032, 0.094); // Rich starlight indigo
        nightHorizon    = vec3(0.042, 0.075, 0.162); // Luminous moonlit mist horizon

        daySun          = vec3(1.22, 1.06, 0.84);    // Crisp warm golden-cream sunlight
        sunsetSun       = vec3(1.44, 0.54, 0.26);    // Rich warm coral-gold sunset light
        moonLight       = vec3(0.34, 0.46, 0.72);    // Luminous silver-cyan moonlight

        dayAmbSky       = vec3(0.17, 0.29, 0.52);    // Vivid cerulean sky fill
        dayAmbGround    = vec3(0.14, 0.15, 0.14);    // Ground bounce
        dayShadowTint   = vec3(0.28, 0.46, 0.88);    // Pure periwinkle-cerulean anime shadows!
        nightAmbSky     = vec3(0.105, 0.155, 0.275); // Generous bright starlit fill (never dark!)
        nightAmbGround  = vec3(0.072, 0.096, 0.165); // Soft indigo-lavender ground lift
        nightShadowTint = vec3(0.24, 0.34, 0.68);    // Colorful periwinkle night shadows
    #endif

    // Apply sunset richness slider
    float sWarm = SUNSET_WARMTH;
    sunsetMid     = adjustVibrance(sunsetMid, 0.75 + 0.25 * sWarm);
    sunsetHorizon = mix(sunsetHorizon, sunsetHorizon * vec3(1.10, 0.94, 0.88), clamp(sWarm - 1.0, -0.4, 0.5));

    // Smoothly blend Day <-> Night, then layer Sunset & Magic Hour Twilight
    float sWeight = clamp(st.sunsetFactor * 0.94, 0.0, 1.0);
    float tWeight = clamp(st.twilightFactor * 0.78, 0.0, 1.0);

    st.skyZenith  = mix(nightZenith,  dayZenith,  st.dayFactor);
    st.skyMid     = mix(nightMid,     dayMid,     st.dayFactor);
    st.skyHorizon = mix(nightHorizon, dayHorizon, st.dayFactor);

    st.skyZenith  = mix(st.skyZenith,  sunsetZenith,  max(sWeight * 0.72, tWeight * 0.86));
    st.skyMid     = mix(st.skyMid,     sunsetMid,     max(sWeight * 0.86, tWeight * 0.78));
    st.skyHorizon = mix(st.skyHorizon, sunsetHorizon, max(sWeight * 0.94, tWeight * 0.58));

    st.skyGlowColor = mix(vec3(0.45, 0.72, 1.20), mix(vec3(1.15, 1.02, 0.78), sunsetGlow, sWeight), st.dayFactor);
    st.skyGlowColor = mix(st.skyGlowColor, sunsetGlow * vec3(1.02, 0.76, 0.96), tWeight * 0.65);

    // Direct Sunlight / Moonlight (smooth horizon crossfade with bright moonlit nights!)
    float horizonDip = 1.0 - 0.16 * st.twilightFactor;
    vec3 sunCol  = mix(daySun, sunsetSun, sWeight);
    vec3 moonCol = moonLight * (0.76 * NIGHT_BRIGHTNESS);
    st.directColor = mix(moonCol, sunCol, st.dayFactor) * horizonDip;

    // Ambient Sky & Ground Fill — Luminous night fill guarantees bright, vivid, clear nights!
    vec3 nightFillSky    = nightAmbSky    * (1.00 * NIGHT_BRIGHTNESS);
    vec3 nightFillGround = nightAmbGround * (1.00 * NIGHT_BRIGHTNESS);

    vec3 sunsetAmbSky    = vec3(0.42, 0.24, 0.44);
    vec3 sunsetAmbGround = vec3(0.28, 0.16, 0.22);

    st.ambientSky    = mix(nightFillSky,    dayAmbSky,    st.dayFactor);
    st.ambientGround = mix(nightFillGround, dayAmbGround, st.dayFactor);
    st.ambientSky    = mix(st.ambientSky,    sunsetAmbSky,    sWeight * 0.62);
    st.ambientGround = mix(st.ambientGround, sunsetAmbGround, sWeight * 0.55);

    // Shadow Color Hue Shift
    vec3 sunsetShadow = vec3(0.42, 0.26, 0.72);
    st.shadowTint = mix(nightShadowTint, dayShadowTint, st.dayFactor);
    st.shadowTint = mix(st.shadowTint, sunsetShadow, max(sWeight * 0.78, tWeight * 0.68));

    // Anime Rim Highlight Color
    vec3 dayRim   = mix(vec3(1.15, 1.04, 0.82), vec3(1.55, 0.68, 0.42), sWeight);
    vec3 nightRim = vec3(0.42, 0.76, 1.25) * (0.75 * NIGHT_BRIGHTNESS);
    st.rimColor   = mix(nightRim, dayRim, st.dayFactor);

    // Painterly Cloud Lighting (Creamy sunlit crowns + colorful cerulean/violet undersides)
    vec3 dayCloudLit    = mix(vec3(1.24, 1.18, 1.10), vec3(1.58, 0.66, 0.42), sWeight);
    vec3 dayCloudShad   = mix(vec3(0.20, 0.36, 0.68), vec3(0.32, 0.16, 0.46), sWeight);
    vec3 nightCloudLit  = vec3(0.14, 0.22, 0.42) * (0.85 * NIGHT_BRIGHTNESS);
    vec3 nightCloudShad = vec3(0.035, 0.055, 0.14) * (0.85 * NIGHT_BRIGHTNESS);
    st.cloudLitColor    = mix(nightCloudLit,  dayCloudLit,  st.dayFactor);
    st.cloudShadowColor = mix(nightCloudShad, dayCloudShad, st.dayFactor);

    // Volumetric Godrays
    vec3 dayRay   = mix(vec3(1.15, 0.98, 0.68), vec3(1.55, 0.56, 0.30), sWeight);
    vec3 nightRay = vec3(0.32, 0.64, 1.12) * (0.72 * NIGHT_BRIGHTNESS);
    st.godrayColor = mix(nightRay, dayRay, st.dayFactor);

    // Aerial Perspective Fog Color
    st.fogColorAnime = mix(st.skyHorizon, st.skyMid, 0.36);

    // Rain / Storm Modulation — Moody luminous pastel teal-slate, never murky black!
    if (st.rainMix > 0.001) {
        float stormExtra = clamp(thunderStrengthVal, 0.0, 1.0) * 0.20;
        vec3 rainSkyDay   = vec3(0.24, 0.34, 0.48) * (1.0 - stormExtra);
        vec3 rainSkyNight = vec3(0.06, 0.10, 0.20) * (0.95 * NIGHT_BRIGHTNESS) * (1.0 - stormExtra * 0.45);
        vec3 rainSky      = mix(rainSkyNight, rainSkyDay, st.dayFactor);

        st.skyZenith        = mix(st.skyZenith,        rainSky * 0.75, st.rainMix * 0.72);
        st.skyMid           = mix(st.skyMid,           rainSky * 0.96, st.rainMix * 0.72);
        st.skyHorizon       = mix(st.skyHorizon,       rainSky * 1.18, st.rainMix * 0.75);
        st.directColor     *= mix(1.0, 0.36, st.rainMix);
        st.ambientSky       = mix(st.ambientSky,       rainSky * 1.25, st.rainMix * 0.55);
        st.ambientGround    = mix(st.ambientGround,    rainSky * 0.85, st.rainMix * 0.50);
        st.cloudLitColor    = mix(st.cloudLitColor,    rainSky * 1.10, st.rainMix * 0.65);
        st.cloudShadowColor = mix(st.cloudShadowColor, rainSky * 0.56, st.rainMix * 0.65);
        st.fogColorAnime    = mix(st.fogColorAnime,    rainSky * 1.04, st.rainMix * 0.75);
    }

    return st;
#endif
}

#endif
