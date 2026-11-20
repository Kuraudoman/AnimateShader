#ifndef ANIMATE_SETTINGS_GLSL
#define ANIMATE_SETTINGS_GLSL

// ==============================================================================
// AnimateShader (星穹幻光) — Central Shader Options & Pipeline Constants
// ==============================================================================

// --- Lighting & Brightness Balance ---
#define NIGHT_BRIGHTNESS 1.35 // [0.8 1.0 1.2 1.35 1.5 1.75 2.0] Night ambient & moonlight brightness
#define CAVE_BRIGHTNESS 1.1 // [0.6 0.8 1.0 1.1 1.3 1.5] Minimum cave/indoor visibility floor
#define OVERALL_EXPOSURE 1.00 // [0.80 0.90 0.95 1.00 1.05 1.10 1.20] Global brightness balance
#define ANIME_SHADING_STYLE 1 // [0 1 2] 0: Smooth Fantasy, 1: Soft Anime Cel, 2: Crisp Anime Cel
#define RIM_LIGHT_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0] Anime rim highlight intensity
#define BLOCKLIGHT_STRENGTH 1.15 // [0.6 0.8 1.0 1.15 1.35 1.6] Torch and block light intensity
#define DYNAMIC_HANDLIGHT // Dynamic light from held glowing items in main/off hand
#define SSAO_ENABLED // Subtle color-tinted screen-space ambient occlusion
#define FOLIAGE_SSS // Translucent backlit glow on leaves, cherry blossoms, and grass

// --- Color Expression & Tone Mapping ---
#define COLOR_PALETTE 0 // [0 1 2 3] 0: Shinkai Azure, 1: Sakura Fantasy, 2: Emerald Ghibli, 3: Ethereal Violet
#define COLOR_VIBRANCE 1.15 // [0.80 0.90 1.00 1.10 1.15 1.25 1.35] Selective color vibrance
#define SHADOW_COLOR_TINT 1.0 // [0.0 0.5 1.0 1.5] Anime cool cerulean/lavender shadow hue shift
#define SUNSET_WARMTH 1.15 // [0.6 0.8 1.0 1.15 1.35] Golden & magic hour sunset richness
#define TONEMAP_CONTRAST 1.00 // [0.85 0.92 1.00 1.08 1.15] Filmic tone map contrast

// --- Dazzling Effects & Bloom ---
#define BLOOM_ENABLED // Multi-scale silky HDR anime bloom
#define BLOOM_INTENSITY 1.0 // [0.4 0.6 0.8 1.0 1.2 1.4 1.6] Bloom radiance
#define ANAMORPHIC_STREAK // Cinematic horizontal anime starlight streaks
#define GODRAYS_ENABLED // Volumetric crepuscular sunbeams & moonbeams
#define GODRAYS_STRENGTH 1.0 // [0.4 0.7 1.0 1.3 1.6] Godray beam intensity
#define EMISSIVE_GLOW 1.2 // [0.6 0.8 1.0 1.2 1.5 1.8] Colorful glow on emissive blocks
#define SUN_LENS_FLARE // Delicate anime starburst & halo flare near sun/moon
#define VIGNETTE_STRENGTH 0.2 // [0.0 0.2 0.4 0.6] Gentle atmospheric edge vignette

// --- Fantasy Sky & Clouds ---
#define ANIME_CLOUDS // Layered volumetric painterly anime cumulus & cirrus clouds
#define CLOUD_QUALITY 1 // [0 1 2] 0: Fast, 1: Detailed, 2: Ultra
#define FANTASY_AURORA // Shimmering fantasy aurora curtains in the night sky
#define AURORA_STRENGTH 1.1 // [0.5 0.8 1.1 1.35 1.6] Aurora brilliance
#define MILKY_WAY // Luminous starry Milky Way nebula band at night
#define SHOOTING_STARS // Occasional meteors streaking across the night sky
#define ATMOSPHERIC_FOG 0.8 // [0.0 0.4 0.8 1.0 1.3] Sky-matched pastel aerial perspective fog

// --- Water & Living World ---
#define WATER_SSR // Real-time screen-space reflections on water and ice
#define WATER_CAUSTICS // Animated sparkling caustics projected underwater
#define WATER_SPARKLES // Twinkling anime star-glints on wave crests
#define WATER_CLARITY 1.0 // [0.5 0.75 1.0 1.25 1.5] Crystal aquamarine water clarity
#define WAVING_FOLIAGE // Wind-swaying leaves, flowers, grass, and crops
#define WET_REFLECTIONS // Luminous wet specular sheen during rain

// --- Shadow Settings ---
#define SHADOW_QUALITY 1 // [0 1 2] 0: Fast, 1: Soft PCF, 2: Smooth High-Sample PCF
#define COLORED_SHADOWS // Stained glass projects colored light onto surfaces
#define NIGHT_SHADOWS // Gentle moonlight shadows at night (never pitch black)

// --- Iris / OptiFine Pipeline Constants ---
const int shadowMapResolution = 2048; // [1024 2048 3072 4096]
const float shadowDistance = 128.0; // [64.0 96.0 128.0 160.0 192.0]
const float shadowDistanceRenderMul = 1.0;
const float entityShadowDistanceMul = 0.75;
const float sunPathRotation = -32.0;
const float ambientOcclusionLevel = 0.72;
const float wetnessHalflife = 100.0;
const float drynessHalflife = 200.0;
const float eyeBrightnessHalflife = 4.0;
const float centerDepthHalflife = 1.5;

#endif
