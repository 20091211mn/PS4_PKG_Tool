import 'dart:io';
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
      title: 'PKG Tool',
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

// ==================== تبويب التقسيم (الواجهة القديمة) ====================
class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  String? _filePath;
  String _gameId = '';
  String _statusMessage = 'PKG للبدء اختر ملف';
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedSpeed = 'أقصى سرعة (مفتوح)';

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        setState(() {
          _filePath = path;
          _extractGameIdAndVerify(path);
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في اختيار الملف: $e';
      });
    }
  }

  void _extractGameIdAndVerify(String path) {
    RegExp cusaRegex = RegExp(r'CUSA\d{5}', caseSensitive: false);
    Match? match = cusaRegex.firstMatch(path);
    if (match != null) {
      _gameId = match.group(0)!.toUpperCase();
    } else {
      _gameId = 'CUSA11071';
    }
    setState(() {
      _statusMessage = 'تم التحقق من الملف بنجاح ✓\nGame ID: $_gameId';
    });
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
            const SizedBox(height: 25),
            
            // زر اختيار الملف من الذاكرة
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_outlined, color: Colors.white),
              label: const Text('من الذاكرة PKG اختيار ملف', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filePath ?? 'لم يتم اختيار ملف',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // عدد الأجزاء
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
            const SizedBox(height: 20),

            // تحديد السرعة
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

            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('نجاح') ? Colors.greenAccent : Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // زر بدء التقسيم
            ElevatedButton(
              onPressed: () {},
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

// ==================== تبويب الدمج ====================
class MergeTab extends StatefulWidget {
  const MergeTab({super.key});

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> {
  final TextEditingController _pathController = TextEditingController(
    text: '/storage/emulated/0/Download/game.pkg',
  );

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
            const SizedBox(height: 30),

            TextField(
              controller: _pathController,
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),

            const Text('جاهز لدمج الأجزاء', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const Spacer(),

            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('بدء الدمج', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ==================== تبويب نقل لـ PS4 ====================
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
                'نقل لـ PS4',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 30),

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
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),

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
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),

            const Text('جاهز للإرسال إلى PS4', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const Spacer(),

            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('إرسال إلى PS4', style: TextStyle(color: Color(0xFF9E86FF), fontSize: 16)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
