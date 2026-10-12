import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart';

const int kChunk = 8388608;
double _lastP = -1;
void _prog(void Function(double) cb, double p) {
  if (p - _lastP >= 0.01 || p >= 1) { _lastP = p; cb(p); }
}
const Color kPurple = Color(0xFF7C4DFF);

class SpeedMeter {
  final int total;
  final Stopwatch _sw = Stopwatch()..start();
  double _lp = 0;
  int _lm = 0;
  String text = '';
  SpeedMeter(this.total);
  bool update(double p) {
    final ms = _sw.elapsedMilliseconds;
    if (p < 1 && ms - _lm < 500) return false;
    final dt = (ms - _lm) / 1000;
    if (dt > 0) {
      final sp = (p - _lp) * total / 1048576 / dt;
      final left = sp > 0 ? ((1 - p) * total / 1048576 / sp).round() : 0;
      final t = left >= 3600 ? '${left ~/ 3600}h ${(left % 3600) ~/ 60}m' : '${left ~/ 60}m ${left % 60}s';
      text = '${sp.toStringAsFixed(1)} MB/s  •  باقي $t';
    }
    _lp = p;
    _lm = ms;
    return true;
  }
}

Future<void> askStorage() async {
  if (!Platform.isAndroid) return;
  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }
}

Future<Directory> outDir() async {
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

const int _bufSize = 8388608;

Future<void> _copyRange(RandomAccessFile src, RandomAccessFile dst, int length, void Function(int) onBytes) async {
  var a = Uint8List(_bufSize);
  var b = Uint8List(_bufSize);
  var left = length;
  if (left <= 0) return;
  var got = await src.readInto(a, 0, left < _bufSize ? left : _bufSize);
  while (got > 0) {
    left -= got;
    final w = dst.writeFrom(a, 0, got);
    var next = 0;
    if (left > 0) {
      next = await src.readInto(b, 0, left < _bufSize ? left : _bufSize);
    }
    await w;
    onBytes(got);
    final t = a;
    a = b;
    b = t;
    got = next;
  }
}

Future<String?> pickFromFolder(BuildContext context) async {
  final dir = await FilePicker.platform.getDirectoryPath();
  if (dir == null) return null;
  final files = Directory(dir).listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  if (!context.mounted) return null;
  if (files.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المجلد فاضي أو ما فيش صلاحية')));
    return null;
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        for (final x in files)
          ListTile(
            title: Text(x.path.split('/').last, overflow: TextOverflow.ellipsis),
            subtitle: Text('${(x.lengthSync() / 1048576).toStringAsFixed(1)} MB'),
            onTap: () => Navigator.pop(c, x.path),
          ),
      ]),
    ),
  );
}

Future<List<String>> pickPartsFromFolder(BuildContext context) async {
  final dir = await FilePicker.platform.getDirectoryPath();
  if (dir == null) return [];
  final re = RegExp(r'^(.*)\.part(\d+)$');
  final groups = <String, List<String>>{};
  for (final e in Directory(dir).listSync().whereType<File>()) {
    final m = re.firstMatch(e.path.split('/').last);
    if (m != null) groups.putIfAbsent(m.group(1)!, () => []).add(e.path);
  }
  if (!context.mounted) return [];
  if (groups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما لقيت أجزاء .partN في المجلد')));
    return [];
  }
  if (groups.length == 1) return groups.values.first;
  final pick = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        for (final k in groups.keys)
          ListTile(
            title: Text(k, overflow: TextOverflow.ellipsis),
            subtitle: Text('${groups[k]!.length} أجزاء'),
            onTap: () => Navigator.pop(c, k),
          ),
      ]),
    ),
  );
  return pick == null ? [] : groups[pick]!;
}

