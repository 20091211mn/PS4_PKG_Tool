import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PKGStudioApp());
}

class PKGStudioApp extends StatelessWidget {
  const PKGStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    SplitterScreen(),
    MergerScreen(),
    DirectInstallerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
  }

  Future<void> _askPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.manageExternalStorage.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.call_split), label: 'تقسيم'),
          BottomNavigationBarItem(icon: Icon(Icons.merge_type), label: 'دمج'),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'نقل للـ PS4'),
        ],
      ),
    );
  }
}

// ---------------------- 1. شاشة التقسيم ----------------------
class SplitterScreen extends StatefulWidget {
  const SplitterScreen({super.key});

  @override
  State<SplitterScreen> createState() => _SplitterScreenState();
}

class _SplitterScreenState extends State<SplitterScreen> {
  String? _selectedFilePath;
  final _partsController = TextEditingController(text: "4");
  double _selectedSpeedMB = 0;
  double _progress = 0.0;
  String _status = "اختر ملف PKG للبدء";
  bool _isProcessing = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _status = "تم اختيار: ${result.files.single.name}";
      });
    }
  }

  Future<Directory> _getOutputDir() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/sdcard/Download/PS4_PKG_Tools');
      try {
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
        return baseDir;
      } catch (_) {
        baseDir = await getExternalStorageDirectory();
      }
    }
    baseDir ??= await getApplicationDocumentsDirectory();
    final outDir = Directory('${baseDir.path}/PS4_PKG_Tools');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  Future<void> _splitFile() async {
    if (_selectedFilePath == null) {
      setState(() => _status = "يرجى اختيار ملف أولاً!");
      return;
    }

    final partsCount = int.tryParse(_partsController.text) ?? 4;
    final file = File(_selectedFilePath!);

    if (!await file.exists()) {
      setState(() => _status = "الملف غير موجود!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _status = "جاري التقسيم...";
    });

    try {
      final totalSize = await file.length();
      final partSize = totalSize ~/ partsCount;
      final outputDir = await _getOutputDir();

      final baseName = file.uri.pathSegments.last.replaceAll('.pkg', '');
      final inputStream = file.openRead();

      int currentPartIndex = 1;
      int bytesWrittenCurrentPart = 0;
      int totalBytesProcessed = 0;

      IOSink currentSink = File("${outputDir.path}/${baseName}_part$currentPartIndex.pkg.part").openWrite();

      final Stopwatch stopwatch = Stopwatch()..start();

      await for (final chunk in inputStream) {
        int offset = 0;
        while (offset < chunk.length) {
          int target = (currentPartIndex < partsCount) ? partSize : (totalSize - (partSize * (partsCount - 1)));
          int remaining = target - bytesWrittenCurrentPart;
          int toWrite = (chunk.length - offset < remaining) ? (chunk.length - offset) : remaining;

          currentSink.add(chunk.sublist(offset, offset + toWrite));
          bytesWrittenCurrentPart += toWrite;
          offset += toWrite;
          totalBytesProcessed += toWrite;

          if (_selectedSpeedMB > 0) {
            double expectedTimeMs = (totalBytesProcessed / (_selectedSpeedMB * 1024 * 1024)) * 1000;
            int actualTimeMs = stopwatch.elapsedMilliseconds;
            if (expectedTimeMs > actualTimeMs) {
              await Future.delayed(Duration(milliseconds: (expectedTimeMs - actualTimeMs).toInt()));
            }
          }

          setState(() {
            _progress = totalBytesProcessed / totalSize;
            _status = "تقسيم جزء $currentPartIndex من $partsCount (${(_progress * 100).toStringAsFixed(1)}%)";
          });

          if (bytesWrittenCurrentPart >= target && currentPartIndex < partsCount) {
            await currentSink.flush();
            await currentSink.close();
            currentPartIndex++;
            bytesWrittenCurrentPart = 0;
            currentSink = File("${outputDir.path}/${baseName}_part$currentPartIndex.pkg.part").openWrite();
          }
        }
      }

      await currentSink.flush();
      await currentSink.close();
      setState(() {
        _status = "تم التقسيم بنجاح في:\n${outputDir.path}";
        _progress = 1.0;
      });
    } catch (e) {
      setState(() => _status = "خطأ: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقسيم ملفات PKG')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('اختيار ملف PKG من الذاكرة'),
            ),
            const SizedBox(height: 8),
            Text(_selectedFilePath ?? 'لم يتم اختيار ملف', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 30),
            TextField(
              controller: _partsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الأجزاء', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text('تحديد السرعة: '),
                DropdownButton<double>(
                  value: _selectedSpeedMB,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('أقصى سرعة (مفتوح)')),
                    DropdownMenuItem(value: 1.0, child: Text('1 ميجابايت/ثانية')),
                    DropdownMenuItem(value: 2.0, child: Text('2 ميجابايت/ثانية')),
                    DropdownMenuItem(value: 5.0, child: Text('5 ميجابايت/ثانية')),
                    DropdownMenuItem(value: 10.0, child: Text('10 ميجابايت/ثانية')),
                  ],
                  onChanged: (val) => setState(() => _selectedSpeedMB = val ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
            Text(_status, textAlign: TextAlign.center),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _splitFile,
                child: Text(_isProcessing ? 'جاري التقسيم...' : 'بدء التقسيم'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------- 2. شاشة الدمج ----------------------
class MergerScreen extends StatefulWidget {
  const MergerScreen({super.key});

  @override
  State<MergerScreen> createState() => _MergerScreenState();
}

class _MergerScreenState extends State<MergerScreen> {
  List<String> _selectedFiles = [];
  double _progress = 0.0;
  String _status = "اختر أجزاء `.part` لدمجها";
  bool _isProcessing = false;

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _selectedFiles = result.paths.whereType<String>().toList();
        _selectedFiles.sort();
        _status = "تم اختيار ${_selectedFiles.length} أجزاء";
      });
    }
  }

  Future<Directory> _getOutputDir() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/sdcard/Download/PS4_PKG_Tools');
      try {
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
        return baseDir;
      } catch (_) {
        baseDir = await getExternalStorageDirectory();
      }
    }
    baseDir ??= await getApplicationDocumentsDirectory();
    final outDir = Directory('${baseDir.path}/PS4_PKG_Tools');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  Future<void> _mergeFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _status = "جاري البدء في التجميع...";
    });

    try {
      final outputDir = await _getOutputDir();
      final mergedFile = File("${outputDir.path}/merged_game.pkg");
      final sink = mergedFile.openWrite();

      int totalBytes = 0;
      for (var path in _selectedFiles) {
        totalBytes += await File(path).length();
      }

      int processedBytes = 0;

      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = File(_selectedFiles[i]);
        final stream = file.openRead();

        await for (final chunk in stream) {
          sink.add(chunk);
          processedBytes += chunk.length;
          setState(() {
            _progress = processedBytes / totalBytes;
            _status = "دمج الجزء ${i + 1} من ${_selectedFiles.length} (${(_progress * 100).toStringAsFixed(1)}%)";
          });
        }
      }

      await sink.flush();
      await sink.close();

      setState(() {
        _status = "تم دمج الملف بنجاح في:\n${outputDir.path}";
        _progress = 1.0;
      });
    } catch (e) {
      setState(() => _status = "خطأ أثناء الدمج: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دمج أجزاء PKG')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickFiles,
              icon: const Icon(Icons.file_copy),
              label: const Text('تحديد أجزاء الملفات (Part Files)'),
            ),
            const SizedBox(height: 10),
            Text("الأجزاء المحددة: ${_selectedFiles.length}"),
            const Divider(height: 30),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
            Text(_status, textAlign: TextAlign.center),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _mergeFiles,
                child: Text(_isProcessing ? 'جاري الدمج...' : 'بدء التجميع والدمج'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------------- 3. شاشة Direct Package Installer ----------------------
class DirectInstallerScreen extends StatefulWidget {
  const DirectInstallerScreen({super.key});

  @override
  State<DirectInstallerScreen> createState() => _DirectInstallerScreenState();
}

class _DirectInstallerScreenState extends State<DirectInstallerScreen> {
  final _ipController = TextEditingController(text: "192.168.1.100");
  final _urlController = TextEditingController();
  String _status = "أدخل آي بي البلايستيشن ورابط الملف المباشر";

  Future<void> _sendToPS4() async {
    final ip = _ipController.text.trim();
    final pkgUrl = _urlController.text.trim();

    if (ip.isEmpty || pkgUrl.isEmpty) {
      setState(() => _status = "يرجى كتابة IP ورابط الـ PKG!");
      return;
    }

    setState(() => _status = "جاري الإرسال إلى PS4 ($ip)...");

    try {
      final response = await http.post(
        Uri.parse("http://$ip:12800/api/install"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "type": "direct",
          "packages": [pkgUrl]
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _status = "تم إرسال أمر التثبيت بنجاح للـ PS4!");
      } else {
        setState(() => _status = "فشل الإرسال: رمز الاستجابة ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _status = "تعذر الاتصال بالـ PS4. تأكد من تشغيل Direct Package Installer على السوني بنفس الشبكة!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النقل المباشر (Direct Package Installer)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'IP جهاز الـ PS4', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'رابط ملف PKG المباشر', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sendToPS4,
                icon: const Icon(Icons.send),
                label: const Text('إرسال للتثبيت على PS4'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
