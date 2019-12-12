import * as THREE from 'three';
import TileGeometry from 'Core/TileGeometry';
import Cache from 'Core/Scheduler/Cache';
import computeBuffers from 'Core/Prefab/computeBufferTileGeometry';

export default function newTileGeometry(params) {
    const bufferKey = `${params.disableSkirt ? 0 : 1}_${params.segment}`;
    let promiseGeometry = Cache.get(bufferKey);

    // build geometry if doesn't exist
    if (!promiseGeometry) {
        let resolve;
        promiseGeometry = new Promise((r) => { resolve = r; });
        Cache.set(bufferKey, promiseGeometry);

        return Promise.resolve(computeBuffers(params)).then((buffers) => {
            buffers.index = new THREE.BufferAttribute(buffers.index, 1);
            buffers.position = new THREE.BufferAttribute(buffers.position, 3);

            const geometry = new TileGeometry(params, buffers);

            geometry._count = 0;
            geometry.dispose = () => {
                geometry._count--;
                if (geometry._count == 0) {
                    THREE.BufferGeometry.prototype.dispose.call(geometry);
                    Cache.delete(bufferKey);
                }
            };
            resolve(geometry);
            return geometry;
        });
    }

    return promiseGeometry;
}
