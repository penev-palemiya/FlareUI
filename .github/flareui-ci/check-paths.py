#!/usr/bin/env python3
import pathlib
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1]).resolve()
seen = set()

def visit(path):
    path = path.resolve()
    if not path.is_relative_to(root) or not path.is_file():
        raise ValueError('Missing or unsafe path: ' + str(path))
    if path in seen:
        return
    seen.add(path)
    if path.suffix.lower() == '.xml':
        for element in ET.parse(path).iter():
            if element.tag.rsplit('}', 1)[-1] in ('Include', 'Script') and 'file' in element.attrib:
                visit(path.parent / element.attrib['file'].replace('\\', '/'))

try:
    toc = root / 'FlareUI.toc'
    for line in toc.read_text(encoding='utf-8-sig').splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            visit(root / line.replace('\\', '/'))
    print(f'PASS: {len(seen)} TOC/XML dependencies exist')
except (OSError, ValueError, ET.ParseError) as exc:
    print('FAIL: ' + str(exc), file=sys.stderr)
    sys.exit(1)
