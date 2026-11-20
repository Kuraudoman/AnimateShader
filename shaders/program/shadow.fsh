// ==============================================================================
// Shadow Pass — Fragment Shader
// Outputs translucent color tint to shadowcolor0 for colored stained-glass
// shadows while allowing sunlit caustics through crystal water!
// ==============================================================================

#include "/lib/settings.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec4 vColor;
flat in int vBlockId;

layout(location = 0) out vec4 shadowColorOut;

void main() {
    vec4 color = texture(gtexture, vTexCoord) * vColor;

    // Water casts gentle bright aquamarine light rather than solid black shadow
    if (vBlockId == 10001) {
        shadowColorOut = vec4(0.76, 0.96, 1.0, 0.22);
        return;
    }

    if (color.a < max(alphaTestRef, 0.08)) {
        discard;
    }

    shadowColorOut = color;
}
