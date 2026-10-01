#!/bin/bash

cat << 'DART_EOF' > lib/main.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PS4PkgStudioApp());
}

class PS4PkgStudioApp extends StatelessWidget {
  const PS4PkgStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 PKG Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121216),
        primaryColor: const Color(0xFF6C5CE7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFF1E1E24),
        ),
      ),
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    SplitTab(),
    MergeTab(),
    SendPs4Tab(),
  ];

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('الإعدادات', textAlign: TextAlign.right),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.right,
          children: [
            Text('مسار الحفظ الافتراضي:', style: TextStyle(color: Colors.grey, fontSize: 13)),
            SizedBox(height: 5),
            Text('/Download/PS4_PKG_Tools/', style: TextStyle(color: Color(0xFF9D84FF), fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Color(0xFF9D84FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121216),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: _showSettingsDialog,
        ),
        title: const Text(
          'PKG تقسيم ملفات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF18181C),
        selectedItemColor: const Color(0xFF9D84FF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.call_split),
            label: 'تقسيم',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.merge_type),
            label: 'دمج',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: 'نقل لـ PS4',
          ),
        ],
      ),
    );
  }
}

class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedFilePath = '';
  String _selectedFileName = '';
  String _selectedSpeed = 'أقصى سرعة (مفتوح)';
  String _statusMessage = 'للبدء اختر ملف PKG';
  bool _isProcessing = false;
  double _progress = 0.0;

  final List<String> _speedOptions = [
    'أقصى سرعة (مفتوح)',
    'متوسطة (50 MB/s)',
    'منخفضة (10 MB/s)',
  ];

  Future<Directory> _getOutputDir() async {
    final Directory dir = Directory('/storage/emulated/0/Download/PS4_PKG_Tools');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _pickFile() async {
    await _requestPermissions();
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path!;
        _selectedFileName = result.files.single.name;
        _statusMessage = 'تم اختيار الملف جاهز للتقسيم';
      });
    }
  }

  Future<void> _startSplit() async {
    if (_selectedFilePath.isEmpty) {
      setState(() => _statusMessage = 'يرجى اختيار ملف PKG أولاً!');
      return;
    }

    final inputFile = File(_selectedFilePath);
    if (!await inputFile.exists()) {
      setState(() => _statusMessage = 'الملف غير موجود في الذاكرة');
      return;
    }

    final partsCount = int.tryParse(_partsController.text.trim()) ?? 4;
    if (partsCount <= 1) {
      setState(() => _statusMessage = 'يرجى تحديد عدد أجزاء أكبر من 1');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'جاري التقسيم وتخزين الملفات...';
    });

    try {
      final outputDir = await _getOutputDir();
      final totalBytes = await inputFile.length();
      final partSize = (totalBytes / partsCount).ceil();

      final RandomAccessFile reader = await inputFile.open(mode: FileMode.read);
      int bytesReadTotal = 0;

      for (int i = 0; i < partsCount; i++) {
        final partPath = '${outputDir.path}/$_selectedFileName.part${i + 1}';
        final partFile = File(partPath);
        final RandomAccessFile writer = await partFile.open(mode: FileMode.write);

        int bytesWrittenForPart = 0;
        final bufferSize = 2 * 1024 * 1024; // 2MB Buffer

        while (bytesWrittenForPart < partSize && bytesReadTotal < totalBytes) {
          int remainingForPart = partSize - bytesWrittenForPart;
          int remainingForTotal = totalBytes - bytesReadTotal;
          int toRead = remainingForPart < remainingForTotal ? remainingForPart : remainingForTotal;
          if (toRead > bufferSize) toRead = bufferSize;

          List<int> buffer = await reader.read(toRead);
          if (buffer.isEmpty) break;

          await writer.writeFrom(buffer);
          bytesWrittenForPart += buffer.length;
          bytesReadTotal += buffer.length;

          setState(() {
            _progress = bytesReadTotal / totalBytes;
          });
        }
        await writer.close();
      }
      await reader.close();

      setState(() {
        _statusMessage = 'تم الحفظ بنجاح في مجلد PS4_PKG_Tools!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ أثناء التقسيم: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_outlined),
              label: const Text('اختيار ملف PKG من الذاكرة'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFileName.isEmpty ? 'لم يتم اختيار ملف' : _selectedFileName,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),

          TextField(
            controller: _partsController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'عدد الأجزاء',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<String>(
                value: _selectedSpeed,
                dropdownColor: const Color(0xFF1E1E24),
                underline: Container(height: 1, color: Colors.grey),
                items: _speedOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSpeed = val);
                },
              ),
              const SizedBox(width: 10),
              const Text('تحديد السرعة: ', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),

          if (_isProcessing)
            LinearProgressIndicator(value: _progress, color: const Color(0xFF6C5CE7)),

          const SizedBox(height: 10),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const Spacer(),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: _isProcessing ? null : _startSplit,
              child: const Text('بدء التقسيم', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
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
  final TextEditingController _pathController =
      TextEditingController(text: '/storage/emulated/0/Download/PS4_PKG_Tools/game.pkg');
  String _status = 'جاهز لدمج الأجزاء';
  bool _isProcessing = false;

  Future<void> _startMerge() async {
    final basePath = _pathController.text.trim();
    if (basePath.isEmpty) {
      setState(() => _status = 'يرجى كتابة أو تحديد مسار الملف الأساسي');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'جاري البحث عن الأجزاء ودمجها...';
    });

    try {
      final outputFile = File('${basePath}_merged.pkg');
      final RandomAccessFile writer = await outputFile.open(mode: FileMode.write);
      int mergedCount = 0;

      for (int i = 1; i <= 100; i++) {
        File partFile = File('$basePath.part$i');
        if (!await partFile.exists()) break;

        final RandomAccessFile reader = await partFile.open(mode: FileMode.read);
        final bufferSize = 2 * 1024 * 1024;
        int length = await partFile.length();
        int readBytes = 0;

        while (readBytes < length) {
          int toRead = (length - readBytes) > bufferSize ? bufferSize : (length - readBytes);
          List<int> buffer = await reader.read(toRead);
          if (buffer.isEmpty) break;
          await writer.writeFrom(buffer);
          readBytes += buffer.length;
        }

        await reader.close();
        mergedCount++;
      }

      await writer.close();

      setState(() {
        _status = mergedCount > 0
            ? 'تم الدمج بنجاح في مجلد PS4_PKG_Tools!'
            : 'لم يتم العثور على أجزاء مجاورة بهذه التسمية!';
      });
    } catch (e) {
      setState(() => _status = 'خطأ أثناء الدمج: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pathController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'مسار الملف الأساسي',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _isProcessing ? null : _startMerge,
              child: const Text('بدء الدمج'),
            ),
          ),
        ],
      ),
    );
  }
}

