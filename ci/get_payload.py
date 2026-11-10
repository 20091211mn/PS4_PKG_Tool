"""Puts the GoldHEN payload used by the direct (no RPI) method at pc/payload.bin.

Uses assets/payload.bin from the repository when it looks right, otherwise takes it from the
DirectPackageInstaller repository (GPL-3.0). A valid payload is 4KB-200KB and has exactly one
6-byte 0xB4 marker where the PC's address is written.
"""
import os
import shutil
import subprocess
import sys

MARK = b'\xb4' * 6
OUT = os.path.join('pc', 'payload.bin')


def valid(data):
    return 4000 < len(data) < 200000 and data.count(MARK) == 1


def read(p):
    try:
        with open(p, 'rb') as f:
            return f.read()
    except OSError:
        return b''


def main():
    c = os.path.join('assets', 'payload.bin')
    if os.path.isfile(c) and valid(read(c)):
        shutil.copy(c, OUT)
        print('using', c, os.path.getsize(OUT), 'bytes')
        return 0
    if not os.path.isdir('dpi'):
        subprocess.check_call(['git', 'clone', '--depth', '1', 'https://github.com/marcussacana/DirectPackageInstaller', 'dpi'])
    for root, dirs, files in os.walk('dpi'):
        dirs[:] = [d for d in dirs if d != '.git']
        for f in sorted(files):
            p = os.path.join(root, f)
            if 'payload' not in p.lower() or 'experimental' in p.lower() or os.path.getsize(p) > 200000:
                continue
            if valid(read(p)):
                shutil.copy(p, OUT)
                print('extracted', p, os.path.getsize(OUT), 'bytes')
                return 0
    print('payload.bin not found - the direct method will be unavailable in this build')
    return 1


if __name__ == '__main__':
    sys.exit(main())
