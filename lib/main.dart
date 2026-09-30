import 'dart:io';
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
      title: 'PS4 PKG Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const PS4ToolsDashboard(),
    );
  }
}

class PS4ToolsDashboard extends StatefulWidget {
  const PS4ToolsDashboard({super.key});

  @override
  State<PS4ToolsDashboard> createState() => _PS4ToolsDashboardState();
}

class _PS4ToolsDashboardState extends State<PS4ToolsDashboard> {
  String _statusLog = 'جاهز لعمليات PS4 PKG';
  bool _isProcessing = false;

  // 1. وظيفة تقسيم ملف PKG إلى أجزاء (Split)
  Future<void> _splitPkgFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    setState(() {
      _isProcessing = true;
      _statusLog = 'جاري تقسيم ملف PKG...';
    });

    try {
      final int chunkSize = 4 * 1024 * 1024 * 1024; // 4 جيجابايت للجزء الواحد
      final inputStream = file.openRead();
      int partIndex = 0;
      int bytesWritten = 0;
      IOSink? currentSink;

      await for (var chunk in inputStream) {
        if (currentSink == null || bytesWritten >= chunkSize) {
          await currentSink?.flush();
          await currentSink?.close();
          currentSink = File('${file.path}.part$partIndex').openWrite();
          partIndex++;
          bytesWritten = 0;
        }
        currentSink.add(chunk);
        bytesWritten += chunk.length;
      }
      await currentSink?.flush();
      await currentSink?.close();

      setState(() => _statusLog = 'تم تقسيم الملف بنجاح إلى $partIndex أجزاء!');
    } catch (e) {
      setState(() => _statusLog = 'خطأ في التقسيم: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 2. وظيفة دمج الأجزاء (Merge .part0, .part1...)
  Future<void> _mergePkgFiles(String basePath) async {
    setState(() {
      _isProcessing = true;
      _statusLog = 'جاري دمج أجزاء PKG...';
    });

    try {
      final outputFile = File('${basePath}_merged.pkg');
      final outputSink = outputFile.openWrite();

      int partIndex = 0;
      while (true) {
        final partFile = File('$basePath.part$partIndex');
        if (!await partFile.exists()) break;

        await outputSink.addStream(partFile.openRead());
        partIndex++;
      }

      await outputSink.flush();
      await outputSink.close();

      setState(() => _statusLog = 'تم دمج $partIndex أجزاء بنجاح في ملف واحد!');
    } catch (e) {
      setState(() => _statusLog = 'خطأ في الدمج: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 3. وظيفة إرسال الملف إلى PS4 عبر الشبكة (Remote Installer API)
  Future<void> _sendToPS4(String ipAddress, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      setState(() => _statusLog = 'الملف غير موجود للإرسال');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusLog = 'جاري إرسال اللعبة إلى PS4 عبر IP: $ipAddress...';
    });

    try {
      // محاكاة بروتوكول إرسال حزم التثبيت المباشر لـ GoldHEN / Direct Package Installer
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('http://$ipAddress:12800/api/install'));
      request.headers.set('Content-Type', 'application/json');
      
      // إرسال رابط أو مسار اللعبة كطلب تثبيت مباشر
      request.write('{"type": "direct", "url": "${file.uri}"}');
      final response = await request.close();

      if (response.statusCode == 200) {
        setState(() => _statusLog = 'تم إرسال أمر التثبيت إلى PS4 بنجاح!');
      } else {
        setState(() => _statusLog = 'فشل الاستجابة من PS4 (رمز: ${response.statusCode})');
      }
      client.close();
    } catch (e) {
      setState(() => _statusLog = 'خطأ في الاتصال بالـ PS4: $e (تأكد من الـ IP وتفعيل GoldHEN)');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أدوات PS4 PKG Studio الفعالة'),
        backgroundColor: Colors.deepPurple.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple),
              ),
              child: Text(
                'حالة العمليات: $_statusLog',
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            if (_isProcessing) const LinearProgressIndicator(color: Colors.amber),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.call_split),
              label: const Text('تقسيم ملف PKG (Split)', style: TextStyle(fontSize: 16)),
              onPressed: _isProcessing ? null : () => _splitPkgFile('/storage/emulated/0/Download/game.pkg'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.merge_type),
              label: const Text('دمج أجزاء PKG (Merge)', style: TextStyle(fontSize: 16)),
              onPressed: _isProcessing ? null : () => _mergePkgFiles('/storage/emulated/0/Download/game.pkg'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.send_to_mobile),
              label: const Text('إرسال إلى PS4 عبر الشبكة (GoldHEN)', style: TextStyle(fontSize: 16)),
              onPressed: _isProcessing ? null : () => _sendToPS4('192.168.1.50', '/storage/emulated/0/Download/game.pkg'),
            ),
          ],
        ),
      ),
    );
  }
}
