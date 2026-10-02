import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const PS4PKGToolApp());
}

class PS4PKGToolApp extends StatelessWidget {
  const PS4PKGToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 PKG Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const PKGToolHomeScreen(),
    );
  }
}

class PKGToolHomeScreen extends StatefulWidget {
  const PKGToolHomeScreen({super.key});

  @override
  State<PKGToolHomeScreen> createState() => _PKGToolHomeScreenState();
}

class _PKGToolHomeScreenState extends State<PKGToolHomeScreen> {
  final TextEditingController _pathController = TextEditingController();
  String _statusMessage = '';
  String _cusaCode = '';
  bool _isVerified = false;
  bool _isProcessing = false;

  // 1. اختيار الملف بواسطة واجهة النظام
  Future<void> _pickPKGFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        _pathController.text = path;
        _verifyAndExtractInfo(path);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error selecting file: $e';
        _isVerified = false;
        _cusaCode = '';
      });
    }
  }

  // 2. فحص سلامة الملف واستخراج رمز CUSA وحجمه
  void _verifyAndExtractInfo(String path) {
    if (path.isEmpty) {
      setState(() {
        _statusMessage = '';
        _cusaCode = '';
        _isVerified = false;
      });
      return;
    }

    File file = File(path);
    if (file.existsSync()) {
      int sizeBytes = file.lengthSync();
      double sizeGB = sizeBytes / (1024 * 1024 * 1024);
      String sizeStr = sizeGB >= 1 
          ? '${sizeGB.toStringAsFixed(2)} GB' 
          : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

      // استخراج رمز CUSA من اسم الملف
      RegExp cusaRegex = RegExp(r'CUSA\d{5}', caseSensitive: false);
      Match? match = cusaRegex.firstMatch(path);
      String extractedCusa = match != null ? match.group(0)!.toUpperCase() : 'Unknown Game ID';

      setState(() {
        _isVerified = true;
        _cusaCode = extractedCusa;
        _statusMessage = 'File Verified Successfully ✓ ($sizeStr)';
      });
    } else {
      setState(() {
        _isVerified = false;
        _cusaCode = '';
        _statusMessage = 'Error: File does not exist!';
      });
    }
  }

  // 3. عملية تقسيم الملف إلى أجزاء 4GB
  Future<void> _splitPKG() async {
    String path = _pathController.text.trim();
    if (path.isEmpty || !_isVerified) {
      setState(() => _statusMessage = 'Error: Select a valid PKG file first!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Splitting PKG file into 4GB parts...';
    });

    try {
      ProcessResult result = await Process.run('split', ['-b', '4000M', '-d', path, '$path.part']);
      setState(() {
        _isProcessing = false;
        _statusMessage = result.exitCode == 0 ? 'Split Completed Successfully! ✓' : 'Split Failed!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Split Process Triggered.';
      });
    }
  }

  // 4. عملية دمج أجزاء PKG
  Future<void> _mergePKG() async {
    String path = _pathController.text.trim();
    if (path.isEmpty || !_isVerified) {
      setState(() => _statusMessage = 'Error: Select a valid file part first!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Merging PKG parts...';
    });

    try {
      String basePrefix = path.contains('.part') 
          ? path.split('.part')[0] 
          : path.split('.')[0];

      ProcessResult result = await Process.run('sh', ['-c', 'cat $basePrefix.part* > ${basePrefix}_merged.pkg']);
      
      setState(() {
        _isProcessing = false;
        _statusMessage = result.exitCode == 0 ? 'Merge Completed Successfully! ✓' : 'Merge Failed!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Merge Process Triggered.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'PS4 PKG Tool',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),
              
              // حقل الإدخال مع أيقونة المجلد
              TextField(
                controller: _pathController,
                onChanged: _verifyAndExtractInfo,
                decoration: InputDecoration(
                  hintText: 'Enter PKG or Part file path...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open, color: Colors.grey),
                    onPressed: _pickPKGFile,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // زر Split PKG
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _splitPKG,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                  ),
                  child: const Text(
                    'Split PKG',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // زر Merge PKG Parts
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _mergePKG,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                  ),
                  child: const Text(
                    'Merge PKG Parts',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const Spacer(),

              // عرض كود اللعبة CUSA
              if (_cusaCode.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    'Game ID: $_cusaCode',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.lightBlueAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // حالة سلامة الملف
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
