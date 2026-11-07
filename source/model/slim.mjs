import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune, dedup, weld, simplify, quantize, textureCompress, meshopt } from '@gltf-transform/functions';
import { MeshoptSimplifier, MeshoptEncoder, MeshoptDecoder } from 'meshoptimizer';
await MeshoptEncoder.ready; await MeshoptDecoder.ready;
import sharp from 'sharp';
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.encoder': MeshoptEncoder, 'meshopt.decoder': MeshoptDecoder });
const doc = await io.read(process.argv[2]);
const root = doc.getRoot();
// keep only the "Scene" scene
for (const s of root.listScenes()) if (s.getName() !== 'Scene') s.dispose();
root.setDefaultScene(root.listScenes()[0]);
// drop UV sets beyond TEXCOORD_1 (three r128 reads uv and uv2 only)
for (const m of root.listMeshes()) for (const p of m.listPrimitives()) for (const sem of p.listSemantics()) if (/^TEXCOORD_[2-9]/.test(sem)) p.setAttribute(sem, null);
await doc.transform(
  prune(), dedup(),
  weld({ tolerance: 0.0001 }),
  simplify({ simplifier: MeshoptSimplifier, ratio: Number(process.argv[4] || 0.3), error: Number(process.argv[5] || 0.0015), lockBorder: false }),
  textureCompress({ encoder: sharp, targetFormat: 'webp', resize: [512, 512], quality: 80, slots: /^(?!baseColorTexture).*/ }),
  textureCompress({ encoder: sharp, targetFormat: 'webp', resize: [1024, 1024], quality: 85, slots: /baseColorTexture/ }),
  prune(),
  meshopt({ encoder: MeshoptEncoder, level: 'medium', quantizePosition: 14, quantizeNormal: 10, quantizeTexcoord: 12 })
);
await io.write(process.argv[3], doc);
let tris = 0; for (const m of root.listMeshes()) for (const p of m.listPrimitives()) { const i = p.getIndices(); tris += (i ? i.getCount() : p.getAttribute('POSITION').getCount()) / 3; }
console.log('tris', tris, 'meshes', root.listMeshes().length, 'nodes', root.listNodes().length);
