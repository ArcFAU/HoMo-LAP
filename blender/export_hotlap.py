# Hot Lap car export. Run in a BACKGROUND Blender only; it never saves livery.blend:
#   blender -b "E:\UE\livery\livery.blend" --python "E:\HOT LAP\blender\export_hotlap.py"
# Everything below changes only this background copy in memory.
import bpy, os, json, shutil, traceback, time
out = r'E:\HOT LAP\blender'
info = {'started': time.time()}
try:
    sc = bpy.data.scenes['Scene']
    bpy.context.window.scene = sc if bpy.context.window else sc
except Exception as e:
    info['scene_note'] = str(e)
try:
    sc = bpy.context.scene
    # back plate (SOLID003) sits in the hidden 07_Hardware collection: show it in this background copy only
    for name in ['SOLID003']:
        ob = bpy.data.objects.get(name)
        if ob and ob.name not in bpy.data.collections['01_Bodywork'].objects: bpy.data.collections['01_Bodywork'].objects.link(ob)
    bpy.context.view_layer.update()
    vis = [o for o in sc.objects if o.type == 'MESH' and o.visible_get()]
    info['extra_visible'] = [o.name for o in vis if o.name == 'SOLID003']
    # Livery panels use OBJECT-linked "[LIVERY]" materials over the original DATA materials. With modifiers
    # applied (Decimate below), the glTF exporter takes the mesh's DATA material and the livery is lost
    # (nosecone, MONO, main elements, undertray ...). Copy the object material into the mesh slot first.
    # The game swaps every "[LIVERY]" material for its own (matched by name) and projects the livery itself,
    # so only the names matter. Their node trees (projection group, UDIM image) make the glTF exporter fail
    # once they are exported, so plain stand-ins with the same names are exported instead.
    standins = []
    for m in [m for m in bpy.data.materials if m.name.endswith('[LIVERY]')]:
        name = m.name; m.name = name + '__orig'
        st = bpy.data.materials.new(name); st.use_nodes = True
        bsdf = next((n for n in st.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf:
            bsdf.inputs['Base Color'].default_value = (0.06, 0.06, 0.07, 1.0); bsdf.inputs['Roughness'].default_value = 0.4
        m.user_remap(st); standins.append(name)
    info['livery_standins'] = standins
    relinked = []
    for o in vis:
        if not any(s.link == 'OBJECT' for s in o.material_slots): continue
        if o.data.users > 1: o.data = o.data.copy()
        for i, s in enumerate(o.material_slots):
            if s.link == 'OBJECT' and s.material:
                mat = s.material; o.data.materials[i] = mat; s.link = 'DATA'; relinked.append(o.name)
    info['relinked_livery'] = sorted(set(relinked))
    before = 0
    for o in vis:
        t = sum(len(p.vertices) - 2 for p in o.data.polygons); before += t
        if t > 3000:
            m = o.modifiers.new('HL_dec', 'DECIMATE'); m.ratio = max(0.1, 3000.0 / t); m.use_collapse_triangulate = True
    info['objects'] = len(vis); info['tris_before'] = before
    glb = os.path.join(out, 'faumax_tau.glb')
    if os.path.exists(glb): os.replace(glb, os.path.join(out, 'faumax_tau.prev.glb'))   # keep the previous export
    kw = dict(filepath=glb, export_format='GLB', use_visible=True, export_apply=True, export_yup=True,
              export_animations=False, export_cameras=False, export_lights=False, export_image_format='JPEG')
    try:
        bpy.ops.export_scene.gltf(**kw)
    except TypeError as e:
        info['retry'] = str(e)
        bpy.ops.export_scene.gltf(filepath=kw['filepath'], export_format='GLB', use_visible=True, export_apply=True)
    imgs = {}
    for name in ['LIVERY_Left', 'LIVERY_Right', 'LIVERY_Top', 'LIVERY_Front', 'LIVERY_Rear']:
        im = bpy.data.images[name]; src = bpy.path.abspath(im.filepath)
        dst = os.path.join(out, name + '.png'); shutil.copyfile(src, dst); imgs[name] = os.path.getsize(dst)
    try: info['livery_concept'] = bpy.context.scene.livery_concept
    except Exception: pass
    info['images'] = imgs
    # UV layer order per livery object, so the game knows which channel holds LIVERY_UV
    lay = {}
    for o in vis:
        names = [l.name for l in o.data.uv_layers]
        if 'LIVERY_UV' in names: lay[o.name] = names.index('LIVERY_UV')
    info['livery_uv_index'] = lay
    info['glb_bytes'] = os.path.getsize(os.path.join(out, 'faumax_tau.glb'))
    info['ok'] = True
except Exception:
    info['error'] = traceback.format_exc()
info['seconds'] = time.time() - info['started']
json.dump(info, open(os.path.join(out, 'export_info.json'), 'w'), indent=1)
