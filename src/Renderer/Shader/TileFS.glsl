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
varying vec2 vLcc;
varying vec2 vLatlon;
varying vec2 vPM;

uniform vec4 riskExtent;
uniform sampler2D riskTexture;

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
    vec4 lccExtent = vec4(-357823.2365, 6037008.6939, 1313632.3628, 7230727.3772);
    if (lccExtent.x < vLcc.x && vLcc.x < lccExtent.z && lccExtent.y  < vLcc.y && vLcc.y < lccExtent.w)
      gl_FragColor.rg = mix(gl_FragColor.rg,fract(vLcc/100000.),0.2);

    vec2 riskUv = (vLcc - riskExtent.xy) / (riskExtent.zw - riskExtent.xy);
    if (riskUv.x > 0. && riskUv.y > 0. && riskUv.x < 1. && riskUv.y < 1.) {
      float risk = (texture2D( riskTexture, riskUv).r * 255. - 1.)/(15. - 1.);
      if (risk > 1./255.) risk = 1. - risk;
      gl_FragColor.r = mix(gl_FragColor.r, 1., risk);
      color = getOutlineColor( vec3(1.), riskUv);
      gl_FragColor.rgb = mix(gl_FragColor.rgb, color.rgb, color.a);
    }

#endif
}
