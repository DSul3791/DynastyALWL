// Cuts a welded triangle list down by its shape alone with meshoptimizer (tools/items/prepare_item_model.py runs it, then bakes new textures).
// Usage: node simplify_shape.mjs POS.bin IDX.bin OUT_IDX.bin TARGET_TRIANGLES MAX_ERROR [LockBorder]
// LockBorder keeps the open edges where one part of a mesh was cut from the rest, so parts cut apart join again.
// POS: float32 xyz per vertex, IDX/OUT_IDX: uint32 triangle corners. Needs meshoptimizer 0.25.0 (npm i meshoptimizer@0.25.0).
import {MeshoptSimplifier} from 'meshoptimizer';
import fs from 'fs';

const [posPath, idxPath, outPath, target, maxError, ...flags] = process.argv.slice(2);
const read = (path, Kind) => { const b = fs.readFileSync(path); return new Kind(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)); };
await MeshoptSimplifier.ready;
const [out, err] = MeshoptSimplifier.simplify(read(idxPath, Uint32Array), read(posPath, Float32Array), 3, Math.floor(+target) * 3, +maxError, flags);
fs.writeFileSync(outPath, Buffer.from(out.buffer, out.byteOffset, out.byteLength));
console.log(JSON.stringify({triangles: out.length / 3, error: err}));
