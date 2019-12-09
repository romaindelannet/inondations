struct ColorLayer {
    int textureOffset;
    int crs;
    float effect;
    float opacity;
};

uniform sampler2D   colorTextures[NUM_FS_TEXTURES];
uniform ColorLayer  colorLayers[NUM_FS_TEXTURES];
uniform int         colorTextureCount;

varying vec2 vUv[NUM_FS_TEXTURES];

float getBorderDistance(vec2 uv) {
    vec2 p2 = min(uv, 1. -uv);
    return min(p2.x, p2.y);
}

vec4 applyWhiteToInvisibleEffect(vec4 color, float intensity) {
    float a = dot(color.rgb, vec3(0.333333333));
    color.a *= 1.0 - pow(abs(a), intensity);
    return color;
}

vec4 applyLightColorToInvisibleEffect(vec4 color, float intensity) {
    float a = max(0.05,1. - length(color.xyz - 1.));
    color.a *= 1.0 - pow(abs(a), intensity);
    color.rgb *= color.rgb * color.rgb;
    return color;
}

#if defined(DEBUG)
uniform bool showOutline;
uniform vec3 outlineColors[NUM_CRS];
uniform float outlineWidth;

vec4 getOutlineColor(vec3 outlineColor, vec2 uv) {
    float alpha = 1. - clamp(getBorderDistance(uv) / outlineWidth, 0., 1.);
    return vec4(outlineColor, alpha);
}
#endif


uniform float minBorderDistance;
vec4 getLayerColor(int textureOffset, sampler2D texture, ColorLayer layer, vec2 uv) {
    if ( textureOffset >= colorTextureCount ) return vec4(0);

    float borderDistance = getBorderDistance(uv.xy);
    if (borderDistance < 0.000) // minBorderDistance )
      return vec4(0);
    vec4 color = texture2D(texture, uv.xy);
    if(color.a > 0.0) {
        if(layer.effect > 2.0) {
            color.rgb /= color.a;
            color = applyLightColorToInvisibleEffect(color, layer.effect);
        } else if(layer.effect > 0.0) {
            color.rgb /= color.a;
            color = applyWhiteToInvisibleEffect(color, layer.effect);
        }
    }

    color.a *= layer.opacity;
    return color;
}
