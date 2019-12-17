#include <itowns/precision_qualifier>
#include <common>
#include <itowns/project_pars_vertex>
#include <itowns/elevation_pars_vertex>
#include <logdepthbuf_pars_vertex>
uniform vec4 extent;

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
uniform float skirtHeight;

// itownsresearch mod
uniform float zDisplacement;
// itownsresearch mod over

#if MODE == MODE_FINAL
#include <fog_pars_vertex>
varying vec3        vNormal;
#endif

varying vec2 vLatlon;
varying vec2 vLcc;
varying vec2 vPM;
varying vec2 vUv[NUM_FS_TEXTURES];

const float PI_OVER_4 = 0.25*PI;
const float PI_OVER_2 = 0.5*PI;
const float PI_OVER_360 = PI / 360.;
const float PM_MAX = PI * 85.0511287798066 / 90.;

uniform vec3 inv_radii_squared;

#include <proj/geocent>
#include <proj/lcc>
uniform geocent_t proj_geocent[1];
uniform lcc_t proj_lcc[1];

void main() {
        vec3 tile_position = vec3(extent.xy + position.xy * (extent.zw - extent.xy), position.z * skirtHeight);

        #if CRS_TILE == CRS_GEOCENT
        vec3 normal = normalize(inv_radii_squared * position);

        #elif CRS_TILE == CRS_PM
        vec3 normal = vec3(0., 0., 1.);
        vec2 pm = tile_position.xy;
        vec3 transformed = tile_position;

        vec3 latlon = tile_position;
        float b = 6378137.;
        latlon.xy /= b;
        latlon.x /= PI / 180.;
        latlon.y = (atan(exp(latlon.y))  - PI_OVER_4 ) / PI_OVER_360;
        vec3 latlonrad = vec3(latlon.xy * (PI / 180.), latlon.z);
        vec3 lcc = proj_forward(proj_lcc[0], latlonrad);

        #elif CRS_TILE == CRS_LCC
        vec3 normal = vec3(0., 0., 1.);
        vec3 lcc = tile_position;
        vec3 latlonrad = proj_inverse(proj_lcc[0], lcc);
        vec3 latlon = vec3(latlonrad.xy * (180. / PI), latlonrad.z);
        vec3 transformed = lcc;

        #else //  CRS_TILE == CRS_LATLON

        vec3 latlon = tile_position;
        vec3 latlonrad = vec3(latlon.xy * (PI / 180.), latlon.z);
        vec2 coslatlon = cos(latlonrad.xy);
        vec2 sinlatlon = sin(latlonrad.xy);
        vec3 normal = vec3(coslatlon.y*coslatlon.x, coslatlon.y*sinlatlon.x, sinlatlon.y);

        vec3 geocent = proj_forward(proj_geocent[0], latlonrad);
        vec3 lcc = proj_forward(proj_lcc[0], latlonrad);
        vec3 transformed = geocent;
        #endif


        #if CRS_TILE != CRS_PM
        float b = 6378137.;
        vec2 pm = vec2(latlon.x * b * PI / 180., b * clamp(log(abs(tan(PI_OVER_4 + PI_OVER_360 * latlon.y))), -PM_MAX, PM_MAX));
        // vec2 pm = vec2(latlon.x, clamp(log(abs(tan(PI_OVER_4 + PI_OVER_360 * latlon.y))), -PM_MAX, PM_MAX));
        #endif

        vec2 uv;
        for ( int i = 0; i < NUM_FS_TEXTURES; i ++ ) {
            uv = latlon.xy;
            if (colorLayers[ i ].crs == CRS_PM) {
                uv = pm;
            } else if (colorLayers[ i ].crs == CRS_LCC) {
                uv = lcc.xy;
            }
            vUv[ i ] =  (uv - colorExtents[ i ].xy) / (colorExtents[ i ].zw - colorExtents[ i ].xy);
        }

        vLcc = lcc.xy;
        vLatlon = latlon.xy;
        vPM = pm;


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