class SendPs4Tab extends StatefulWidget {
  const SendPs4Tab({super.key});

  @override
  State<SendPs4Tab> createState() => _SendPs4TabState();
}

class _SendPs4TabState extends State<SendPs4Tab> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.50');
  final TextEditingController _fileController =
      TextEditingController(text: '/storage/emulated/0/Download/PS4_PKG_Tools/game.pkg');
  String _status = 'جاهز للإرسال إلى PS4';
  bool _isProcessing = false;

  Future<void> _sendToPs4() async {
    final ip = _ipController.text.trim();
    final filePath = _fileController.text.trim();

    setState(() {
      _isProcessing = true;
      _status = 'جاري الإرسال إلى $ip...';
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse('http://$ip:12800/api/install'));
      request.headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        "type": "direct",
        "packages": [Uri.file(filePath).toString()]
      });

      request.write(payload);
      final response = await request.close();

      setState(() {
        _status = response.statusCode == 200
            ? 'تم إرسال حزمة التثبيت إلى PS4 بنجاح!'
            : 'استجاب الجهاز برمز: ${response.statusCode}';
      });
      client.close();
    } catch (e) {
      setState(() => _status = 'فشل الاتصال بـ PS4: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.datetime,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'عنوان IP الخاص بـ PS4',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _fileController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'مسار ملف الـ PKG',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _isProcessing ? null : _sendToPs4,
              child: const Text('إرسال إلى PS4'),
            ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# رفع التغييرات تلقائياً إلى GitHub وإنشاء الإصدار v2.4.0
git add .
git commit -m "Set output directory to PS4_PKG_Tools and add settings icon"
git push origin main

TAG_NAME="v2.4.0"
git tag -f $TAG_NAME
git push origin $TAG_NAME --force

