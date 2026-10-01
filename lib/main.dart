import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PS4PkgStudioApp());
}

class PS4PkgStudioApp extends StatelessWidget {
  const PS4PkgStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تقسيم ملفات PKG',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

// ----------------------------------------------------
// 1. تبويب التقسيم (طابق الصورة المرفقة)
// ----------------------------------------------------
class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedFilePath = '';
  String _selectedSpeed = 'أقصى سرعة (مفتوح)';
  String _statusMessage = 'للبدء اختر ملف PKG';
  bool _isProcessing = false;
  double _progress = 0.0;

  final List<String> _speedOptions = [
    'أقصى سرعة (مفتوح)',
    'متوسطة (50 MB/s)',
    'منخفضة (10 MB/s)',
  ];

  Future<void> _pickFile() async {
    if (Platform.isAndroid) {
      await [Permission.storage, Permission.manageExternalStorage].request();
    }
    // مسار افتراضي للتجربة على الأندرويد
    setState(() {
      _selectedFilePath = '/storage/emulated/0/Download/game.pkg';
      _statusMessage = 'تم اختيار الملف جاهز للتقسيم';
    });
  }

  Future<void> _startSplit() async {
    if (_selectedFilePath.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى اختيار ملف PKG أولاً!';
      });
      return;
    }

    final file = File(_selectedFilePath);
    if (!await file.exists()) {
      setState(() {
        _statusMessage = 'الملف المحدد غير موجود في الذاكرة';
      });
      return;
    }

    final partsCount = int.tryParse(_partsController.text.trim()) ?? 4;
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'جاري تقسيم الملف إلى $partsCount أجزاء...';
    });

    try {
      final totalBytes = await file.length();
      final chunkSize = (totalBytes / partsCount).ceil();

      final inputStream = file.openRead();
      int partIndex = 0;
      int bytesWrittenCurrentPart = 0;
      int totalBytesRead = 0;

      IOSink? currentSink;

      await for (List<int> chunk in inputStream) {
        if (currentSink == null || bytesWrittenCurrentPart >= chunkSize) {
          if (currentSink != null) {
            await currentSink.flush();
            await currentSink.close();
          }
          final partPath = '$_selectedFilePath.part$partIndex';
          currentSink = File(partPath).openWrite();
          partIndex++;
          bytesWrittenCurrentPart = 0;
        }

        currentSink.add(chunk);
        bytesWrittenCurrentPart += chunk.length;
        totalBytesRead += chunk.length;

        setState(() {
          _progress = totalBytesRead / totalBytes;
        });
      }

      if (currentSink != null) {
        await currentSink.flush();
        await currentSink.close();
      }

      setState(() {
        _statusMessage = 'تم تقسيم الملف بنجاح إلى $partIndex أجزاء!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء التقسيم: $e';
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تقسيم ملفات PKG',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 25),

          // زر اختيار ملف من الذاكرة
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
            _selectedFilePath.isEmpty ? 'لم يتم اختيار ملف' : _selectedFilePath,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),

          // حقل عدد الأجزاء
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

          // تحديد السرعة
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

          // شريط التقدم إن وجد
          if (_isProcessing)
            LinearProgressIndicator(value: _progress, color: const Color(0xFF6C5CE7)),

          const SizedBox(height: 10),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const Spacer(),

          // زر بدء التقسيم العريض السفلي
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

// ----------------------------------------------------
// 2. تبويب الدمج
// ----------------------------------------------------
class MergeTab extends StatefulWidget {
  const MergeTab({super.key});

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> {
  final TextEditingController _pathController =
      TextEditingController(text: '/storage/emulated/0/Download/game.pkg');
  String _status = 'جاهز لدمج الأجزاء';
  bool _isProcessing = false;

  Future<void> _startMerge() async {
    final basePath = _pathController.text.trim();
    setState(() {
      _isProcessing = true;
      _status = 'جاري الدمج...';
    });

    try {
      final outputFile = File('${basePath}_merged.pkg');
      final outputSink = outputFile.openWrite();
      int index = 0;

      while (true) {
        final partFile = File('$basePath.part$index');
        if (!await partFile.exists()) break;

        await outputSink.addStream(partFile.openRead());
        index++;
      }

      await outputSink.flush();
      await outputSink.close();

      setState(() {
        _status = index > 0 ? 'تم دمج $index جزءاً بنجاح!' : 'لم يتم العثور على أجزاء للدمج.';
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
          const Text('دمج أجزاء PKG',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right),
          const SizedBox(height: 20),
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

// ----------------------------------------------------
// 3. تبويب الإرسال إلى PS4
// ----------------------------------------------------
class SendPs4Tab extends StatefulWidget {
  const SendPs4Tab({super.key});

  @override
  State<SendPs4Tab> createState() => _SendPs4TabState();
}

class _SendPs4TabState extends State<SendPs4Tab> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.50');
  final TextEditingController _fileController =
      TextEditingController(text: '/storage/emulated/0/Download/game.pkg');
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
          const Text('نقل لـ PS4',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right),
          const SizedBox(height: 20),
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
