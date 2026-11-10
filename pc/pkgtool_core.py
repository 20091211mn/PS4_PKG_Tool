"""PS4 PKG Tool (PC): split / merge / send to a PS4 running Remote Package Installer.

Pure standard library. The GUI (pkgtool_gui.py) is a thin layer over this module.
"""
import http.server
import json
import os
import re
import socket
import socketserver
import struct
import sys
import threading
import time
import urllib.request

BUF = 8 * 1024 * 1024
MAXPART = 4294967295


class PkgError(Exception):
    pass


# ------------------------------------------------------------------ names
_PART_RE = re.compile(r'^(?P<base>.+)\.part(?P<idx>\d+)$', re.I)
_NUM_RE = re.compile(r'^(?P<base>.+)\.(?P<idx>\d{1,4})$')


def part_parse(name):
    """name.partN or name.NNN -> (base, index, style, width) or None."""
    m = _PART_RE.match(name)
    if m:
        return m.group('base'), int(m.group('idx')), 0, 0
    m = _NUM_RE.match(name)
    if m:
        return m.group('base'), int(m.group('idx')), 1, len(m.group('idx'))
    return None


def part_name(base, style, width, idx):
    return '%s.part%d' % (base, idx) if style == 0 else '%s.%0*d' % (base, width, idx)


def alt_name(base):
    stem, ext = os.path.splitext(base)
    return '%s_merged%s' % (stem, ext) if ext else base + '_merged'


def find_group(folder, base, style, width):
    """Find every part of the same split file and check for gaps."""
    first = 1
    if style == 1 and width >= 2 and os.path.exists(os.path.join(folder, part_name(base, style, width, 0))):
        first = 0
    found = contiguous = gap = 0
    total = 0
    highest = first - 1
    for i in range(first, first + 99):
        p = os.path.join(folder, part_name(base, style, width, i))
        if not os.path.isfile(p):
            if not gap and contiguous == i - first:
                gap = i
            continue
        found += 1
        total += os.path.getsize(p)
        highest = i
        if contiguous == i - first:
            contiguous += 1
    missing = gap if highest >= first + contiguous else 0
    if found == 0:
        missing = first
    return {'base': base, 'style': style, 'width': width, 'first': first, 'count': found,
            'last': max(1, highest - first + 1), 'missing': missing, 'total': total}


def group_for_file(path):
    """Given ANY part of a split file, return its group (or None when it is not a part / not a set)."""
    folder, name = os.path.split(os.path.abspath(path))
    pp = part_parse(name)
    if not pp:
        return None
    base, idx, style, width = pp
    g = find_group(folder, base, style, width)
    if style == 1 and g['count'] < 2:
        return None  # "file.2" alone is just a file
    g['folder'] = folder
    g['index'] = idx
    return g


# -------------------------------------------------------------- PKG header
def read_pkg_info(path):
    try:
        with open(path, 'rb') as f:
            h = f.read(0x80)
    except OSError:
        return None
    if len(h) < 0x80 or h[:4] != b'\x7fCNT':
        return None
    cid = h[0x40:0x40 + 36].split(b'\0')[0].decode('ascii', 'replace')
    ctype = struct.unpack('>I', h[0x74:0x78])[0]
    return {'content_id': cid, 'title_id': cid[7:16] if len(cid) >= 16 else '',
            'region': cid[:2], 'content_type': ctype}


def parse_sfo(d):
    """PARAM.SFO -> dict of key -> str/int."""
    if d[:4] != b'\0PSF':
        raise ValueError('not a PARAM.SFO')
    key_tab, data_tab, n = struct.unpack_from('<III', d, 8)
    out = {}
    for i in range(min(n, 256)):
        ko, fmt, ln, _mx, do = struct.unpack_from('<HHIII', d, 0x14 + i * 16)
        end = d.index(b'\0', key_tab + ko)
        key = d[key_tab + ko:end].decode('ascii', 'replace')
        raw = d[data_tab + do:data_tab + do + ln]
        if fmt == 0x0404:
            out[key] = struct.unpack('<I', raw[:4].ljust(4, b'\0'))[0]
        else:
            out[key] = raw.split(b'\0')[0].decode('utf-8', 'replace')
    return out


