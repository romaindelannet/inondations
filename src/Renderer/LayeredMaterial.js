import * as THREE from 'three';
import TileVS from 'Renderer/Shader/TileVS.glsl';
import TileFS from 'Renderer/Shader/TileFS.glsl';
import ShaderUtils from 'Renderer/Shader/ShaderUtils';
import Capabilities from 'Core/System/Capabilities';
import RenderMode from 'Renderer/RenderMode';
import MaterialLayer from 'Renderer/MaterialLayer';
import Extent from 'Core/Geographic/Extent';

const fullExtent = new THREE.Vector4(-180, -90, 180, 90);

const riskExtent = new THREE.Vector4(0, 0, 0, 0);
const riskTexture = new THREE.TextureLoader().load('images/risk.png', (texture) => {
    fetch('images/risk.wld').then(response => response.text()).then((worldFile) => {
        texture.extent = new Extent('EPSG:2154', 0, 0, 0, 0).setFromWorldFile(worldFile, texture.image);
        texture.extent.toVector4(riskExtent);
    });
});

// from three.js packDepthToRGBA
const UnpackDownscale = 255 / 256; // 0..1 -> fraction (excluding 1)
const bitSh = new THREE.Vector4(
    UnpackDownscale / (256.0 * 256.0 * 256.0),
    UnpackDownscale / (256.0 * 256.0),
    UnpackDownscale / 256.0,
    UnpackDownscale);

export function unpack1K(color, factor) {
    return factor ? bitSh.dot(color) * factor : bitSh.dot(color);
}

// comes from glsl-proj4
const proj_l93 = {
    lon0: 0.05235987755982989,
    p0: new THREE.Vector3(700000, 6600000, 0),
    k0: 1,
    e: 0.08181919104281582,
    ns: 0.725607765053269,
    af0: 11754255.426096005,
    rh: 6055612.049875989,
};
const proj_wgs84 = {
    a: 6378137,
    b: 6356752.314245179,
    e: 0.08181919084262149,
    eprime: 0.08209443794969568,
    e2: 0.006694379990141283,
    p0: new THREE.Vector3(0, 0, 0),
    k0: 1,
};

// Max sampler color count to LayeredMaterial
// Because there's a statement limitation to unroll, in getColorAtIdUv method
const maxSamplersColorCount = 15;
const samplersElevationCount = 1;

const PI_OVER_4 = 0.25 * Math.PI;
const PI_OVER_360 = Math.PI / 360.0;

export function getMaxColorSamplerUnitsCount() {
    const maxSamplerUnitsCount = Capabilities.getMaxTextureUnitsCount();
    return Math.min(maxSamplerUnitsCount - samplersElevationCount, maxSamplersColorCount);
}

function updateLayersUniforms(uniforms, olayers, max) {
    // prepare convenient access to elevation or color uniforms
    const layers = uniforms.layers.value;
    const textures = uniforms.textures.value;
    const extents = uniforms.extents.value;
    const textureCount = uniforms.textureCount;

    // flatten the 2d array [i,j] -> layers[_layerIds[i]].textures[j]
    let count = 0;
    for (const layer of olayers) {
        layer.textureOffset = count;
        for (let i = 0, il = layer.textures.length; i < il; ++i, ++count) {
            const t = layer.textures[i];
            if (count < max && t.coords) {
                let extent = t.coords;
                if (extent.crs == 'WMTS:PM') {
                    const b = 6378137;
                    extent = extent.as('EPSG:3857');
                    /* equivalent to
                    extent = extent.as('EPSG:4326');
                    extent.east = extent.east * b * 2 * PI_OVER_360;
                    extent.west = extent.west * b * 2 * PI_OVER_360;
                    extent.south = Math.log(Math.tan(PI_OVER_4 + PI_OVER_360 * extent.south)) * b;
                    extent.north = Math.log(Math.tan(PI_OVER_4 + PI_OVER_360 * extent.north)) * b;
                    */
                    /*
                    extent.east /= b * 2 * PI_OVER_360;
                    extent.west /= b * 2 * PI_OVER_360;
                    extent.south /= b;
                    extent.north /= b;
                    */
                } else if (extent.crs == 'WMTS:WGS84') {
                    extent = extent.as('EPSG:4326');
                } else if (extent.crs == 'WMTS:TMS:3946') {
                    extent = extent.as('EPSG:3946');
                } else {
                    console.warn(t.coords.crs, ' extents are not handled yet');
                }
                extents[count].set(extent.west, extent.south, extent.east, extent.north);
                textures[count] = t;
                layers[count] = layer;
            }
        }
    }
    if (count > max) {
        console.warn(`LayeredMaterial: Not enough texture units (${max} < ${count}), excess textures have been discarded.`);
    }
    textureCount.value = count;
}

function setDefineMapping(object, PROPERTY, mapping) {
    Object.keys(mapping).forEach((key) => {
        object.defines[`${PROPERTY}_${key}`] = mapping[key];
    });
}

