import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

class TransferTab extends StatefulWidget {
  const TransferTab({super.key});
  @override
  State<TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends State<TransferTab> {
  static const int rpiPort = 12800;
  static const int serverPort = 9090;
  final _ip = TextEditingController(text: '10.191.41.57');
  final _path = TextEditingController();
  String _status = 'افتح Remote Package Installer على الـ PS4 أولاً';
  String _speed = '';
  bool _ok = false, _busy = false;
  double _progress = 0;
  int _sent = 0, _lastSent = 0, _size = 1;
  HttpServer? _server;
  Timer? _timer;

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r != null && r.files.single.path != null) {
      setState(() => _path.text = r.files.single.path!);
    }
  }

  Future<String> _wifiIp() async {
    String fallback = '';
    for (var i in await NetworkInterface.list()) {
      final n = i.name.toLowerCase();
      for (var a in i.addresses) {
        if (a.type != InternetAddressType.IPv4 || a.isLoopback) continue;
        if (n.contains('wlan') || n.contains('wifi')) return a.address;
        if (!n.contains('rmnet') && !n.contains('ccmni')) fallback = a.address;
      }
    }
    return fallback;
  }

  Future<void> _check() async {
    setState(() => _status = 'جاري الفحص...');
    try {
      final r = await http
          .post(Uri.parse('http://${_ip.text.trim()}:$rpiPort/api/install'),
              headers: {'Content-Type': 'application/json'}, body: '{}')
          .timeout(const Duration(seconds: 4));
      _ok = true;
      _status = 'التطبيق شغّال على الـ PS4 ✓ (${r.statusCode})';
    } catch (e) {
      _ok = false;
      _status = 'افتح Remote Package Installer على الـ PS4 وخليه على الشاشة';
    }
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _server?.close(force: true);
    _server = null;
    await WakelockPlus.disable();
    if (mounted) setState(() { _busy = false; _speed = ''; _status = 'تم إيقاف السيرفر'; });
  }

  Future<void> _start() async {
    final ps4 = _ip.text.trim();
    final file = File(_path.text.trim());
    if (ps4.isEmpty || !file.existsSync()) {
      setState(() => _status = 'خطأ: الملف غير موجود!');
      return;
    }
    final phone = await _wifiIp();
    if (phone.isEmpty) {
      setState(() => _status = 'خطأ: التلفون مش على الواي فاي');
      return;
    }
    final size = await file.length();
    final name = file.path.split('/').last;
    _size = size;
    _sent = 0;
    _lastSent = 0;
    setState(() { _busy = true; _progress = 0; _status = 'جاري التشغيل...'; });
    await WakelockPlus.enable();
    try {
      await _server?.close(force: true);
      _server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort, shared: true);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final d = _sent - _lastSent;
        _lastSent = _sent;
        if (mounted) {
          setState(() {
            _progress = (_sent / _size).clamp(0.0, 1.0);
            _speed = '${(d / 1048576).toStringAsFixed(1)} MB/s';
          });
        }
      });
      _server!.listen((HttpRequest req) async {
        try {
          final res = req.response;
          int start = 0, end = size - 1;
          res.headers.set('Accept-Ranges', 'bytes');
          res.headers.contentType = ContentType.binary;
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
          if (req.method == 'HEAD') { await res.close(); return; }
          final raf = await file.open();
          try {
            await raf.setPosition(start);
            int left = end - start + 1;
            while (left > 0) {
              final n = left < 4194304 ? left : 4194304;
              final chunk = await raf.read(n);
              if (chunk.isEmpty) break;
              res.add(chunk);
              await res.flush();
              left -= chunk.length;
              _sent += chunk.length;
            }
          } finally {
            await raf.close();
          }
          await res.close();
        } catch (_) {}
      });
      final url = 'http://$phone:$serverPort/package.pkg';
      setState(() => _status = 'إرسال الأمر للـ PS4...');
      final r = await http
          .post(Uri.parse('http://$ps4:$rpiPort/api/install'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'type': 'direct', 'packages': [url]}))
          .timeout(const Duration(seconds: 30));
      final okay = r.statusCode == 200 && r.body.contains('success');
      setState(() => _status = okay
          ? 'بدأ التثبيت ✓ خلي التطبيق مفتوح لين يخلص'
          : 'رد PS4: ${r.statusCode} ${r.body}');
    } catch (e) {
      _timer?.cancel();
      setState(() { _busy = false; _status = 'فشل الاتصال: $e'; });
      await WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _server?.close(force: true);
    WakelockPlus.disable();
    super.dispose();
  }

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7C4DFF))),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.circle, size: 12, color: _ok ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(width: 5),
              Text(_ok ? 'متصل' : 'غير متصل', style: TextStyle(fontSize: 12, color: _ok ? Colors.greenAccent : Colors.redAccent)),
            ]),
            const Text('نقل لـ PS4', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy ? null : _check,
            icon: const Icon(Icons.wifi_find, color: Color(0xFF7C4DFF)),
            label: const Text('فحص الاتصال بـ PS4'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45), side: const BorderSide(color: Color(0xFF7C4DFF))),
          ),
          const SizedBox(height: 15),
          TextField(controller: _ip, decoration: _dec('عنوان IP الخاص بـ PS4')),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: TextField(controller: _path, decoration: _dec('مسار ملف PKG'), style: const TextStyle(fontSize: 12))),
            IconButton(icon: const Icon(Icons.folder_open, color: Color(0xFF7C4DFF)), onPressed: _pick),
          ]),
          const Spacer(),
          if (_busy) LinearProgressIndicator(value: _progress, color: const Color(0xFF7C4DFF)),
          if (_busy) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${(_progress * 100).toStringAsFixed(1)}%   $_speed', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 10),
          Text(_status, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _status.contains('✓') ? Colors.greenAccent : Colors.grey)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _busy ? _stop : _start,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23232E), minimumSize: const Size(double.infinity, 50)),
            child: Text(_busy ? 'إيقاف السيرفر' : 'بدء النقل', style: const TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}