_CATEGORY_TYPES = {'gd': 'PS4GD', 'gp': 'PS4GP', 'ac': 'PS4AC'}


def read_pkg_meta(path):
    """Header info + PARAM.SFO (CATEGORY/TITLE) + ICON0. Falls back to a header guess if the SFO is unreadable."""
    info = read_pkg_info(path)
    if not info:
        return None
    meta = dict(info, title='', category='', icon=b'', source='header',
                bgft_type=BGFT_TYPES.get(info['content_type'], 'PS4GD'))
    try:
        size = os.path.getsize(path)
        with open(path, 'rb') as f:
            hdr = f.read(0x100)
            count, table = struct.unpack_from('>I', hdr, 0x10)[0], struct.unpack_from('>I', hdr, 0x18)[0]
            if not 0 < count <= 4096 or table >= size:
                raise ValueError('bad entry table')
            f.seek(table)
            raw = f.read(count * 32)
            sfo = icon = None
            for i in range(len(raw) // 32):
                eid, _n, _f1, _f2, off, sz = struct.unpack_from('>IIIIII', raw, i * 32)
                if eid == 0x1000 and 0 < sz <= 1 << 20 and off + sz <= size:
                    sfo = (off, sz)
                elif eid == 0x1200 and 0 < sz <= 2 << 20 and off + sz <= size:
                    icon = (off, sz)
            if not sfo:
                raise ValueError('no PARAM.SFO')
            f.seek(sfo[0])
            params = parse_sfo(f.read(sfo[1]))
            cat = str(params.get('CATEGORY', '')).strip().lower()
            meta['category'] = cat
            meta['title'] = str(params.get('TITLE', '')).strip()
            kind = _CATEGORY_TYPES.get(cat) or ('PS4GD' if cat.startswith('gd') else None)
            if kind:
                meta['bgft_type'] = kind
                meta['source'] = 'PARAM.SFO'
            if icon:
                f.seek(icon[0])
                meta['icon'] = f.read(icon[1])
    except (ValueError, struct.error, OSError, IndexError):
        pass
    return meta


# ------------------------------------------------------------ split / merge
def _copy(src, dst, length, tick):
    left = length
    while left > 0:
        chunk = src.read(min(BUF, left))
        if not chunk:
            raise PkgError('unexpected end of file')
        dst.write(chunk)
        left -= len(chunk)
        tick(len(chunk))


def min_parts(size):
    return max(2, -(-size // 4000000000))


def split_file(path, n, progress=None):
    """Split `path` into n pieces next to it (name.part1 ...). Returns the list of part paths."""
    progress = progress or (lambda done, total: None)
    if not os.path.isfile(path):
        raise PkgError('input file not found')
    size = os.path.getsize(path)
    if n < 2 or n > size:
        raise PkgError('bad parts count')
    ps = -(-size // n)
    if ps >= MAXPART:
        raise PkgError('a part would be over 4GB - use more parts')
    first = '%s.part1' % path
    if os.path.exists(first):
        raise PkgError('parts already exist - delete them first')
    done = [0]

    def tick(k):
        done[0] += k
        progress(done[0], size)

    out_paths, written = [], 0
    with open(path, 'rb') as src:
        for i in range(1, n + 1):
            length = min(ps, size - written)
            if length <= 0:
                break
            p = '%s.part%d' % (path, i)
            with open(p, 'wb') as dst:
                _copy(src, dst, length, tick)
            if os.path.getsize(p) != length:
                raise PkgError('part size mismatch')
            out_paths.append(p)
            written += length
    if written != size:
        raise PkgError('parts total does not match the original')
    return out_paths


def merge_group(group, progress=None):
    """Merge every part of `group` into one file. Never overwrites: picks name_merged.ext if taken."""
    progress = progress or (lambda done, total: None)
    if group['missing']:
        raise PkgError('missing part number %d' % group['missing'])
    folder, base, total = group['folder'], group['base'], group['total']
    out = os.path.join(folder, base)
    if os.path.exists(out):
        if os.path.getsize(out) == total:
            raise PkgError('already merged - the output file exists')
        out = os.path.join(folder, alt_name(base))
        if os.path.exists(out):
            raise PkgError('output file exists - delete or rename it')
    done = [0]

    def tick(k):
        done[0] += k
        progress(done[0], total)

    n = 0
    try:
        with open(out, 'wb') as dst:
            for i in range(group['first'], group['first'] + 99):
                p = os.path.join(folder, part_name(base, group['style'], group['width'], i))
                if not os.path.isfile(p):
                    continue
                n += 1
                with open(p, 'rb') as src:
                    _copy(src, dst, os.path.getsize(p), tick)
        if os.path.getsize(out) != total:
            raise PkgError('final size mismatch')
    except Exception:
        if os.path.exists(out):
            os.remove(out)  # never leave a half-written file behind
        raise
    return out


# ------------------------------------------------------- local file server
class _Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *a):
        pass

    def _range(self, size):
        rg = self.headers.get('Range')
        if rg:
            m = re.match(r'bytes=(\d*)-(\d*)', rg)
            if m:
                a = int(m.group(1)) if m.group(1) else 0
                b = int(m.group(2)) if m.group(2) else size - 1
                return a, min(b, size - 1), True
        return 0, size - 1, False

    def _manifest(self, head):
        if not head:
            self.server.manifest_hits += 1
        body = self.server.manifest
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def _serve(self, head):
        srv = self.server
        if getattr(srv, 'manifest', None) is not None and self.path.startswith('/json/'):
            return self._manifest(head)
        size = srv.file_size
        a, b, partial = self._range(size)
        if a > b or a >= size:
            self.send_response(416)
            self.send_header('Content-Range', 'bytes */%d' % size)
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        self.send_response(206 if partial else 200)
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Disposition', 'attachment; filename="%s"' % os.path.basename(srv.file_path))
        if partial:
            self.send_header('Content-Range', 'bytes %d-%d/%d' % (a, b, size))
        self.send_header('Content-Length', str(b - a + 1))
        self.end_headers()
        if head:
            return
        srv.pkg_hits += 1
        if not srv.first_pkg_time:
            srv.first_pkg_time = time.time()
        try:
            with open(srv.file_path, 'rb') as f:
                f.seek(a)
                left = b - a + 1
                while left > 0:
                    chunk = f.read(min(1024 * 1024, left))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    left -= len(chunk)
                    srv.sent += len(chunk)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass

    def do_HEAD(self):
        self._serve(True)

    def do_GET(self):
        self._serve(False)


class _Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class FileServer:
    def __init__(self, path, port=0):
        self.srv = _Server(('0.0.0.0', port), _Handler)
        self.srv.file_path = path
        self.srv.file_size = os.path.getsize(path)
        self.srv.sent = 0
        self.srv.manifest_hits = 0
        self.srv.pkg_hits = 0
        self.srv.first_pkg_time = 0.0
        self.thread = threading.Thread(target=self.srv.serve_forever, daemon=True)

    @property
    def port(self):
        return self.srv.server_address[1]

    @property
    def sent(self):
        return self.srv.sent

    @property
    def size(self):
        return self.srv.file_size

    @property
    def manifest_hits(self):
        return self.srv.manifest_hits

    @property
    def pkg_hits(self):
        return self.srv.pkg_hits

    def start(self):
        self.thread.start()
        return self

    def stop(self):
        self.srv.shutdown()
        self.srv.server_close()

    def url(self, ip):
        return 'http://%s:%d/%s' % (ip, self.port, urllib.request.pathname2url(os.path.basename(self.srv.file_path)))

    def enable_direct(self, ip):
        """Serve the JSON manifest that the DirectPackageInstaller payload downloads first."""
        pkg_url = 'http://%s:%d/pkg/app.pkg' % (ip, self.port)
        size = self.srv.file_size
        self.srv.manifest = json.dumps({
            'originalFileSize': size, 'packageDigest': '0' * 64, 'numberOfSplitFiles': 1,
            'pieces': [{'url': pkg_url, 'fileOffset': 0, 'fileSize': size, 'hashValue': '0' * 40}]}).encode()
        return 'http://%s:%d/json/0.json' % (ip, self.port)


def local_ip_for(target_ip):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((target_ip, 12800))
        return s.getsockname()[0]
    finally:
        s.close()


def rpi_install(ps4_ip, url, port=12800, timeout=15):
    """Ask Remote Package Installer on the PS4 to download and install `url`."""
    body = json.dumps({'type': 'direct', 'packages': [url]}).encode()
    req = urllib.request.Request('http://%s:%d/api/install' % (ps4_ip, port), data=body,
                                 headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            text = r.read().decode('utf-8', 'replace')
    except OSError as e:
        raise PkgError('cannot reach RPI on %s:%d (%s)' % (ps4_ip, port, e))
    try:
        return json.loads(text)
    except ValueError:
        return {'raw': text}


# ------------------------------------------- direct install (no RPI)
# Same flow as the DirectPackageInstaller GoldHEN payload method:
#  1. we listen on a port, 2. send payload.bin (with our IP+port written over a 6-byte marker) to the
#  console's BinLoader (9090), 3. the payload connects back, 4. we send the package description,
#  5. the console downloads the JSON manifest and then the PKG from our HTTP server.
MARKER = b'\xb4' * 6
BGFT_TYPES = {0x1A: 'PS4GD', 0x1B: 'PS4AC', 0x1E: 'PS4GP'}


def patch_payload(data, ip, port):
    off = data.find(MARKER)
    if off < 0:
        raise PkgError('payload.bin does not contain the address marker (wrong file?)')
    try:
        ipb = bytes(int(x) for x in ip.split('.'))
    except ValueError:
        ipb = b''
    if len(ipb) != 4:
        raise PkgError('bad local IP address: %r' % ip)
    return data[:off] + ipb + struct.pack('>H', port) + data[off + 6:]


def build_info(url, name, content_id, ctype, size, icon=b''):
    def s(text):
        b = text.encode('utf-8')
        return struct.pack('<i', len(b)) + b
    return struct.pack('<I', 1) + s(url) + s(name) + s(content_id) + s(ctype) + struct.pack('<q', size) + struct.pack('<i', len(icon)) + icon


def _connect_ps4(ip, ports, timeout=3.0, retry_delay=3):
    last = None
    for rnd in range(2):
        for p in ports:
            try:
                return socket.create_connection((ip, p), timeout=timeout), p
            except OSError as e:
                last = e
        if rnd == 0:
            time.sleep(retry_delay)
    raise PkgError('cannot connect to the PS4 on ports %s (%s). Is GoldHEN running with the payload server?' %
                   ('/'.join(str(p) for p in ports), last))


def direct_install(ps4_ip, pkg_path, payload, ctype=None, ports=(9090, 9021, 9020), log=None, wait=25, retry_delay=3):
    """Returns the running FileServer; keep it alive until the console finishes downloading."""
    log = log or (lambda m: None)
    info = read_pkg_meta(pkg_path)
    if not info:
        raise PkgError('not a valid PS4 PKG (header not found)')
    pc_ip = local_ip_for(ps4_ip)
    server = FileServer(pkg_path).start()
    lst = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        lst.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        lst.bind(('0.0.0.0', 0))
        lst.listen(4)
        manifest_url = server.enable_direct(pc_ip)
        log('listening for the payload on %s:%d, files on port %d' % (pc_ip, lst.getsockname()[1], server.port))
        data = patch_payload(payload, pc_ip, lst.getsockname()[1])
        s, port = _connect_ps4(ps4_ip, ports, retry_delay=retry_delay)
        log('connected to PS4 port %d, sending payload (%d bytes)' % (port, len(data)))
        with s:
            s.sendall(data)
        lst.settimeout(wait)
        try:
            conn, addr = lst.accept()
        except OSError:
            raise PkgError('the payload did not connect back within %d s - restart GoldHEN and try again' % wait)
        log('payload connected from %s' % addr[0])
        with conn:
            name = info['title'] or os.path.splitext(os.path.basename(pkg_path))[0]
            final_type = ctype or info['bgft_type']
            log('package: %s | type %s (%s%s) | icon %d bytes' % (
                name, final_type, 'chosen by you' if ctype else info['source'],
                ", category '%s'" % info['category'] if info['category'] else '', len(info['icon'])))
            conn.sendall(build_info(manifest_url, name, info['content_id'], final_type,
                                    os.path.getsize(pkg_path), info['icon']))
        log('package description sent - the PS4 should start downloading')
        return server
    except Exception:
        server.stop()
        raise
    finally:
        lst.close()


# ------------------------------------------------------------ Arabic text
_AR = {}
for _b, _iso, _k in [
    (0x621, 0xFE80, 0), (0x622, 0xFE81, 1), (0x623, 0xFE83, 1), (0x624, 0xFE85, 1), (0x625, 0xFE87, 1),
    (0x626, 0xFE89, 2), (0x627, 0xFE8D, 1), (0x628, 0xFE8F, 2), (0x629, 0xFE93, 1), (0x62A, 0xFE95, 2),
    (0x62B, 0xFE99, 2), (0x62C, 0xFE9D, 2), (0x62D, 0xFEA1, 2), (0x62E, 0xFEA5, 2), (0x62F, 0xFEA9, 1),
    (0x630, 0xFEAB, 1), (0x631, 0xFEAD, 1), (0x632, 0xFEAF, 1), (0x633, 0xFEB1, 2), (0x634, 0xFEB5, 2),
    (0x635, 0xFEB9, 2), (0x636, 0xFEBD, 2), (0x637, 0xFEC1, 2), (0x638, 0xFEC5, 2), (0x639, 0xFEC9, 2),
    (0x63A, 0xFECD, 2), (0x641, 0xFED1, 2), (0x642, 0xFED5, 2), (0x643, 0xFED9, 2), (0x644, 0xFEDD, 2),
    (0x645, 0xFEE1, 2), (0x646, 0xFEE5, 2), (0x647, 0xFEE9, 2), (0x648, 0xFEED, 1), (0x649, 0xFEEF, 1),
    (0x64A, 0xFEF1, 2)]:
    _AR[_b] = (_iso, _k)
_LAMALEF = {0x622: 0xFEF5, 0x623: 0xFEF7, 0x625: 0xFEF9, 0x627: 0xFEFB}


def _is_ar(c):
    return 0x621 <= c <= 0x64A or c in (0x640, 0x60C, 0x61F, 0x61B) or 0x64B <= c <= 0x652


def _shape_run(cps):
    cps = [c for c in cps if not 0x64B <= c <= 0x652]
    units, i = [], 0  # (code, isoform, kind) kind: -1 other, 0 none, 1 right, 2 dual, 3 tatweel
    while i < len(cps):
        c = cps[i]
        if c == 0x644 and i + 1 < len(cps) and cps[i + 1] in _LAMALEF:
            units.append((_LAMALEF[cps[i + 1]], _LAMALEF[cps[i + 1]], 1))
            i += 2
            continue
        if c in _AR:
            units.append((c, _AR[c][0], _AR[c][1]))
        elif c == 0x640:
            units.append((c, c, 3))
        else:
            units.append((c, c, -1))
        i += 1
    out = []
    for i, (c, iso, k) in enumerate(units):
        if k in (-1, 0, 3):
            out.append(c)
            continue
        jp = i > 0 and units[i - 1][2] in (2, 3)
        jn = i + 1 < len(units) and units[i + 1][2] in (1, 2, 3)
        if k == 1:
            out.append(iso + 1 if jp else iso)
        else:
            out.append(iso + 3 if jp and jn else iso + 1 if jp else iso + 2 if jn else iso)
    return out


def _neutral(c):
    if c < 0x80:
        return not (chr(c).isalnum())
    return (0xA0 <= c <= 0xBF) or (0x2000 <= c <= 0x206F) or (0x2190 <= c <= 0x21FF) or \
           (0x25A0 <= c <= 0x25FF) or (0x2700 <= c <= 0x27BF)


def ar(text):
    """Return `text` in visual order with joined Arabic letters, for widgets that cannot shape Arabic."""
    cp = [ord(ch) for ch in text]
    if not any(_is_ar(c) for c in cp):
        return text
    n = len(cp)
    t = []
    for c in cp:
        t.append('A' if _is_ar(c) else 'D' if 0x30 <= c <= 0x39 else 'N' if _neutral(c) else 'L')
    for i in range(1, n - 1):
        if t[i] == 'N' and t[i - 1] == 'D' and t[i + 1] == 'D' and chr(cp[i]) in '.,:/+-':
            t[i] = 'D'
    infl, last = ['R'] * n, 'S'
    for i in range(n):
        if t[i] == 'A':
            last = 'A'
        elif t[i] == 'L':
            last = 'L'
        elif t[i] == 'D':
            infl[i] = 'L' if last == 'L' else 'R'
    cls = ['R' if t[i] == 'A' else '?' if t[i] == 'N' else 'L' for i in range(n)]
    i = 0
    while i < n:
        if t[i] != 'N':
            i += 1
            continue
        j = i
        while j < n and t[j] == 'N':
            j += 1
        lft = 'R' if i == 0 else ('R' if t[i - 1] == 'A' else 'L' if t[i - 1] == 'L' else infl[i - 1])
        rgt = 'R' if j >= n else ('R' if t[j] == 'A' else 'L' if t[j] == 'L' else infl[j])
        for k in range(i, j):
            cls[k] = 'L' if lft == 'L' and rgt == 'L' else 'R'
        i = j
    runs, i = [], 0
    while i < n:
        j = i
        while j < n and cls[j] == cls[i]:
            j += 1
        runs.append((i, j, cls[i]))
        i = j
    out = []
    for a, b, c in reversed(runs):
        if c == 'R':
            out.extend(reversed(_shape_run(cp[a:b])))
        else:
            out.extend(cp[a:b])
    return ''.join(chr(c) for c in out)


def fmt_size(b):
    return '%.2f GB' % (b / 1073741824) if b >= 1073741824 else '%.1f MB' % (b / 1048576)


if __name__ == '__main__':  # tiny CLI: split FILE N | merge ANY_PART
    try:
        if len(sys.argv) >= 3 and sys.argv[1] == 'split':
            print('\n'.join(split_file(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else min_parts(os.path.getsize(sys.argv[2])))))
        elif len(sys.argv) >= 3 and sys.argv[1] == 'merge':
            g = group_for_file(sys.argv[2])
            if not g:
                raise PkgError('not a part of a split file')
            print(merge_group(g))
        elif len(sys.argv) >= 3 and sys.argv[1] == 'info':
            m = read_pkg_meta(sys.argv[2])
            if not m:
                raise PkgError('not a PS4 PKG')
            m['icon'] = '%d bytes' % len(m['icon'])
            print(json.dumps(m, indent=2, ensure_ascii=False))
        elif len(sys.argv) >= 5 and sys.argv[1] == 'direct':
            with open(sys.argv[4], 'rb') as f:
                srv = direct_install(sys.argv[2], sys.argv[3], f.read(), log=print)
            print('serving - press Ctrl+C when the PS4 has finished')
            while True:
                time.sleep(1)
        else:
            print('usage: pkgtool_core.py split FILE [N] | merge ANY_PART | info FILE.pkg | direct PS4_IP FILE.pkg payload.bin')
    except PkgError as e:
        print('ERROR:', e)
        sys.exit(1)