function setDefineProperty(object, property, PROPERTY, initValue) {
    object.defines[PROPERTY] = initValue;
    Object.defineProperty(object, property, {
        get: () => object.defines[PROPERTY],
        set: (value) => {
            if (object.defines[PROPERTY] != value) {
                object.defines[PROPERTY] = value;
                object.needsUpdate = true;
            }
        },
    });
}

function setUniformProperty(object, property, initValue) {
    object.uniforms[property] = new THREE.Uniform(initValue);
    Object.defineProperty(object, property, {
        get: () => object.uniforms[property].value,
        set: (value) => {
            if (object.uniforms[property].value != value) {
                object.uniforms[property].value = value;
            }
        },
    });
}

export const ELEVATION_MODES = {
    RGBA: 0,
    COLOR: 1,
    DATA: 2,
};

export const CRS_DEFINES = {
    LATLON: 0,
    LCC: 1,
    GEOCENT: 2,
    PM: 3,
};

export function tile_crs_define(crs) {
    // layer.parent.tileMatrixSets.indexOf(CRS.formatToTms(layer.projection))
    if (crs == 'EPSG:4326' || crs == 'WMTS:WGS84') {
        return CRS_DEFINES.LATLON;
    } else if (crs == 'EPSG:3857' || crs == 'WMTS:PM') {
        return CRS_DEFINES.PM;
    } else if (crs == 'EPSG:2154' || crs == 'EPSG:3946') {
        return CRS_DEFINES.LCC;
    } else {
        console.error(crs, ' extents are not handled yet');
        return -1;
    }
}

let nbSamplers;
const fragmentShader = [];
class LayeredMaterial extends THREE.RawShaderMaterial {
    constructor(options = {}, crsCount) {
        super(options);

        crsCount = 3; // WGS84, PM, L93 // TODO !!!

        nbSamplers = nbSamplers || [samplersElevationCount, getMaxColorSamplerUnitsCount()];

        this.defines.NUM_VS_TEXTURES = nbSamplers[0];
        this.defines.NUM_FS_TEXTURES = nbSamplers[1];
        this.defines.USE_FOG = 1;
        this.defines.NUM_CRS = crsCount;

        setDefineMapping(this, 'CRS', CRS_DEFINES);
        setDefineMapping(this, 'ELEVATION', ELEVATION_MODES);
        setDefineMapping(this, 'MODE', RenderMode.MODES);
        setDefineProperty(this, 'crs', 'CRS_TILE', CRS_DEFINES.LATLON);
        setDefineProperty(this, 'mode', 'MODE', RenderMode.MODES.FINAL);

        if (__DEBUG__) {
            this.defines.DEBUG = 1;
            const outlineColors = [];
            for (let i = 0; i < this.defines.NUM_CRS; ++i) {
                outlineColors.push(new THREE.Vector3(1.0, i / (crsCount - 1.0), 0.0));
            }
            setUniformProperty(this, 'showOutline', true);
            setUniformProperty(this, 'outlineWidth', 0.008);
            setUniformProperty(this, 'outlineColors', outlineColors);
        }

        if (Capabilities.isLogDepthBufferSupported()) {
            this.defines.USE_LOGDEPTHBUF = 1;
            this.defines.USE_LOGDEPTHBUF_EXT = 1;
        }

        this.vertexShader = TileVS;
        fragmentShader[crsCount] = fragmentShader[crsCount] || ShaderUtils.unrollLoops(TileFS, this.defines);
        this.fragmentShader = fragmentShader[crsCount];

        // Color uniforms
        setUniformProperty(this, 'diffuse', new THREE.Color(0.04, 0.23, 0.35));
        setUniformProperty(this, 'opacity', this.opacity);
        setUniformProperty(this, 'skirtHeight', 0.0);

        // Lighting uniforms
        setUniformProperty(this, 'lightingEnabled', false);
        setUniformProperty(this, 'lightPosition', new THREE.Vector3(-0.5, 0.0, 1.0));

        // Misc properties
        setUniformProperty(this, 'fogDistance', 1000000000.0);
        setUniformProperty(this, 'fogColor', new THREE.Color(0.76, 0.85, 1.0));
        setUniformProperty(this, 'overlayAlpha', 0);
        setUniformProperty(this, 'overlayColor', new THREE.Color(1.0, 0.3, 0.0));
        setUniformProperty(this, 'objectId', 0);
        setUniformProperty(this, 'extent', fullExtent.clone());

        // itownsresearch mod
        // Z displacement (used for water flooding for example)
        setUniformProperty(this, 'zDisplacement', 0);
        // itownsresearch mod over

        // > 0 produces gaps,
        // < 0 causes oversampling of textures
        // = 0 causes sampling artefacts due to bad estimation of texture-uv gradients
        // best is a small negative number
        setUniformProperty(this, 'minBorderDistance', -0.01);

        // LayeredMaterialLayers
        this.layers = [];
        this.elevationLayerIds = [];
        this.colorLayerIds = [];

        // elevation layer uniforms, to be updated using updateUniforms()
        this.uniforms.elevationLayers = new THREE.Uniform(new Array(nbSamplers[0]).fill({}));
        this.uniforms.elevationTextures = new THREE.Uniform(new Array(nbSamplers[0]).fill(null));
        this.uniforms.elevationExtents = new THREE.Uniform(new Array(nbSamplers[0]).fill(null));
        this.uniforms.elevationTextureCount = new THREE.Uniform(0);


        // color layer uniforms, to be updated using updateUniforms()
        this.uniforms.colorLayers = new THREE.Uniform(new Array(nbSamplers[1]).fill({}));
        this.uniforms.colorTextures = new THREE.Uniform(new Array(nbSamplers[1]).fill(null));
        this.uniforms.colorExtents = new THREE.Uniform(new Array(nbSamplers[1]).fill(null));
        this.uniforms.colorTextureCount = new THREE.Uniform(0);


        for (let i = 0; i < nbSamplers[0]; ++i) {
            this.uniforms.elevationExtents.value[i] = fullExtent.clone();
        }
        for (let i = 0; i < nbSamplers[1]; ++i) {
            this.uniforms.colorExtents.value[i] = fullExtent.clone();
        }

        this.uniforms.proj_geocent = new THREE.Uniform([proj_wgs84]);
        this.uniforms.proj_lcc = new THREE.Uniform([proj_l93]);

        this.uniforms.riskTexture = new THREE.Uniform(riskTexture);
        this.uniforms.riskExtent = new THREE.Uniform(riskExtent);
    }

