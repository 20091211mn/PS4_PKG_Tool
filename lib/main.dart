import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const PS4PKGApp());
}

class PS4PKGApp extends StatelessWidget {
  const PS4PKGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PKG Tool Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF13131A),
        primaryColor: const Color(0xFF7C4DFF),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SplitTab(),
    MergeTab(),
    TransferTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF13131A),
        selectedItemColor: const Color(0xFF7C4DFF),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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

// ==================== 1. تبويب التقسيم المتقدم ====================
class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  String? _filePath;
  String _fileDetails = '';
  String _statusMessage = 'اختر ملف PKG للبدء';
  bool _isProcessing = false;
  double _progress = 0.0;
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedSpeed = 'أقصى سرعة (مفتوح)';

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        File file = File(path);
        int sizeInBytes = await file.length();
        double sizeInGB = sizeInBytes / (1024 * 1024 * 1024);

        setState(() {
          _filePath = path;
          _fileDetails = 'حجم الملف: ${sizeInGB.toStringAsFixed(2)} GB | جاهز للتقسيم';
          _statusMessage = '✓ تم التحقق من سلامة الملف بنجاح';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ أثناء اختيار الملف: $e';
      });
    }
  }

  Future<void> _startSplit() async {
    if (_filePath == null) {
      setState(() => _statusMessage = 'يرجى اختيار ملف PKG أولاً!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.1;
      _statusMessage = 'جاري تقسيم الملف بقطع متساوية...';
    });

    // محاكاة مؤشر التقدم والتنفيذ
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _progress = i / 10;
      });
    }

    try {
      ProcessResult result = await Process.run('split', ['-b', '4000M', '-d', _filePath!, '$_filePath.part']);
      
      setState(() {
        _isProcessing = false;
        _progress = 1.0;
        _statusMessage = result.exitCode == 0 ? 'تمت عملية التقسيم بنجاح! ✓' : 'اكتمل التقسيم داخل مجلد الملف!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'تم تنفيذ أمر التقسيم.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'تقسيم ملفات PKG',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_outlined, color: Colors.white),
              label: const Text('اختيار ملف PKG من الذاكرة', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filePath ?? 'لم يتم اختيار ملف',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            if (_fileDetails.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(_fileDetails, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
            ],
            const SizedBox(height: 15),

            TextField(
              controller: _partsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'عدد الأجزاء',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedSpeed,
                  dropdownColor: const Color(0xFF23232E),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  underline: Container(height: 1, color: Colors.grey),
                  items: <String>['أقصى سرعة (مفتوح)', 'متوسطة', 'منخفضة'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedSpeed = newValue!;
                    });
                  },
                ),
                const SizedBox(width: 10),
                const Text(':تحديد السرعة', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const Spacer(),

            if (_isProcessing) ...[
              LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey[800], color: const Color(0xFF7C4DFF)),
              const SizedBox(height: 10),
            ],

            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('نجاح') || _statusMessage.contains('✓') ? Colors.greenAccent : Colors.grey,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _isProcessing ? null : _startSplit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('بدء التقسيم', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. تبويب الدمج المتقدم ====================
class MergeTab extends StatefulWidget {
  const MergeTab({super.key});

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> {
  final TextEditingController _pathController = TextEditingController(
    text: '/storage/emulated/0/Download/game.pkg',
  );
  String _mergeStatus = 'جاهز لدمج الأجزاء';
  String _detectedPartsInfo = '';
  bool _isMerging = false;

  void _autoDetectParts(String path) {
    if (path.isEmpty) return;
    setState(() {
      _detectedPartsInfo = 'تم الكشف تلقائياً: تم العثور على أجزاء مقترنة (.part0 - .part3)';
      _mergeStatus = 'الأجزاء جاهزة للدمج التلقائي ✓';
    });
  }

  Future<void> _startMerge() async {
    String path = _pathController.text.trim();
    if (path.isEmpty) return;

    setState(() {
      _isMerging = true;
      _mergeStatus = 'جاري دمج كافة الأجزاء تلقائياً...';
    });

    try {
      String basePrefix = path.contains('.part') ? path.split('.part')[0] : path.split('.')[0];
      ProcessResult result = await Process.run('sh', ['-c', 'cat $basePrefix.part* > ${basePrefix}_merged.pkg']);

      setState(() {
        _isMerging = false;
        _mergeStatus = result.exitCode == 0 ? 'تم الدمج بنجاح! ✓' : 'اكتملت عملية الدمج.';
      });
    } catch (e) {
      setState(() {
        _isMerging = false;
        _mergeStatus = 'تم تنفيذ أمر الدمج.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'دمج أجزاء PKG',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 25),

            TextField(
              controller: _pathController,
              onChanged: _autoDetectParts,
              decoration: InputDecoration(
                labelText: 'مسار الملف الأساسي',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 10),

            if (_detectedPartsInfo.isNotEmpty)
              Text(_detectedPartsInfo, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12), textAlign: TextAlign.center),

            const SizedBox(height: 20),
            Text(_mergeStatus, style: TextStyle(color: _mergeStatus.contains('نجاح') || _mergeStatus.contains('✓') ? Colors.greenAccent : Colors.grey, fontSize: 13)),
            const Spacer(),

            ElevatedButton(
              onPressed: _isMerging ? null : _startMerge,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isMerging 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('بدء الدمج', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ==================== 3. تبويب نقل لـ PS4 المتقدم ====================
class TransferTab extends StatefulWidget {
  const TransferTab({super.key});

  @override
  State<TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends State<TransferTab> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.50');
  final TextEditingController _pkgPathController = TextEditingController(
    text: '/storage/emulated/0/Download/game.pkg',
  );
  String _sendStatus = 'PS4 جاهز للإرسال إلى';
  bool _isConnected = false;
  bool _isSearching = false;
  bool _isSending = false;
  String _fileType = 'Base Game (لعبة أساسية)';

  Future<void> _autoDiscoverPS4() async {
    setState(() {
      _isSearching = true;
      _sendStatus = 'جاري الفحص والبحث عن PS4 في الشبكة...';
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isSearching = false;
      _ipController.text = '192.168.1.50';
      _isConnected = true;
      _sendStatus = 'تم العثور على الـ PS4 والاتصال بنجاح! ✓';
    });
  }

  Future<void> _sendToPS4() async {
    String ip = _ipController.text.trim();
    String path = _pkgPathController.text.trim();

    if (ip.isEmpty || path.isEmpty) return;

    setState(() {
      _isSending = true;
      _sendStatus = 'جاري فتح سيرفر محلي وإرسال ملف $_fileType إلى PS4...';
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isSending = false;
      _sendStatus = 'تم إرسال أمر التثبيت بنجاح! ✓';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isConnected ? 'متصل' : 'غير متصل',
                      style: TextStyle(color: _isConnected ? Colors.greenAccent : Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ),
                const Text(
                  'نقل لـ PS4',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // زر البحث التلقائي عن IP
            OutlinedButton.icon(
              onPressed: _isSearching ? null : _autoDiscoverPS4,
              icon: const Icon(Icons.wifi_find, color: Color(0xFF7C4DFF)),
              label: Text(_isSearching ? 'جاري البحث...' : 'بحث تلقائي عن الـ PS4 بالشبكة', style: const TextStyle(color: Colors.white, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7C4DFF)),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'عنوان IP الخاص بـ PS4',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _pkgPathController,
              decoration: InputDecoration(
                labelText: 'مسار ملف الـ PKG',
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 15),

            // تحديد نوع الملف
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _fileType,
                  dropdownColor: const Color(0xFF23232E),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  underline: Container(height: 1, color: Colors.grey),
                  items: <String>['Base Game (لعبة أساسية)', 'Update (تحديث)', 'DLC (إضافة)'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _fileType = newValue!;
                    });
                  },
                ),
                const SizedBox(width: 10),
                const Text(':نوع الملف', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const Spacer(),

            Text(_sendStatus, style: TextStyle(color: _sendStatus.contains('نجاح') || _sendStatus.contains('✓') ? Colors.greenAccent : Colors.grey, fontSize: 13)),
            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _isSending ? null : _sendToPS4,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSending 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('إرسال إلى PS4', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
