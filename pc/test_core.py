import hashlib
import socket
import http.server
import json
import os
import struct
import tempfile
import threading
import unittest
import urllib.request

import pkgtool_core as core


def _write(path, data):
    with open(path, 'wb') as f:
        f.write(data)


def _sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for c in iter(lambda: f.read(1 << 20), b''):
            h.update(c)
    return h.hexdigest()


def _pkg_bytes(n):
    h = bytearray(0x80)
    h[0:4] = b'\x7fCNT'
    h[0x40:0x40 + 36] = b'UP0001-CUSA00001_00-GAME000000000000'
    h[0x74:0x78] = struct.pack('>I', 0x1A)
    return bytes(h) + os.urandom(n - 0x80)


def _sfo(params):
    keys, data, idx = b'', b'', b''
    for k, v in sorted(params.items()):
        vb = v.encode() + b'\0'
        idx += struct.pack('<HHIII', len(keys), 0x0204, len(vb), (len(vb) + 3) & ~3, len(data))
        keys += k.encode() + b'\0'
        data += vb + b'\0' * (((len(vb) + 3) & ~3) - len(vb))
    kt = 0x14 + len(idx)
    dt = kt + len(keys) + (-(kt + len(keys)) % 4)
    return (b'\0PSF' + struct.pack('<III', 0x101, kt, dt) + struct.pack('<I', len(params)) + idx
            + keys + b'\0' * (dt - kt - len(keys)) + data)


def _pkg_with_sfo(category, title, icon=b'', ctype=0x1A, total=300000):
    sfo = _sfo({'CATEGORY': category, 'TITLE': title, 'TITLE_ID': 'CUSA00001'})
    h = bytearray(0x100)
    h[0:4] = b'\x7fCNT'
    n = 3 if icon else 2
    struct.pack_into('>I', h, 0x10, n)
    struct.pack_into('>I', h, 0x18, 0x200)
    h[0x40:0x40 + 36] = b'UP0001-CUSA00001_00-GAME000000000000'
    struct.pack_into('>I', h, 0x74, ctype)
    body = bytearray(total)
    body[0:0x100] = h
    ents = [(0x0100, 0x600, 8), (0x1000, 0x800, len(sfo))] + ([(0x1200, 0x1000, len(icon))] if icon else [])
    for i, (eid, off, sz) in enumerate(ents):
        struct.pack_into('>IIIIII', body, 0x200 + i * 32, eid, 0, 0, 0, off, sz)
    body[0x800:0x800 + len(sfo)] = sfo
    if icon:
        body[0x1000:0x1000 + len(icon)] = icon
    body[0x1000 + len(icon):] = os.urandom(total - 0x1000 - len(icon))
    return bytes(body)


