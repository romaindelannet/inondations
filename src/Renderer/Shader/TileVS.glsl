#include <itowns/precision_qualifier>
#include <common>
#include <itowns/project_pars_vertex>
#include <itowns/elevation_pars_vertex>
#include <logdepthbuf_pars_vertex>
uniform vec4 extent;
attribute vec2 l93;
attribute vec2 uv;

struct ColorLayer {
    int textureOffset;
    int crs;
    float effect;
    float opacity;
};


uniform ColorLayer  colorLayers[NUM_FS_TEXTURES];
uniform vec4        colorExtents[NUM_FS_TEXTURES];

uniform mat4 modelMatrix;
uniform bool lightingEnabled;

// itownsresearch mod
uniform float zDisplacement;
// itownsresearch mod over

#if MODE == MODE_FINAL
#include <fog_pars_vertex>
varying vec3        vNormal;
#endif

varying vec2 vWgs84;
varying vec2 vL93;
varying vec2 vPM;
varying vec2 vUv[NUM_FS_TEXTURES];

const float PI_OVER_4 = 0.25*PI;
const float PI_OVER_360 = PI / 360.;
const float PM_MAX = PI * 85.0511287798066 / 90.;

#define TILE_CRS_DEFAULT 0
#define TILE_CRS_CARTESIAN 1
#define TILE_CRS_CARTOGRAPHIC 2
#define TILE_CRS TILE_CRS_CARTESIAN
uniform vec3 inv_radii_squared;

void main() {
        vec2 wgs84 = extent.xy + uv * (extent.zw - extent.xy);

        #if TILE_CRS == TILE_CRS_DEFAULT
        vec3 normal = normalize(inv_radii_squared * position);
        #elif TILE_CRS == TILE_CRS_CARTESIAN
        vec3 normal = vec3(0., 0., 1.);
        #else //  TILE_CRS == TILE_CRS_CARTOGRAPHIC
        vec2 wgs84rad = wgs84 * (PI / 180.);
        vec2 coswgs84 = cos(wgs84rad);
        vec2 sinwgs84 = sin(wgs84rad);
        vec3 normal = vec3(coswgs84.y*coswgs84.x, coswgs84.y*sinwgs84.x, sinwgs84.y);
        #endif

        vec2 pm = vec2(wgs84.x, clamp(log(abs(tan(PI_OVER_4 + PI_OVER_360 * wgs84.y))), -PM_MAX, PM_MAX));

        vec2 uv;
        for ( int i = 0; i < NUM_FS_TEXTURES; i ++ ) {
            uv = wgs84;
            if (colorLayers[ i ].crs == 1) {
                uv = pm;
            }
            vUv[ i ] =  (uv - colorExtents[ i ].xy) / (colorExtents[ i ].zw - colorExtents[ i ].xy);
        }

        vL93 = l93;
        vWgs84 = wgs84;
        vPM = pm;
        #include <begin_vertex>
        #include <itowns/elevation_vertex>

        // itownsresearch mod
        transformed += zDisplacement * normal;
        // itownsresearch mod over

        #include <project_vertex>
        #include <logdepthbuf_vertex>
#if MODE == MODE_FINAL
        #include <fog_vertex>
        vNormal = normalize ( mat3( modelMatrix[0].xyz, modelMatrix[1].xyz, modelMatrix[2].xyz ) * normal );
#endif
}
