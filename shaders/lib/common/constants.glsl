#ifndef ANIMATE_CONSTANTS_GLSL
#define ANIMATE_CONSTANTS_GLSL

// ==============================================================================
// Buffer Format Declarations (Parsed by Iris / OptiFine)
// ==============================================================================
/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
const int shadowcolor0Format = RGBA8;
*/

// ==============================================================================
// Mathematical Constants
// ==============================================================================
const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float HALF_PI = 1.57079632679;
const float INV_PI = 0.31830988618;

// ==============================================================================
// Material IDs (Stored in colortex1.w in [0.0, 1.0])
// ==============================================================================
const float MAT_DEFAULT     = 0.05; // Standard opaque terrain
const float MAT_FOLIAGE     = 0.15; // Grass, flowers, crops (backlit SSS)
const float MAT_LEAVES      = 0.22; // Tree canopies, cherry leaves (strong backlit SSS)
const float MAT_POLISHED    = 0.30; // Gems, metals, quartz, glazed/polished blocks
const float MAT_EMISSIVE    = 0.40; // Emissive blocks (tint encoded in colortex2.z)
const float MAT_ENTITY      = 0.55; // Players, mobs, items
const float MAT_BLOCK_ENT   = 0.65; // Chests, signs, banners, enchanting tables
const float MAT_PORTAL_END  = 0.75; // End portal / gateway cosmic shader
const float MAT_HAND        = 0.85; // First-person hand / held tools (special depth)
const float MAT_UNLIT       = 0.96; // Beacon beam, outlines, UI-like fullbright elements

// ==============================================================================
// Emissive Color Categories (Encoded in colortex2.z when MAT_EMISSIVE)
// ==============================================================================
const float EMIS_WARM_GOLD   = 0.10; // Torch, lantern, glowstone, froglight ochre
const float EMIS_FIERY_LAVA  = 0.25; // Lava, magma, fire
const float EMIS_SOUL_CYAN   = 0.40; // Soul lantern/fire, sculk, trial spawner
const float EMIS_SEA_AQUA    = 0.55; // Sea lantern, conduit, verdant froglight, glow berries
const float EMIS_MAGIC_VIOLET= 0.70; // Amethyst, crying obsidian, enchanting, pearlescent
const float EMIS_RUBY_RED    = 0.85; // Redstone torch/ore/block
const float EMIS_STAR_PEARL  = 0.98; // End rod, beacon, firefly bush

vec3 getEmissiveTint(float code) {
    if (code < 0.18) return vec3(1.15, 0.78, 0.38); // Honey gold
    if (code < 0.32) return vec3(1.30, 0.50, 0.18); // Fiery amber-orange
    if (code < 0.48) return vec3(0.32, 0.96, 1.25); // Mystical soul cyan
    if (code < 0.62) return vec3(0.45, 1.15, 1.05); // Crystal sea aqua
    if (code < 0.78) return vec3(0.95, 0.52, 1.32); // Fantasy amethyst violet-pink
    if (code < 0.92) return vec3(1.25, 0.28, 0.36); // Vivid ruby redstone
    return vec3(1.10, 1.06, 1.22);                  // Radiant pearlescent starlight
}

// Helper to test material bands safely with float precision tolerance
bool isMat(float id, float target) {
    return abs(id - target) < 0.035;
}

#endif