Future<String> splitFile(String path, int parts, void Function(double) onProgress) async {
  final f = File(path);
  final size = await f.length();
  final base = path.split('/').last;
  final dir = await outDir();
  final partSize = (size + parts - 1) ~/ parts;
  final src = await f.open();
  int done = 0;
  try {
    for (int i = 1; i <= parts; i++) {
      final len = min(partSize, size - done);
      if (len <= 0) break;
      final dst = await File('${dir.path}/$base.part$i').open(mode: FileMode.write);
      try {
        await _copyRange(src, dst, len, (n) {
          done += n;
          onProgress(done / size);
        });
        await dst.flush();
      } finally {
        await dst.close();
      }
    }
  } finally {
    await src.close();
  }
  return dir.path;
}

class _Part {
  final String path;
  final int n;
  _Part(this.path, this.n);
}

Future<String> mergeFiles(List<String> paths, void Function(double) onProgress) async {
  final re = RegExp(r'^(.*)\.part(\d+)$');
  String? base;
  final list = <_Part>[];
  for (final p in paths) {
    final name = p.split('/').last;
    final m = re.firstMatch(name);
    if (m == null) throw 'اسم غير صالح (لازم ينتهي بـ .partN): $name';
    if (base != null && base != m.group(1)) throw 'الأجزاء من ملفات مختلفة';
    base = m.group(1);
    list.add(_Part(p, int.parse(m.group(2)!)));
  }
  list.sort((a, b) => a.n.compareTo(b.n));
  for (int i = 0; i < list.length; i++) {
    if (list[i].n != i + 1) throw 'جزء ناقص: متوقع part${i + 1}';
  }
  int total = 0;
  for (final x in list) {
    total += await File(x.path).length();
  }
  final dir = await outDir();
  final out = File('${dir.path}/$base');
  final dst = await out.open(mode: FileMode.write);
  int done = 0;
  try {
    for (final x in list) {
      final src = await File(x.path).open();
      try {
        final len = await src.length();
        await _copyRange(src, dst, len, (n) {
          done += n;
          onProgress(done / total);
        });
      } finally {
        await src.close();
      }
    }
    await dst.flush();
  } finally {
    await dst.close();
  }
  if (await out.length() != total) throw 'الحجم النهائي غلط';
  return out.path;
}

InputDecoration kDec(String l) => InputDecoration(
      labelText: l,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPurple)),
    );

class SplitTab extends StatefulWidget {
  const SplitTab({super.key});
  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  String? _path;
  String _name = '';
  int _size = 0;
  String _status = 'اختر ملف PKG للبدء';
  bool _busy = false;
  double _progress = 0;
  String _speed = '';
  final _parts = TextEditingController(text: '4');

  Future<void> _pick() async {
    await askStorage();
    try {
      String? p;
      if (Platform.isAndroid) {
        p = await pickFromFolder(context);
      } else {
        final r = await FilePicker.platform.pickFiles(type: FileType.any);
        p = r?.files.single.path;
      }
      if (p == null) return;
      final String path = p;
      final sz = await File(path).length();
      final need = (sz / 4000000000).ceil();
      if (need > (int.tryParse(_parts.text.trim()) ?? 0)) _parts.text = '$need';
      setState(() {
        _path = path;
        _name = path.split('/').last;
        _size = sz;
        _progress = 0;
        _status = 'تم اختيار الملف ✓';
      });
    } catch (e) {
      setState(() => _status = 'خطأ في الاختيار: $e');
    }
  }