    getUniformByType(type) {
        return {
            layers: this.uniforms[`${type}Layers`],
            textures: this.uniforms[`${type}Textures`],
            extents: this.uniforms[`${type}Extents`],
            textureCount: this.uniforms[`${type}TextureCount`],
        };
    }

    setExtent(extent) {
        this.extent.set(extent.west, extent.south, extent.east, extent.north);
        this.crs = tile_crs_define(extent.crs);
        // console.log(this.crs, 'tile', extent.crs);
    }

    updateLayersUniforms() {
        const colorlayers = this.layers.filter(l => this.colorLayerIds.includes(l.id) && l.visible && l.opacity > 0);
        colorlayers.sort((a, b) => this.colorLayerIds.indexOf(a.id) - this.colorLayerIds.indexOf(b.id));
        updateLayersUniforms(this.getUniformByType('color'), colorlayers, this.defines.NUM_FS_TEXTURES);

        // if (this.elevationLayerIds.some(id => this.getLayer(id)) ||
        //    (this.uniforms.elevationTextureCount.value && !this.elevationLayerIds.length)) {
        const elevationLayers = this.getElevationLayer() ? [this.getElevationLayer()] : [];
        updateLayersUniforms(this.getUniformByType('elevation'), elevationLayers, this.defines.NUM_VS_TEXTURES);
        // console.log(this.uniforms.elevationExtents.value[0]);
        // }

        this.layersNeedUpdate = false;
    }

    dispose() {
        this.dispatchEvent({ type: 'dispose' });
        this.layers.forEach(l => l.dispose(false));
        this.layers.length = 0;
        this.layersNeedUpdate = true;
    }

    // TODO: rename to setColorLayerIds and add setElevationLayerIds ?
    setSequence(sequenceLayer) {
        this.colorLayerIds = sequenceLayer;
        this.layersNeedUpdate = true;
    }

    setSequenceElevation(layerId) {
        this.elevationLayerIds[0] = layerId;
        this.layersNeedUpdate = true;
    }

    removeLayer(layerId) {
        const index = this.layers.findIndex(l => l.id === layerId);
        if (index > -1) {
            this.layers[index].dispose();
            this.layers.splice(index, 1);
            const idSeq = this.colorLayerIds.indexOf(layerId);
            if (idSeq > -1) {
                this.colorLayerIds.splice(idSeq, 1);
            } else {
                this.elevationLayerIds = [];
            }
        }
    }

    addLayer(layer) {
        if (layer.id in this.layers) {
            console.warn('The "{layer.id}" layer was already present in the material, overwritting.');
        }
        const lml = new MaterialLayer(this, layer);
        this.layers.push(lml);
        if (layer.isColorLayer) {
            this.setSequence(layer.parent.colorLayersOrder);
        } else {
            this.setSequenceElevation(layer.id);
        }
        return lml;
    }

    getLayer(id) {
        return this.layers.find(l => l.id === id);
    }

    getLayers(ids) {
        return this.layers.filter(l => ids.includes(l.id));
    }

    getElevationLayer() {
        return this.layers.find(l => l.id === this.elevationLayerIds[0]);
    }

    setElevationScale(scale) {
        if (this.elevationLayerIds.length) {
            this.getElevationLayer().scale = scale;
        }
    }
}

export default LayeredMaterial;
