#if NUM_VS_TEXTURES > 0
    if(elevationTextureCount > 0) {
        int i = 0;
        vec3 uv = latlon;
        if (elevationLayers[ i ].crs == CRS_PM) {
            uv = vec3(pm, latlon.z);
        } else if (elevationLayers[ i ].crs == CRS_LCC) {
            uv = lcc;
        }
        float elevation = uv.z + getElevation(uv.xy, elevationTextures[ i ], elevationExtents[ i ], elevationLayers[ i ]);
        transformed += elevation * normal;
    }
#endif
