import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const String kDirectVersion = 'v9';

class PkgMeta {
  final String contentId, headerType, bgftType, title, category, source;
  final int size;
  final Uint8List icon;
  PkgMeta(this.contentId, this.headerType, this.bgftType, this.title, this.category, this.source, this.size, this.icon);
}

int _be32(Uint8List b, int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
int _le32(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
int _le16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);

// PARAM.SFO -> text values only (CATEGORY, TITLE, ...)
Map<String, String> _parseSfo(Uint8List d) {
  final out = <String, String>{};
  if (d.length < 0x14 || d[0] != 0 || d[1] != 0x50 || d[2] != 0x53 || d[3] != 0x46) return out;
  final keyTab = _le32(d, 8);
  final dataTab = _le32(d, 12);
  final n = _le32(d, 16);
  for (var i = 0; i < n && i < 256; i++) {
    final e = 0x14 + i * 16;
    if (e + 16 > d.length) break;
    final ko = _le16(d, e);
    final fmt = _le16(d, e + 2);
    final len = _le32(d, e + 4);
    final dof = _le32(d, e + 12);
    var t = keyTab + ko;
    final s = t;
    while (t < d.length && d[t] != 0) {
      t++;
    }
    if (t >= d.length) continue;
    final key = ascii.decode(d.sublist(s, t), allowInvalid: true);
    final ds = dataTab + dof;
    if (fmt == 0x0404 || ds + len > d.length) continue;
    final raw = d.sublist(ds, ds + len);
    var z = raw.indexOf(0);
    if (z < 0) z = raw.length;
    out[key] = utf8.decode(raw.sublist(0, z), allowMalformed: true);
  }
  return out;
}

Future<PkgMeta> readPkgMeta(File f) async {
  final raf = await f.open();
  try {
    final size = await f.length();
    final h = await raf.read(0x100);
    if (h.length < 0x100 || h[0] != 0x7f || h[1] != 0x43 || h[2] != 0x4e || h[3] != 0x54) {
      throw 'الملف مش PKG صالح (الهيدر غلط)';
    }
    final idBytes = <int>[];
    for (var i = 0x40; i < 0x64 && h[i] != 0; i++) {
      idBytes.add(h[i]);
    }
    final ct = _be32(h, 0x74);
    final headerType = ct == 0x1B ? 'PS4AC' : (ct == 0x1E ? 'PS4GP' : 'PS4GD');
    var type = headerType;
    var title = '';
    var cat = '';
    var source = 'header';
    var icon = Uint8List(0);
    try {
      final count = _be32(h, 0x10);
      final table = _be32(h, 0x18);
      if (count > 0 && count <= 4096 && table < size) {
        await raf.setPosition(table);
        final raw = await raf.read(count * 32);
        var sfoOff = 0, sfoSz = 0, icoOff = 0, icoSz = 0;
        for (var i = 0; i + 32 <= raw.length; i += 32) {
          final id = _be32(raw, i);
          final off = _be32(raw, i + 16);
          final sz = _be32(raw, i + 20);
          if (id == 0x1000 && sz > 0 && sz <= (1 << 20) && off + sz <= size) {
            sfoOff = off;
            sfoSz = sz;
          } else if (id == 0x1200 && sz > 0 && sz <= (2 << 20) && off + sz <= size) {
            icoOff = off;
            icoSz = sz;
          }
        }
        if (sfoSz > 0) {
          await raf.setPosition(sfoOff);
          final p = _parseSfo(await raf.read(sfoSz));
          cat = (p['CATEGORY'] ?? '').trim().toLowerCase();
          title = (p['TITLE'] ?? '').trim();
          var k = '';
          if (cat == 'gd') {
            k = 'PS4GD';
          } else if (cat == 'gp') {
            k = 'PS4GP';
          } else if (cat == 'ac') {
            k = 'PS4AC';
          } else if (cat.startsWith('gd')) {
            k = 'PS4GD';
          }
          if (k.isNotEmpty) {
            type = k;
            source = 'PARAM.SFO';
          }
          if (icoSz > 0) {
            await raf.setPosition(icoOff);
            icon = await raf.read(icoSz);
          }
        }
      }
    } catch (_) {
      // keep the header guess
    }
    return PkgMeta(ascii.decode(idBytes, allowInvalid: true), headerType, type, title, cat, source, size, icon);
  } finally {
    await raf.close();
  }
}

Future<String> wifiIp() async {
  String fb = '';
  for (final i in await NetworkInterface.list()) {
    final n = i.name.toLowerCase();
    for (final a in i.addresses) {
      if (a.type != InternetAddressType.IPv4 || a.isLoopback) continue;
      if (n.contains('wlan') || n.contains('wifi') || n == 'en0') return a.address;
      if (!n.contains('rmnet') && !n.contains('ccmni') && !n.contains('pdp_ip')) fb = a.address;
    }
  }
  return fb;
}

int findBytes(Uint8List b, List<int> pat) {
  for (var i = 0; i <= b.length - pat.length; i++) {
    var ok = true;
    for (var j = 0; j < pat.length; j++) {
      if (b[i + j] != pat[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

Uint8List buildInfo(String url, String name, String id, String type, int size, Uint8List icon) {
  final b = BytesBuilder();
  void i32(int v) {
    final d = ByteData(4)..setInt32(0, v, Endian.little);
    b.add(d.buffer.asUint8List());
  }

  void str(String s) {
    final bytes = utf8.encode(s);
    i32(bytes.length);
    b.add(bytes);
  }

  i32(1);
  str(url);
  str(name);
  str(id);
  str(type);
  final d8 = ByteData(8)..setInt64(0, size, Endian.little);
  b.add(d8.buffer.asUint8List());
  i32(icon.length);
  b.add(icon);
  return b.toBytes();
}

class PkgServer {
  HttpServer? _srv;
  File? _file;
  int size = 0;
  int sent = 0;
  int manifestHits = 0;
  int pkgHits = 0;
  String _json = '';
  String phone = '';

  Future<void> start(File f, String phoneIp, int pkgSize) async {
    _file = f;
    size = pkgSize;
    phone = phoneIp;
    sent = 0;
    manifestHits = 0;
    pkgHits = 0;
    _json = '';
    _srv = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _srv!.listen(_handle, onError: (_) {});
  }

  // Same as DirectPackageInstaller: the file URL itself, and a JSON manifest of 4GB pieces only when the
  // package is bigger than 4GB.
  String directUrl(String fileName) {
    final src = base64Url.encode(utf8.encode(fileName));
    final port = _srv!.port;
    const piece = 4294967296;
    if (size <= piece) {
      _json = '';
      return 'http://$phone:$port/file?b64=$src';
    }
    final pieces = <Map<String, dynamic>>[];
    var off = 0;
    while (off < size) {
      final sz = (size - off) < piece ? (size - off) : piece;
      pieces.add({
        'url': 'http://$phone:$port/split?b64=$src&offset=$off&size=$sz',
        'fileOffset': off,
        'fileSize': sz,
        'hashValue': '0' * 40,
      });
      off += sz;
    }
    _json = jsonEncode({
      'originalFileSize': size,
      'packageDigest': '0' * 64,
      'numberOfSplitFiles': pieces.length,
      'pieces': pieces,
    });
    return 'http://$phone:$port/json/0.json';
  }

  Future<void> stop() async {
    try {
      await _srv?.close(force: true);
    } catch (_) {}
    _srv = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final res = req.response;
      final path = req.uri.path;
      if (path.startsWith('/json/') && _json.isNotEmpty) {
        if (req.method != 'HEAD') manifestHits++;
        final data = utf8.encode(_json);
        res.headers.contentType = ContentType('application', 'json');
        res.contentLength = data.length;
        if (req.method != 'HEAD') res.add(data);
        await res.close();
        return;
      }
      var base = 0;
      var total = size;
      if (path == '/split') {
        base = int.tryParse(req.uri.queryParameters['offset'] ?? '') ?? -1;
        total = int.tryParse(req.uri.queryParameters['size'] ?? '') ?? 0;
        if (base < 0 || total <= 0 || base + total > size) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.contentLength = 0;
          await res.close();
          return;
        }
      }
      int start = 0, end = total - 1;
      res.headers.set('Accept-Ranges', 'none');
      res.headers.contentType = ContentType.binary;
      res.headers.set('Content-Disposition', 'attachment; filename="app.pkg"');
      final rg = req.headers.value('range');
      if (rg != null) {
        final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rg);
        if (m != null) {
          if (m.group(1)!.isNotEmpty) start = int.parse(m.group(1)!);
          if (m.group(2)!.isNotEmpty) end = int.parse(m.group(2)!);
          if (end > total - 1) end = total - 1;
          res.statusCode = HttpStatus.partialContent;
          res.headers.set('Content-Range', 'bytes $start-$end/$total');
        }
      }
      res.bufferOutput = false;
      res.contentLength = end - start + 1;
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }
      pkgHits++;
      final raf = await _file!.open();
      try {
        await raf.setPosition(base + start);
        var left = end - start + 1;
        while (left > 0) {
          final c = await raf.read(left < 4194304 ? left : 4194304);
          if (c.isEmpty) break;
          res.add(c);
          await res.flush();
          left -= c.length;
          sent += c.length;
        }
      } finally {
        await raf.close();
      }
      await res.close();
    } catch (_) {}
  }
}

class DirectTab extends StatefulWidget {
  const DirectTab({super.key});
  @override
  State<DirectTab> createState() => _DirectTabState();
}

class _DirectTabState extends State<DirectTab> {
  final _ip = TextEditingController();
  File? _file;
  String _type = 'تلقائي';
  final List<String> _log = [];
  bool _busy = false, _serving = false;
  double _p = 0;
  String _speed = '';
  PkgServer? _server;
  ServerSocket? _ss;
  Timer? _t;
  int _lastSent = 0;
  DateTime? _sentAt;
  bool _w1 = false, _w2 = false, _started = false;

  void _add(String s) {
    if (mounted) setState(() => _log.add(s));
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r != null && r.files.single.path != null) setState(() => _file = File(r.files.single.path!));
  }

  Future<Socket> _connectPs4(String ip) async {
    for (var round = 0; round < 2; round++) {
      for (final port in [9090, 9021, 9020]) {
        try {
          _add('اتصال بـ $ip:$port ...');
          final s = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
          _add('تم الاتصال بالبورت $port');
          return s;
        } catch (_) {}
      }
      if (round == 0) await Future.delayed(const Duration(seconds: 3));
    }
    throw 'ما قدرتش أتصل بالبورتات 9090 و9021 و9020. تأكد إن GoldHEN شغال (Payload Server)';
  }

  Future<Uint8List> _loadPayload(String phone, int port) async {
    final bd = await rootBundle.load('assets/payload.bin');
    final p = Uint8List.fromList(bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes));
    final off = findBytes(p, [0xB4, 0xB4, 0xB4, 0xB4, 0xB4, 0xB4]);
    if (off < 0) throw 'payload.bin ما فيهوش الماركر (ملف غلط)';
    final ipb = phone.split('.').map(int.parse).toList();
    for (var i = 0; i < 4; i++) {
      p[off + i] = ipb[i];
    }
    p[off + 4] = (port >> 8) & 0xff;
    p[off + 5] = port & 0xff;
    return p;
  }

  Future<void> _stop({bool silent = false}) async {
    _t?.cancel();
    _t = null;
    try {
      await _ss?.close();
    } catch (_) {}
    _ss = null;
    await _server?.stop();
    _server = null;
    _sentAt = null;
    await WakelockPlus.disable();
    if (!silent) _add('تم إيقاف السيرفر');
    if (mounted) setState(() => _serving = false);
  }

  Future<void> _send() async {
    final f = _file;
    final ip = _ip.text.trim();
    if (f == null || ip.isEmpty) {
      _add('اختر ملف واكتب IP الـ PS4');
      return;
    }
    await _stop(silent: true);
    setState(() {
      _log.clear();
      _busy = true;
      _p = 0;
      _speed = '';
      _w1 = false;
      _w2 = false;
      _started = false;
    });
    await WakelockPlus.enable();
    try {
      final meta = await readPkgMeta(f);
      final auto = _type == 'تلقائي';
      final type = auto ? meta.bgftType : _type;
      final how = auto ? meta.source : 'يدوي';
      final catTxt = meta.category.isEmpty ? '' : ' category=${meta.category}';
      _add('الحزمة: ${meta.contentId}');
      _add('النوع: $type ($how$catTxt)');
      final phone = await wifiIp();
      if (phone.isEmpty) throw 'التلفون مش على الواي فاي';
      _add('IP التلفون: $phone');
      final server = PkgServer();
      await server.start(f, phone, meta.size);
      _server = server;
      final fileName = f.path.split(Platform.pathSeparator).last;
      final url = server.directUrl(fileName);
      _add('سيرفر الملف شغال (الإصدار $kDirectVersion، ${url.contains('/file?') ? 'رابط الملف مباشرة' : 'جدول تقسيم لأن الحزمة أكبر من 4GB'})');
      final ss = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _ss = ss;
      final accepted = Completer<Socket>();
      ss.listen((c) {
        if (!accepted.isCompleted) {
          accepted.complete(c);
        } else {
          c.destroy();
        }
      }, onError: (_) {});
      final payload = await _loadPayload(phone, ss.port);
      final s = await _connectPs4(ip);
      _add('إرسال الـ payload (${payload.length} بايت)...');
      s.add(payload);
      await s.flush();
      await s.close();
      _add('استنى الـ payload يتصل بالتلفون...');
      final c = await accepted.future.timeout(const Duration(seconds: 25),
          onTimeout: () => throw 'الـ payload ما رجّع اتصال. أطفئ BinLoader في GoldHEN وشغّله من جديد (أو أعد تشغيل الـ PS4) وجرّب');
      final fallbackName = fileName.replaceAll(RegExp(r'\.pkg$', caseSensitive: false), '');
      final name = meta.title.isEmpty ? fallbackName : meta.title;
      c.add(buildInfo(url, name, meta.contentId, type, meta.size, meta.icon));
      await c.flush();
      await c.close();
      _add('تم إرسال بيانات الحزمة ✓ (هذا لا يعني أن التحميل بدأ)');
      _add('انتظر رسالة: الـ PS4 بدأ التحميل. وخلي التطبيق مفتوح والشاشة شغالة');
      _sentAt = DateTime.now();
      _lastSent = 0;
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        final sv = _server;
        if (sv == null) return;
        final at = _sentAt;
        if (at != null) {
          final el = DateTime.now().difference(at).inSeconds;
          if (sv.pkgHits > 0) {
            if (!_started) {
              _started = true;
              _add('✓ الـ PS4 بدأ التحميل فعلاً');
            }
          } else if (sv.manifestHits == 0 && el > 30 && !_w1) {
            _w1 = true;
            _add('⚠ الـ PS4 ما طلب الملف. غالباً الـ payload خرج (إشعار DirectPackageInstaller Exited).');
            _add('الحل: في GoldHEN أطفئ BinLoader ثم شغّله من جديد (أو أعد تشغيل الـ PS4) ثم اضغط إرسال.');
          } else if (sv.manifestHits > 0 && el > 60 && !_w2) {
            _w2 = true;
            _add('⚠ الـ PS4 قرأ الوصف لكنه ما بدأ التحميل. تأكد من الشبكة (نفس الواي فاي) وجرّب نوع حزمة ثاني.');
          }
        }
        final d = sv.sent - _lastSent;
        _lastSent = sv.sent;
        if (mounted) {
          setState(() {
            _p = (sv.sent / sv.size).clamp(0.0, 1.0);
            _speed = '${(d / 1048576).toStringAsFixed(1)} MB/s';
          });
        }
      });
      if (mounted) setState(() => _serving = true);
    } catch (e) {
      _add('فشل: $e');
      await _stop(silent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _ss?.close();
    _server?.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Align(alignment: Alignment.centerRight, child: Text('إرسال مباشر (Payload) $kDirectVersion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        TextField(controller: _ip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IP الـ PS4', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.attach_file),
          label: Text(_file == null ? 'اختيار ملف PKG' : _file!.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'نوع الحزمة', border: OutlineInputBorder()),
          items: const ['تلقائي', 'PS4GD', 'PS4AC', 'PS4GP'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _type = v ?? 'تلقائي'),
        ),
        const SizedBox(height: 12),
        if (_serving) ...[
          LinearProgressIndicator(value: _p, color: const Color(0xFF7C4DFF)),
          const SizedBox(height: 4),
          Text('${(_p * 100).toStringAsFixed(1)}%   $_speed', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
        ],
        if (_log.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF1B1B25), borderRadius: BorderRadius.circular(10)),
            child: SelectableText(_log.join('\n'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _busy ? null : (_serving ? () => _stop() : _send),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23232E), minimumSize: const Size(double.infinity, 50)),
          child: Text(_busy ? '...' : (_serving ? 'إيقاف السيرفر' : 'إرسال للـ PS4'), style: const TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
        ),
      ]),
    );
  }
}
