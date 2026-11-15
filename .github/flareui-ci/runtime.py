import io
import json
import pathlib
import stat
import subprocess
import zipfile

root = pathlib.Path('.')
manifest = json.loads(pathlib.Path('.github/flareui-ci/runtime-manifest.json').read_text())
tracked = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
roots = {'Modules', 'Settings', 'Locales', 'Libs', 'Media', 'LICENSES'}
potential = {p for p in tracked if p and (p.split('/')[0] in roots or ('/' not in p and (p.lower().endswith(('.lua', '.xml', '.toc')) or p == 'LICENSE.txt')))}
if len(manifest) != len(set(manifest)) or set(manifest) != potential:
    raise SystemExit('Runtime manifest mismatch: ' + str(sorted(set(manifest) ^ potential)))
stream = io.BytesIO()
with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in sorted(manifest):
        p = root / name
        if p.is_symlink() or not p.is_file():
            raise SystemExit('Unsafe runtime file: ' + name)
        z.writestr('FlareUI/' + name, p.read_bytes())
with zipfile.ZipFile(stream) as z:
    names = z.namelist()
    if len(names) != len(set(names)) or set(names) != {'FlareUI/' + p for p in manifest}:
        raise SystemExit('ZIP manifest mismatch')
    for info in z.infolist():
        p = pathlib.PurePosixPath(info.filename)
        if p.is_absolute() or '..' in p.parts or not info.filename.startswith('FlareUI/') or stat.S_ISLNK(info.external_attr >> 16):
            raise SystemExit('Unsafe ZIP entry: ' + info.filename)
        if z.read(info) != (root / info.filename[8:]).read_bytes():
            raise SystemExit('ZIP content mismatch: ' + info.filename)
print('Runtime manifest and in-memory ZIP audit passed; no artifact published')
