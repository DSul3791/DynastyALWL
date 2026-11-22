// Cuts a triangle list down with meshoptimizer, keeping texture seams (tools/stations/prepare_improved_smithy.py runs it).
// Usage: node simplify_mesh.mjs POS.bin UV.bin IDX.bin OUT_IDX.bin TARGET_TRIANGLES MAX_ERROR
// POS: float32 xyz per vertex, UV: float32 uv per vertex, IDX/OUT_IDX: uint32 triangle corners. Needs meshoptimizer 0.25.0 (npm i meshoptimizer@0.25.0).
import {MeshoptSimplifier} from 'meshoptimizer';
import fs from 'fs';

const [posPath, uvPath, idxPath, outPath, target, maxError] = process.argv.slice(2);
const read = (path, Kind) => { const b = fs.readFileSync(path); return new Kind(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)); };
await MeshoptSimplifier.ready;
// Permissive lets an edge collapse across a seam; the high texture weight (1000) means it only does where both sides' texture coordinates
// agree, so no triangle is left spanning two parts of the texture (a lower weight smeared the coals' orange over the stone).
const [out, err] = MeshoptSimplifier.simplifyWithAttributes(read(idxPath, Uint32Array), read(posPath, Float32Array), 3, read(uvPath, Float32Array), 2,
	[1000, 1000], null, Math.floor(+target) * 3, +maxError, ['Permissive']);
fs.writeFileSync(outPath, Buffer.from(out.buffer, out.byteOffset, out.byteLength));
console.log(JSON.stringify({triangles: out.length / 3, error: err}));
