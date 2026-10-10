import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class StoreItem {
  final String id, name, desc, url, tag, icon, platform, version;
  final int size;
  final bool direct;
  const StoreItem(this.name, this.desc, this.url, this.tag,
      {this.id = '', this.icon = '', this.platform = 'PS4', this.version = '', this.size = 0, this.direct = false});
}

const List<StoreItem> kItems = [
  StoreItem('GoldHEN', 'Homebrew enabler للـ PS4', 'https://github.com/GoldHEN/GoldHEN', 'نظام'),
  StoreItem('PS4 Store', 'متجر homebrew مفتوح المصدر', 'https://github.com/LightningMods/PS4-Store', 'متجر'),
];

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse(_s(v)) ?? 0);
String _fmt(int b) {
  if (b <= 0) return '';
  if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)} GB';
  return '${(b / 1048576).toStringAsFixed(1)} MB';
}

class _Dl {
  double p = 0;
  String info = '';
  bool running = false, done = false, cancel = false;
}

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  String _q = '';
  String _plat = 'الكل';
  final Map<String, _Dl> _dl = {};

  Future<Directory> _dir() async {
    Directory d;
    if (Platform.isAndroid) {
      d = Directory('/storage/emulated/0/Download/PS4_PKG_Tools');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      d = Directory('${docs.path}/PS4_PKG_Tools');
    }
    await d.create(recursive: true);
    return d;
  }

  Future<void> _download(StoreItem e) async {
    final st = _dl.putIfAbsent(e.id.isEmpty ? e.name : e.id, () => _Dl());
    if (st.running) return;
    if (Platform.isAndroid && !await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
    setState(() { st.running = true; st.done = false; st.p = 0; st.info = ''; st.cancel = false; });
    final client = HttpClient();
    IOSink? sink;
    File? partial;
    try {
      final dir = await _dir();
      var name = Uri.decodeComponent(Uri.parse(e.url).pathSegments.last).replaceFirst(RegExp(r'^\d{10,}_'), '');
      if (name.isEmpty) name = '${e.name}.bin';
      final file = File('${dir.path}/$name');
      partial = file;
      final req = await client.getUrl(Uri.parse(e.url));
      final res = await req.close();
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final total = res.contentLength > 0 ? res.contentLength : e.size;
      sink = file.openWrite();
      int got = 0, lastGot = 0, lastMs = 0;
      final sw = Stopwatch()..start();
      await for (final chunk in res) {
        if (st.cancel) throw 'تم الإلغاء';
        sink.add(chunk);
        got += chunk.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - lastMs >= 500) {
          final speed = (got - lastGot) / 1048576 / ((ms - lastMs) / 1000);
          lastGot = got;
          lastMs = ms;
          if (mounted) setState(() { st.p = total > 0 ? got / total : 0; st.info = '${speed.toStringAsFixed(1)} MB/s'; });
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (mounted) setState(() { st.running = false; st.done = true; st.p = 1; st.info = file.path; });
    } catch (err) {
      try { await sink?.close(); } catch (_) {}
      try { await partial?.delete(); } catch (_) {}
      if (mounted) setState(() { st.running = false; st.done = false; st.info = 'فشل: $err'; });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرتش أفتح الرابط')));
    }
  }

  List<StoreItem> _filter(List<StoreItem> all) => all.where((e) {
        final q = _q.toLowerCase();
        final okQ = e.name.toLowerCase().contains(q) || e.desc.toLowerCase().contains(q);
        final okP = _plat == 'الكل' || e.platform == 'PS4+PS5' || e.platform == _plat;
        return okQ && okP;
      }).toList();

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFF2A2A38), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF9E86FF))),
      );

  Widget _action(StoreItem e) {
    final st = _dl[e.id.isEmpty ? e.name : e.id];
    if (!e.direct) {
      return OutlinedButton.icon(
        onPressed: () => _open(e.url),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: const Text('فتح الصفحة'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
      );
    }
    if (st != null && st.running) {
      return Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: st.p > 0 ? st.p : null, minHeight: 8, color: const Color(0xFF7C4DFF)),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(st.p * 100).toStringAsFixed(0)}%   ${st.info}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          TextButton(onPressed: () => st.cancel = true, child: const Text('إلغاء')),
        ]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (st != null && st.done)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('تم التحميل ✓\n${st.info}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
        ),
      if (st != null && !st.done && st.info.startsWith('فشل'))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(st.info, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
        ),
      FilledButton.icon(
        onPressed: () => _download(e),
        icon: const Icon(Icons.download),
        label: Text(st != null && st.done ? 'تحميل مرة ثانية' : 'تحميل'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), minimumSize: const Size(double.infinity, 44)),
      ),
    ]);
  }

  Widget _card(StoreItem e) {
    final lead = e.icon.isEmpty
        ? Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: const Color(0xFF2A2A38), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.extension, color: Color(0xFF7C4DFF), size: 30),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(e.icon, width: 56, height: 56, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      width: 56, height: 56, color: const Color(0xFF2A2A38),
                      child: const Icon(Icons.extension, color: Color(0xFF7C4DFF), size: 30),
                    )),
          );
    return Card(
      color: const Color(0xFF1B1B25),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lead,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(e.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(e.platform),
            if (e.version.isNotEmpty) _chip('v${e.version}'),
            if (e.tag.isNotEmpty) _chip(e.tag),
            if (_fmt(e.size).isNotEmpty) _chip(_fmt(e.size)),
          ]),
          const SizedBox(height: 12),
          _action(e),
        ]),
      ),
    );
  }

  Widget _list(List<StoreItem> items) {
    if (items.isEmpty) return const Center(child: Text('ما فيش نتائج'));
    return ListView.builder(itemCount: items.length, itemBuilder: (_, i) => _card(items[i]));
  }

  Widget _body() {
    if (Firebase.apps.isEmpty) return _list(_filter(kItems));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (c, snap) {
        if (snap.hasError) return _list(_filter(kItems));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _list(_filter(kItems));
        final items = docs.map((d) {
          final m = d.data();
          final url = _s(m['fileUrl']).isEmpty ? _s(m['url']) : _s(m['fileUrl']);
          return StoreItem(_s(m['name']), _s(m['desc']), url, _s(m['tag']),
              id: d.id,
              icon: _s(m['iconUrl']),
              platform: _s(m['platform']).isEmpty ? 'PS4' : _s(m['platform']),
              version: _s(m['version']),
              size: _i(m['size']),
              direct: _s(m['fileAsset']).isNotEmpty);
        }).toList();
        return _list(_filter(items));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Align(alignment: Alignment.centerRight, child: Text('متجر الأدوات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 15),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'ابحث...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7C4DFF)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final p in ['الكل', 'PS4', 'PS5'])
              ChoiceChip(label: Text(p), selected: _plat == p, onSelected: (_) => setState(() => _plat = p)),
          ]),
          const SizedBox(height: 10),
          Expanded(child: _body()),
        ]),
      ),
    );
  }
}
