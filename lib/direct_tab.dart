import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PkgMeta {
  final String contentId, type;
  final int size;
  PkgMeta(this.contentId, this.type, this.size);
}

Future<PkgMeta> readPkgMeta(File f) async {
  final raf = await f.open();
  try {
    final h = await raf.read(0x80);
    if (h.length < 0x80 || h[0] != 0x7f || h[1] != 0x43 || h[2] != 0x4e || h[3] != 0x54) {
      throw 'الملف مش PKG صالح (الهيدر غلط)';
    }
    final idBytes = <int>[];
    for (var i = 0x40; i < 0x64 && h[i] != 0; i++) {
      idBytes.add(h[i]);
    }
    final ct = (h[0x74] << 24) | (h[0x75] << 16) | (h[0x76] << 8) | h[0x77];
    var type = 'PS4GD';
    if (ct == 0x1B) {
      type = 'PS4AC';
    } else if (ct == 0x1E) {
      type = 'PS4GP';
    }
    return PkgMeta(ascii.decode(idBytes, allowInvalid: true), type, await f.length());
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

Uint8List buildInfo(String url, String name, String id, String type, int size) {
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
  i32(0);
  return b.toBytes();
}

class PkgServer {
  HttpServer? _srv;
  File? _file;
  int size = 0;
  int sent = 0;
  String _json = '';
  String phone = '';

  Future<void> start(File f, String phoneIp, int pkgSize) async {
    _file = f;
    size = pkgSize;
    phone = phoneIp;
    sent = 0;
    _srv = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final pkgUrl = 'http://$phoneIp:${_srv!.port}/pkg/app.pkg';
    _json = jsonEncode({
      'originalFileSize': pkgSize,
      'packageDigest': '0' * 64,
      'numberOfSplitFiles': 1,
      'pieces': [
        {'url': pkgUrl, 'fileOffset': 0, 'fileSize': pkgSize, 'hashValue': '0' * 40}
      ],
    });
    _srv!.listen(_handle, onError: (_) {});
  }

  String manifestUrl() => 'http://$phone:${_srv!.port}/json/0.json';

  Future<void> stop() async {
    try {
      await _srv?.close(force: true);
    } catch (_) {}
    _srv = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final res = req.response;
      if (req.uri.path.startsWith('/json/')) {
        final data = utf8.encode(_json);
        res.headers.contentType = ContentType('application', 'json');
        res.contentLength = data.length;
        if (req.method != 'HEAD') res.add(data);
        await res.close();
        return;
      }
      int start = 0, end = size - 1;
      res.headers.set('Accept-Ranges', 'bytes');
      res.headers.contentType = ContentType.binary;
      res.headers.set('Content-Disposition', 'attachment; filename="app.pkg"');
      final rg = req.headers.value('range');
      if (rg != null) {
        final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rg);
        if (m != null) {
          if (m.group(1)!.isNotEmpty) start = int.parse(m.group(1)!);
          if (m.group(2)!.isNotEmpty) end = int.parse(m.group(2)!);
          if (end > size - 1) end = size - 1;
          res.statusCode = HttpStatus.partialContent;
          res.headers.set('Content-Range', 'bytes $start-$end/$size');
        }
      }
      res.bufferOutput = false;
      res.contentLength = end - start + 1;
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }
      final raf = await _file!.open();
      try {
        await raf.setPosition(start);
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
    setState(() { _log.clear(); _busy = true; _p = 0; _speed = ''; });
    await WakelockPlus.enable();
    try {
      final meta = await readPkgMeta(f);
      final type = _type == 'تلقائي' ? meta.type : _type;
      _add('الحزمة: ${meta.contentId}   النوع: $type');
      final phone = await wifiIp();
      if (phone.isEmpty) throw 'التلفون مش على الواي فاي';
      _add('IP التلفون: $phone');
      final server = PkgServer();
      await server.start(f, phone, meta.size);
      _server = server;
      final url = server.manifestUrl();
      _add('سيرفر الملف شغال');
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
          onTimeout: () => throw 'الـ payload ما رجّعش اتصال. جرّب تعيد التشغيل أو شغّل GoldHEN من جديد');
      final name = f.path.split('/').last.replaceAll(RegExp(r'\.pkg$', caseSensitive: false), '');
      c.add(buildInfo(url, name, meta.contentId, type, meta.size));
      await c.flush();
      await c.close();
      _add('تم إرسال بيانات الحزمة ✓');
      _add('تابع من Notifications ← Downloads على الـ PS4، وخلي التطبيق مفتوح لين يخلص');
      _lastSent = 0;
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        final sv = _server;
        if (sv == null) return;
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
        const Align(alignment: Alignment.centerRight, child: Text('إرسال مباشر (Payload)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        TextField(controller: _ip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IP الـ PS4', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.attach_file),
          label: Text(_file == null ? 'اختيار ملف PKG' : _file!.path.split('/').last, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'نوع الحزمة', border: OutlineInputBorder()),
          items: const ['تلقائي', 'PS4GD', 'PS4GP', 'PS4AC'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
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
