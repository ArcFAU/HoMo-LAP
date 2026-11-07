
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
    before = 0
    for o in vis:
        t = sum(len(p.vertices) - 2 for p in o.data.polygons); before += t
        if t > 3000:
            m = o.modifiers.new('HL_dec', 'DECIMATE'); m.ratio = max(0.1, 3000.0 / t); m.use_collapse_triangulate = True
    info['objects'] = len(vis); info['tris_before'] = before
    kw = dict(filepath=os.path.join(out, 'faumax_tau.glb'), export_format='GLB', use_visible=True, export_apply=True, export_yup=True,
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
    uv = bpy.data.images['LIVERY_UV']; base = bpy.path.abspath(uv.filepath)
    for t in (1001, 1002, 1003, 1004):
        src = base.replace('<UDIM>', str(t))
        if os.path.exists(src):
            dst = os.path.join(out, 'LIVERY_UV.%d.png' % t); shutil.copyfile(src, dst); imgs['UV%d' % t] = os.path.getsize(dst)
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