  Future<void> _go() async {
    if (_path == null) {
      setState(() => _status = 'اختر ملف أولاً');
      return;
    }
    final n = int.tryParse(_parts.text.trim()) ?? 0;
    if (n < 2 || n > _size) {
      setState(() => _status = 'عدد الأجزاء غلط (أقل شي 2)');
      return;
    }
    if ((_size + n - 1) ~/ n >= 4294967295) {
      setState(() => _status = 'الجزء أكبر من 4 جيجا، FAT32 ما يقبلوش. زيد عدد الأجزاء');
      return;
    }
    setState(() { _busy = true; _progress = 0; _speed = ''; _status = 'جاري التقسيم...'; });
    try {
      final sm = SpeedMeter(_size);
      final dir = await splitFile(_path!, n, (p) {
        if (sm.update(p) && mounted) setState(() { _progress = p; _speed = sm.text; });
      });
      setState(() => _status = 'تم التقسيم ✓\n$dir');
      final base = _path!.split('/').last;
      final files = Directory(dir).listSync().whereType<File>().where((x) => x.path.split('/').last.startsWith('$base.part')).map((x) => XFile(x.path)).toList();
      if (Platform.isIOS && files.isNotEmpty) await Share.shareXFiles(files);
    } catch (e) {
      setState(() => _status = 'فشل التقسيم: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.settings, color: kPurple, size: 26),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const Text('تقسيم ملفات PKG', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.folder_outlined, color: Colors.white),
            label: const Text('اختيار ملف PKG', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23232E), minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.snippet_folder, size: 55, color: kPurple),
                const SizedBox(height: 10),
                Text(_path == null ? 'لم يتم اختيار ملف' : _name, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9E86FF), fontWeight: FontWeight.bold)),
                if (_path != null) Text('${(_size / 1048576).toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.grey)),
              ]),
            ),
          ),
          TextField(controller: _parts, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: kDec('عدد الأجزاء')),
          const SizedBox(height: 15),
          if (_busy) LinearProgressIndicator(value: _progress, color: kPurple),
          if (_busy) Text('${(_progress * 100).toStringAsFixed(1)}%   $_speed', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Text(_status, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _status.contains('✓') ? Colors.greenAccent : Colors.grey)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _busy ? null : _go,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23232E), minimumSize: const Size(double.infinity, 50)),
            child: const Text('بدء التقسيم', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}

class MergeTab extends StatefulWidget {
  const MergeTab({super.key});
  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> {
  List<String> _paths = [];
  String _status = 'اختر كل أجزاء الملف (part1, part2...)';
  bool _busy = false;
  double _progress = 0;
  String _speed = '';

  Future<void> _pick() async {
    await askStorage();
    try {
      List<String> p;
      if (Platform.isAndroid) {
        p = await pickPartsFromFolder(context);
      } else {
        final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
        p = r == null ? <String>[] : r.files.where((x) => x.path != null).map((x) => x.path!).toList();
      }
      if (p.isEmpty) return;
      setState(() {
        _paths = p;
        _progress = 0;
        _status = 'تم اختيار ${p.length} أجزاء ✓';
      });
    } catch (e) {
      setState(() => _status = 'خطأ في الاختيار: $e');
    }
  }

  Future<void> _go() async {
    if (_paths.length < 2) {
      setState(() => _status = 'اختر جزئين على الأقل');
      return;
    }
    setState(() { _busy = true; _progress = 0; _speed = ''; _status = 'جاري الدمج...'; });
    try {
      final tot = _paths.fold<int>(0, (a, x) => a + File(x).lengthSync());
      final sm = SpeedMeter(tot);
      final out = await mergeFiles(_paths, (p) {
        if (sm.update(p) && mounted) setState(() { _progress = p; _speed = sm.text; });
      });
      setState(() => _status = 'تم الدمج ✓\n$out');
      if (Platform.isIOS) await Share.shareXFiles([XFile(out)]);
    } catch (e) {
      setState(() => _status = 'فشل الدمج: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Align(alignment: Alignment.centerRight, child: Text('دمج أجزاء PKG', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.file_upload, color: Colors.white),
            label: const Text('اختيار أجزاء PKG', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23232E), minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(children: [
              for (final p in _paths) Text(p.split('/').last, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          if (_busy) LinearProgressIndicator(value: _progress, color: kPurple),
          if (_busy) Text('${(_progress * 100).toStringAsFixed(1)}%   $_speed', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Text(_status, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _status.contains('✓') ? Colors.greenAccent : Colors.grey)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _busy ? null : _go,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23232E), minimumSize: const Size(double.infinity, 50)),
            child: const Text('بدء الدمج', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}
