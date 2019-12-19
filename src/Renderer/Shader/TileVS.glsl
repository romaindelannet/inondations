#include <itowns/precision_qualifier>
#include <common>
#include <itowns/project_pars_vertex>
#include <itowns/elevation_pars_vertex>
#include <logdepthbuf_pars_vertex>
uniform vec4 extent;

struct ColorLayer {
    int textureOffset;
    int crs;
    int crs_id;
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

varying vec3 vLatlon;
varying vec3 vLcc[2];
varying vec3 vPM;
varying vec2 vUv[NUM_FS_TEXTURES];

const float PI_OVER_4 = 0.25*PI;
const float PI_OVER_2 = 0.5*PI;
const float PI_OVER_360 = PI / 360.;
const float PM_MAX = PI * 85.0511287798066 / 90.;

uniform vec3 inv_radii_squared;

#include <proj/geocent>
#include <proj/lcc>
uniform geocent_t proj_geocent[1];
uniform lcc_t proj_lcc[2];
const float pm_b = 6378137.;

void main() {
        vec3 tile_position = vec3(extent.xy + position.xy * (extent.zw - extent.xy), position.z * skirtHeight);

        #if CRS_TILE == CRS_GEOCENT
        vec3 geocent = tile_position;
        // vec3 normal = normalize(inv_radii_squared * position);
        vec3 latlon = proj_inverse(proj_geocent[0], geocent);

        #elif CRS_TILE == CRS_PM
        vec3 pm = tile_position;
        vec3 normal = vec3(0., 0., 1.);
        vec3 latlon = pm;
        latlon.y = 2.0 * atan(exp(latlon.y)) - PI_OVER_2;

        #elif CRS_TILE == CRS_LCC
        vec3 lcc = tile_position;
        vec3 normal = vec3(0., 0., 1.);
        vec3 latlon = proj_inverse(proj_lcc[CRS_ID_TILE], lcc);
        vLcc[CRS_ID_TILE] = lcc;

        #elif CRS_TILE == CRS_LATLON
        vec3 latlon = tile_position;
        vec2 coslatlon = cos(latlon.xy);
        vec2 sinlatlon = sin(latlon.xy);
        vec3 normal = vec3(coslatlon.y*coslatlon.x, coslatlon.y*sinlatlon.x, sinlatlon.y);
        #endif

        #if CRS_TILE != CRS_GEOCENT
        vec3 geocent = proj_forward(proj_geocent[0], latlon);
        #endif

        #if CRS_TILE != CRS_LCC || CRS_ID_TILE != 0
        vLcc[0] = proj_forward(proj_lcc[0], latlon);
        #endif

        #if CRS_TILE != CRS_LCC || CRS_ID_TILE != 1
        vLcc[1] = proj_forward(proj_lcc[1], latlon);
        #endif

        #if CRS_TILE != CRS_PM
        vec3 pm = latlon;
        float y = latlon.y; // extent.w; // s0.5*(extent.y+extent.w);
        pm.y = log(abs(tan(PI_OVER_4 + 0.5 * y)));
        /*
        float dy = latlon.y-y;
        pm.y += dy/cos(y);//*(1.0+5.0*dy*tan(y));
        */
        pm.y = clamp(pm.y, -PM_MAX, PM_MAX);
        #endif

        vLatlon = latlon;
        vPM = pm;

        #if CRS_VIEW == CRS_GEOCENT
        vec3 transformed = geocent;
        #elif  CRS_VIEW == CRS_LCC
        vec3 transformed = vLcc[CRS_ID_VIEW];
        #elif  CRS_VIEW == CRS_PM
        vec3 transformed = pm_b * pm;
        #elif  CRS_VIEW == CRS_LATLON
        vec3 transformed = latlon;
        #endif

        vec2 uv;
        for ( int i = 0; i < NUM_FS_TEXTURES; i ++ ) {
            uv = latlon.xy;
            if (colorLayers[ i ].crs == CRS_PM) {
                uv = pm.xy;
            } else if (colorLayers[ i ].crs == CRS_LCC) {
                if (colorLayers[ i ].crs_id == 0 ) {
                  uv = vLcc[0].xy;
                } else if (colorLayers[ i ].crs_id == 1 ) {
                  uv = vLcc[1].xy;
                }
            }
            vUv[ i ] =  (uv - colorExtents[ i ].xy) / (colorExtents[ i ].zw - colorExtents[ i ].xy);
        }


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
