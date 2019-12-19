#if NUM_VS_TEXTURES > 0
    if(elevationTextureCount > 0) {
        int i = 0;
        vec3 uv = latlon;
        if (elevationLayers[ i ].crs == CRS_PM) {
            uv = pm;
        } else if (elevationLayers[ i ].crs == CRS_LCC) {
            if (elevationLayers[ i ].crs_id == 0 ) {
              uv = vLcc[0];
            } else if (elevationLayers[ i ].crs_id == 1 ) {
              uv = vLcc[1];
            }
        }
        float elevation = uv.z + getElevation(uv.xy, elevationTextures[ i ], elevationExtents[ i ], elevationLayers[ i ]);
        transformed += elevation * normal;
    }
#endif