class PkgMeta(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def _meta(self, **kw):
        p = os.path.join(self.d, 'a.pkg')
        _write(p, _pkg_with_sfo(**kw))
        return core.read_pkg_meta(p)

    def test_category_decides_the_type_not_the_header(self):
        png = b'\x89PNG\r\n\x1a\n' + os.urandom(500)
        for cat, want in (('gd', 'PS4GD'), ('gp', 'PS4GP'), ('ac', 'PS4AC')):
            m = self._meta(category=cat, title='Some Title', icon=png, ctype=0x1A)   # header says GD every time
            self.assertEqual((m['bgft_type'], m['source'], m['title'], m['category']), (want, 'PARAM.SFO', 'Some Title', cat))
            self.assertEqual(m['icon'], png)

    def test_arabic_title_and_unknown_category_falls_back_to_header(self):
        m = self._meta(category='gd', title='لعبة رائعة')
        self.assertEqual(m['title'], 'لعبة رائعة')
        m = self._meta(category='zz', title='X', ctype=0x1B)
        self.assertEqual((m['bgft_type'], m['source']), ('PS4AC', 'header'))

    def test_broken_table_falls_back_without_crashing(self):
        p = os.path.join(self.d, 'b.pkg')
        _write(p, _pkg_bytes(5000))                      # header only, no entry table
        m = core.read_pkg_meta(p)
        self.assertEqual((m['source'], m['bgft_type'], m['title']), ('header', 'PS4GD', ''))


class SplitMerge(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def test_roundtrip_from_middle_part(self):
        p = os.path.join(self.d, 'game.pkg')
        _write(p, _pkg_bytes(5 * 1024 * 1024))
        want = _sha(p)
        parts = core.split_file(p, 3)
        self.assertEqual(len(parts), 3)
        os.remove(p)
        g = core.group_for_file(parts[1])           # press the MIDDLE part
        self.assertEqual((g['count'], g['missing'], g['last']), (3, 0, 3))
        out = core.merge_group(g)
        self.assertEqual(os.path.basename(out), 'game.pkg')
        self.assertEqual(_sha(out), want)

    def test_numeric_style(self):
        data = os.urandom(3 * 1024 * 1024)
        for i in range(3):
            _write(os.path.join(self.d, 'movie.mkv.%03d' % (i + 1)), data[i * 1048576:(i + 1) * 1048576])
        g = core.group_for_file(os.path.join(self.d, 'movie.mkv.002'))
        self.assertEqual(g['style'], 1)
        out = core.merge_group(g)
        with open(out, 'rb') as f:
            self.assertEqual(f.read(), data)

    def test_lone_number_is_not_a_part(self):
        _write(os.path.join(self.d, 'v1.2'), b'x')
        self.assertIsNone(core.group_for_file(os.path.join(self.d, 'v1.2')))

    def test_missing_part_refused_and_nothing_written(self):
        for i in (1, 2, 4):
            _write(os.path.join(self.d, 'gap.bin.part%d' % i), os.urandom(1000))
        g = core.group_for_file(os.path.join(self.d, 'gap.bin.part2'))
        self.assertEqual(g['missing'], 3)
        with self.assertRaises(core.PkgError):
            core.merge_group(g)
        self.assertFalse(os.path.exists(os.path.join(self.d, 'gap.bin')))

    def test_name_taken_uses_merged_suffix_and_same_size_is_reported(self):
        a = os.urandom(2000)
        _write(os.path.join(self.d, 'b.pkg.part1'), a[:1000])
        _write(os.path.join(self.d, 'b.pkg.part2'), a[1000:])
        _write(os.path.join(self.d, 'b.pkg'), b'different')
        out = core.merge_group(core.group_for_file(os.path.join(self.d, 'b.pkg.part1')))
        self.assertEqual(os.path.basename(out), 'b_merged.pkg')
        os.remove(out)
        _write(os.path.join(self.d, 'b.pkg'), a)     # already merged, same size
        with self.assertRaises(core.PkgError):
            core.merge_group(core.group_for_file(os.path.join(self.d, 'b.pkg.part1')))

    def test_split_refuses_existing_parts_and_bad_counts(self):
        p = os.path.join(self.d, 'x.bin')
        _write(p, os.urandom(5000))
        core.split_file(p, 2)
        with self.assertRaises(core.PkgError):
            core.split_file(p, 2)
        with self.assertRaises(core.PkgError):
            core.split_file(os.path.join(self.d, 'nope'), 2)
        q = os.path.join(self.d, 'y.bin')
        _write(q, b'abc')
        with self.assertRaises(core.PkgError):
            core.split_file(q, 1)

    def test_pkg_header(self):
        p = os.path.join(self.d, 'a.pkg')
        _write(p, _pkg_bytes(4096))
        i = core.read_pkg_info(p)
        self.assertEqual((i['title_id'], i['region'], i['content_type']), ('CUSA00001', 'UP', 0x1A))
        _write(os.path.join(self.d, 'b.txt'), b'hello')
        self.assertIsNone(core.read_pkg_info(os.path.join(self.d, 'b.txt')))


class Network(unittest.TestCase):
    def test_range_server(self):
        d = tempfile.mkdtemp()
        p = os.path.join(d, 'f.pkg')
        data = os.urandom(300000)
        _write(p, data)
        srv = core.FileServer(p).start()
        try:
            url = srv.url('127.0.0.1')
            with urllib.request.urlopen(url) as r:
                self.assertEqual(r.read(), data)
                self.assertEqual(r.headers['Accept-Ranges'], 'bytes')
            req = urllib.request.Request(url, headers={'Range': 'bytes=1000-1999'})
            with urllib.request.urlopen(req) as r:
                self.assertEqual(r.status, 206)
                self.assertEqual(r.read(), data[1000:2000])
                self.assertEqual(r.headers['Content-Range'], 'bytes 1000-1999/300000')
            req = urllib.request.Request(url, method='HEAD')
            with urllib.request.urlopen(req) as r:
                self.assertEqual(int(r.headers['Content-Length']), 300000)
            self.assertGreaterEqual(srv.sent, 300000)
        finally:
            srv.stop()

    def test_rpi_request_shape(self):
        got = {}

        class H(http.server.BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def do_POST(self):
                got['path'] = self.path
                got['body'] = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                got['ctype'] = self.headers['Content-Type']
                out = json.dumps({'status': 'success', 'task_id': 7}).encode()
                self.send_response(200)
                self.send_header('Content-Length', str(len(out)))
                self.end_headers()
                self.wfile.write(out)

        s = http.server.HTTPServer(('127.0.0.1', 0), H)
        threading.Thread(target=s.serve_forever, daemon=True).start()
        try:
            r = core.rpi_install('127.0.0.1', 'http://pc:1/a.pkg', port=s.server_address[1])
        finally:
            s.shutdown()
            s.server_close()
        self.assertEqual(r['status'], 'success')
        self.assertEqual(got['path'], '/api/install')
        self.assertEqual(got['body'], {'type': 'direct', 'packages': ['http://pc:1/a.pkg']})
        with self.assertRaises(core.PkgError):
            core.rpi_install('127.0.0.1', 'x', port=1, timeout=1)


class MockPS4:
    """Plays the console side of the DirectPackageInstaller flow."""

    def __init__(self, connect_back=True):
        self.connect_back = connect_back
        self.lst = socket.socket()
        self.lst.bind(('127.0.0.1', 0))
        self.lst.listen(1)
        self.port = self.lst.getsockname()[1]
        self.result = {}
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    @staticmethod
    def _read_all(conn):
        out = b''
        while True:
            c = conn.recv(65536)
            if not c:
                return out
            out += c

    def run(self):
        try:
            conn, _ = self.lst.accept()
            data = self._read_all(conn)
            conn.close()
            self.result['payload'] = data
            if not self.connect_back:
                return
            ip = '.'.join(str(b) for b in data[16384:16388])
            port = struct.unpack('>H', data[16388:16390])[0]
            back = socket.create_connection((ip, port), timeout=5)
            info = self._read_all(back)
            back.close()
            self.result['info'] = info
            pos = [0]

            def u32():
                v = struct.unpack_from('<I', info, pos[0])[0]; pos[0] += 4; return v

            def string():
                n = struct.unpack_from('<i', info, pos[0])[0]; pos[0] += 4
                v = info[pos[0]:pos[0] + n].decode(); pos[0] += n; return v
            self.result['version'] = u32()
            url = string(); name = string(); cid = string(); typ = string()
            size = struct.unpack_from('<q', info, pos[0])[0]; pos[0] += 8
            icon = struct.unpack_from('<i', info, pos[0])[0]
            pos[0] += 4
            self.result.update(url=url, name=name, cid=cid, type=typ, size=size, icon=icon,
                               icon_bytes=info[pos[0]:pos[0] + icon], consumed=pos[0] + icon, total=len(info))
            man = json.loads(urllib.request.urlopen(url, timeout=5).read())
            piece = man['pieces'][0]
            half = piece['fileSize'] // 2
            buf = b''
            for a, b in ((0, half - 1), (half, piece['fileSize'] - 1)):
                req = urllib.request.Request(piece['url'], headers={'Range': 'bytes=%d-%d' % (a, b)})
                buf += urllib.request.urlopen(req, timeout=5).read()
            self.result['manifest'] = man
            self.result['downloaded'] = buf
        except Exception as e:  # reported by the test
            self.result['error'] = repr(e)

    def close(self):
        self.lst.close()


def _fake_payload():
    return bytes(range(256)) * 64 + b'\xb4' * 6 + b'\x00\x01\x02\x03\x04\x05'   # 16396 bytes, marker at 16384


class DirectInstall(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.pkg = os.path.join(self.d, 'My Game.pkg')
        _write(self.pkg, _pkg_bytes(700000))

    def test_full_flow(self):
        ps4 = MockPS4()
        srv = core.direct_install('127.0.0.1', self.pkg, _fake_payload(), ports=(ps4.port,), wait=5)
        try:
            ps4.thread.join(15)
        finally:
            srv.stop()
            ps4.close()
        r = ps4.result
        self.assertNotIn('error', r, r.get('error'))
        self.assertEqual(len(r['payload']), 16396)
        self.assertEqual(r['payload'][:16384], bytes(range(256)) * 64)         # untouched code
        self.assertEqual(r['payload'][16390:], b'\x00\x01\x02\x03\x04\x05')   # untouched tail
        self.assertEqual(r['version'], 1)
        self.assertEqual((r['name'], r['cid'], r['type'], r['icon']), ('My Game', 'UP0001-CUSA00001_00-GAME000000000000', 'PS4GD', 0))
        self.assertEqual(r['size'], 700000)
        self.assertTrue(r['url'].endswith('/json/0.json'))
        self.assertEqual(r['manifest']['pieces'][0]['fileSize'], 700000)
        with open(self.pkg, 'rb') as f:
            self.assertEqual(r['downloaded'], f.read())

    def test_description_uses_sfo_title_type_and_icon(self):
        png = b'\x89PNG\r\n\x1a\n' + os.urandom(2000)
        pkg = os.path.join(self.d, 'whatever-file-name.pkg')
        _write(pkg, _pkg_with_sfo('gp', 'Real Game Title', png))
        ps4 = MockPS4()
        srv = core.direct_install('127.0.0.1', pkg, _fake_payload(), ports=(ps4.port,), wait=5)
        try:
            ps4.thread.join(15)
            hits = (srv.manifest_hits, srv.pkg_hits)
        finally:
            srv.stop()
            ps4.close()
        r = ps4.result
        self.assertNotIn('error', r, r.get('error'))
        self.assertEqual((r['name'], r['type'], r['icon_bytes']), ('Real Game Title', 'PS4GP', png))
        self.assertEqual(r['consumed'], r['total'])                       # no stray bytes left over
        self.assertGreaterEqual(hits[0], 1)                               # the console fetched the manifest ...
        self.assertGreaterEqual(hits[1], 1)                               # ... and then the package

    def test_type_override(self):
        ps4 = MockPS4()
        srv = core.direct_install('127.0.0.1', self.pkg, _fake_payload(), ctype='PS4AC', ports=(ps4.port,), wait=5)
        try:
            ps4.thread.join(15)
        finally:
            srv.stop()
            ps4.close()
        self.assertEqual(ps4.result['type'], 'PS4AC')

    def test_ps4_unreachable(self):
        with self.assertRaises(core.PkgError):
            core.direct_install('127.0.0.1', self.pkg, _fake_payload(), ports=(1,), retry_delay=0)

    def test_payload_never_connects_back(self):
        ps4 = MockPS4(connect_back=False)
        try:
            with self.assertRaises(core.PkgError) as cm:
                core.direct_install('127.0.0.1', self.pkg, _fake_payload(), ports=(ps4.port,), wait=1)
            self.assertIn('did not connect back', str(cm.exception))
        finally:
            ps4.close()

    def test_bad_inputs(self):
        with self.assertRaises(core.PkgError):
            core.patch_payload(b'no marker here', '10.0.0.5', 1234)
        with self.assertRaises(core.PkgError):
            core.direct_install('127.0.0.1', os.path.join(self.d, 'nope.pkg'), _fake_payload())
        txt = os.path.join(self.d, 'a.pkg')
        _write(txt, b'not a pkg')
        with self.assertRaises(core.PkgError):
            core.direct_install('127.0.0.1', txt, _fake_payload())

    def test_patch_payload_layout(self):
        out = core.patch_payload(_fake_payload(), '192.168.1.77', 0x1234)
        self.assertEqual(out[16384:16390], bytes([192, 168, 1, 77, 0x12, 0x34]))
        self.assertEqual(len(out), 16396)


class ArabicShaping(unittest.TestCase):
    def test_plain_text_untouched(self):
        self.assertEqual(core.ar('Hello 123'), 'Hello 123')

    def test_matches_cpp_reference_codepoints(self):
        # visual order produced by the C++ shaper that was verified against Raqm on the console build
        self.assertEqual([ord(c) for c in core.ar('دمج')], [0xFE9E, 0xFEE3, 0xFEA9])
        self.assertEqual([ord(c) for c in core.ar('لا')], [0xFEFB])


if __name__ == '__main__':
    unittest.main()
