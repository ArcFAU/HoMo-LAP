# Wraps car.glb / car_q.glb as base64 JSON (the artifact host does not serve .glb files)
# and writes them to ..\..\game\car.json and car_q.json.
# Run after slim.mjs / slim_q.mjs:  python pack_json.py
import base64, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, '..', '..', 'game')
for src, dst in [('car.glb', 'car.json'), ('car_q.glb', 'car_q.json')]:
    b = open(os.path.join(HERE, src), 'rb').read()
    json.dump({'format': 'glb-base64', 'source': 'faumax_tau.glb (livery.blend)', 'bytes': len(b),
               'data': base64.b64encode(b).decode()}, open(os.path.join(GAME, dst), 'w'))
    print(dst, os.path.getsize(os.path.join(GAME, dst)), 'bytes')
