# Builds ..\game\index.html from template.html + the track data + the team logo.
# Run:  python build_game.py
import base64, os, datetime
HERE = os.path.dirname(os.path.abspath(__file__))
tpl = open(os.path.join(HERE, 'template.html'), encoding='utf-8').read()
track = open(os.path.join(HERE, 'fsg_track.json'), encoding='utf-8').read()
logo = 'data:image/png;base64,' + base64.b64encode(open(os.path.join(HERE, 'logo_small.png'), 'rb').read()).decode()
assert '/*__TRACK__*/null' in tpl and '__LOGO__' in tpl
build = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')   # shown in the menu, to see which version a browser runs
out = tpl.replace('/*__TRACK__*/null', track).replace('__LOGO__', logo).replace('__BUILD__', build)
dst = os.path.join(HERE, '..', 'game', 'index.html')
open(dst, 'w', encoding='utf-8', newline='\n').write(out)
print('wrote', os.path.normpath(dst), len(out), 'bytes')
