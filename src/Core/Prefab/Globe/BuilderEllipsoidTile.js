import * as THREE from 'three';
import Coordinates from 'Core/Geographic/Coordinates';
import OBB from 'Renderer/OBB';

class BuilderEllipsoidTile {
    constructor(options = {}) {
        this.tmp = {
            coords: [
                new Coordinates('EPSG:4326', 0, 0),
                new Coordinates('EPSG:4326', 0, 0)],
            position: new THREE.Vector3(),
            dimension: new THREE.Vector2(),
        };

        this.projection = options.projection;
        // Order projection on tiles
        this.uvCount = options.uvCount;
    }
    // prepare params
    // init projected object -> params.projected
    prepare(params) {
        params.nbRow = 2 ** (params.level + 1.0);


        // let's avoid building too much temp objects
        params.projected = { longitude: 0, latitude: 0 };
        params.extent.dimensions(this.tmp.dimension);
    }

    // get center tile in cartesian 3D
    center(extent) {
        return extent.center(this.tmp.coords[0])
            .as(this.projection, this.tmp.coords[1]).toVector3();
    }

    // get position 3D cartesian
    vertexPosition(params) {
        this.tmp.coords[0].setFromValues(
            params.projected.longitude,
            params.projected.latitude);

        this.tmp.coords[0].as(this.projection, this.tmp.coords[1]).toVector3(this.tmp.position);
        return this.tmp.position;
    }

    // get normal for last vertex
    vertexNormal() {
        return this.tmp.coords[1].geodesicNormal;
    }

    // coord u tile to projected
    uProjecte(u, params) {
        params.projected.longitude = params.extent.west + u * this.tmp.dimension.x;
    }

    // coord v tile to projected
    vProjecte(v, params) {
        params.projected.latitude = params.extent.south + v * this.tmp.dimension.y;
    }

    // use for region for adaptation boundingVolume
    OBB(boundingBox) {
        return new OBB(boundingBox.min, boundingBox.max);
    }
}

export default BuilderEllipsoidTile;
