#include <itowns/precision_qualifier>
#include <logdepthbuf_pars_fragment>
#include <itowns/pitUV>

#include <itowns/color_layers_pars_fragment>
#if MODE == MODE_FINAL
#include <itowns/fog_pars_fragment>
#include <itowns/overlay_pars_fragment>
#include <itowns/lighting_pars_fragment>
#endif
#include <itowns/mode_pars_fragment>

uniform vec3        diffuse;
uniform float       opacity;
varying vec3 vLcc[2];
varying vec3 vLatlon;
varying vec3 vPM;

#include <proj/lcc>
uniform lcc_t proj_lcc[2];

uniform vec4 riskExtent;
uniform sampler2D riskTexture;

// itownsresearch mod
uniform float zDisplacement;
uniform float waterLevel;
// itownsresearch mod over

void main() {
    #include <logdepthbuf_fragment>

#if MODE == MODE_ID

    #include <itowns/mode_id_fragment>

#elif MODE == MODE_DEPTH

    #include <itowns/mode_depth_fragment>

#else

    gl_FragColor = vec4(diffuse, opacity);

    vec4 color;
    #pragma unroll_loop
    for ( int i = 0; i < NUM_FS_TEXTURES; i ++ ) {
        color = getLayerColor( i , colorTextures[ i ], colorLayers[ i ], vUv[ i ]);
        gl_FragColor.rgb = mix(gl_FragColor.rgb, color.rgb, color.a);
    }

  #if defined(DEBUG)
    if (showOutline) {
        #pragma unroll_loop
        for ( int i = 0; i < NUM_CRS; i ++) {
            color = getOutlineColor( outlineColors[ i ], vUv[ i ].xy);
            gl_FragColor.rgb = mix(gl_FragColor.rgb, color.rgb, color.a);
        }
    }
  #endif

    #include <itowns/fog_fragment>
    #include <itowns/lighting_fragment>
    #include <itowns/overlay_fragment>

    // gl_FragColor.rg = mix(gl_FragColor.rg,fract(vLatlon/10.),0.1);
    vec4 lcc0Extent = proj_lcc[0].extent;
    vec4 lcc1Extent = proj_lcc[1].extent;

    if (lcc0Extent.x < vLcc[0].x && vLcc[0].x < lcc0Extent.z && lcc0Extent.y  < vLcc[0].y && vLcc[0].y < lcc0Extent.w)
      gl_FragColor.rg = mix(gl_FragColor.rg,fract(vLcc[0].xy/100000.),0.2);

    vec2 riskUv = (vLcc[0].xy - riskExtent.xy) / (riskExtent.zw - riskExtent.xy);
    if (riskUv.x > 0. && riskUv.y > 0. && riskUv.x < 1. && riskUv.y < 1.) {
      float risk = (texture2D( riskTexture, riskUv).r * 255. - 1.)/(15. - 1.);
      // a nettoyer
      // if (risk > 1./255.) risk = 1. - risk;
      // gl_FragColor.b = mix(gl_FragColor.b, 1., risk);
      // color = getOutlineColor( vec3(1.), riskUv);
      //gl_FragColor.rgb = mix(gl_FragColor.rgb, color.rgb, color.a);
      if (risk < waterLevel / 18. ) {
        //gl_FragColor.r = mix(gl_FragColor.r, 1., risk);
        if (risk > 1./255.) risk = 1. - risk;
        gl_FragColor.b = mix(gl_FragColor.b, 1., risk);
        gl_FragColor.g = mix(gl_FragColor.b, 1., risk);
        color = getOutlineColor( vec3(1.), riskUv);
      }
    }

#endif
}
