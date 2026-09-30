import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const PKGStudioApp());
}

class PKGStudioApp extends StatelessWidget {
  const PKGStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const PKGSplitterScreen(),
    );
  }
}

class PKGSplitterScreen extends StatefulWidget {
  const PKGSplitterScreen({super.key});

  @override
  State<PKGSplitterScreen> createState() => _PKGSplitterScreenState();
}

class _PKGSplitterScreenState extends State<PKGSplitterScreen> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _partsController = TextEditingController(text: "4");
  double _progress = 0.0;
  String _status = "في انتظار البدء...";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
  }

  Future<void> _askPermissions() async {
    await Permission.notification.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> _splitFile() async {
    final filePath = _pathController.text.trim();
    final partsCount = int.tryParse(_partsController.text) ?? 4;

    if (!await Permission.manageExternalStorage.isGranted) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        setState(() => _status = "خطأ: يلزم تفعيل إذن الوصول الشامل للتخزين!");
        return;
      }
    }

    final file = File(filePath);
    if (!await file.exists()) {
      setState(() => _status = "خطأ: الملف غير موجود في هذا المسار!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = "جاري تحضير التقسيم المباشر...";
      _progress = 0.0;
    });

    try {
      final totalSize = await file.length();
      final partSize = totalSize ~/ partsCount;

      final outputDir = Directory('/sdcard/Download/PS4_PKG_Tools');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final baseName = file.uri.pathSegments.last.replaceAll('.pkg', '');
      final inputStream = file.openRead();
      
      int currentPartIndex = 1;
      int bytesWrittenCurrentPart = 0;
      int totalBytesProcessed = 0;

      String getPartPath(int index) => "${outputDir.path}/${baseName}_part$index.pkg.part";

      IOSink currentPartSink = File(getPartPath(currentPartIndex)).openWrite();

      await for (final chunk in inputStream) {
        int chunkOffset = 0;
        
        while (chunkOffset < chunk.length) {
          int targetForCurrentPart = (currentPartIndex < partsCount)
              ? partSize
              : (totalSize - (partSize * (partsCount - 1)));

          int remainingInPart = targetForCurrentPart - bytesWrittenCurrentPart;
          int bytesToWrite = (chunk.length - chunkOffset < remainingInPart)
              ? (chunk.length - chunkOffset)
              : remainingInPart;

          currentPartSink.add(chunk.sublist(chunkOffset, chunkOffset + bytesToWrite));
          bytesWrittenCurrentPart += bytesToWrite;
          chunkOffset += bytesToWrite;
          totalBytesProcessed += bytesToWrite;

          setState(() {
            _progress = totalBytesProcessed / totalSize;
            _status = "جاري كتابة الجزء $currentPartIndex من $partsCount (${(_progress * 100).toStringAsFixed(1)}%)";
          });

          if (bytesWrittenCurrentPart >= targetForCurrentPart && currentPartIndex < partsCount) {
            await currentPartSink.flush();
            await currentPartSink.close();
            currentPartIndex++;
            bytesWrittenCurrentPart = 0;
            currentPartSink = File(getPartPath(currentPartIndex)).openWrite();
          }
        }
      }

      await currentPartSink.flush();
      await currentPartSink.close();

      setState(() {
        _status = "تم التقسيم بنجاح في مجلد Download/PS4_PKG_Tools!";
        _progress = 1.0;
      });
    } catch (e) {
      setState(() => _status = "خطأ أثناء التقطيع: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PS4 PKG Studio (Flutter Fast)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'مسار ملف PKG',
                hintText: '/sdcard/Download/game.pkg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _partsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد الأجزاء',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _splitFile,
                child: Text(_isProcessing ? 'جاري العمل...' : 'بدء التقسيم المباشر (Fast Native)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
