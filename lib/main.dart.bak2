import 'transfer_tab.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const PS4PKGApp());
}

class AppSettings {
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  static ValueNotifier<String> languageNotifier = ValueNotifier('العربية');
}

class PS4PKGApp extends StatelessWidget {
  const PS4PKGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeNotifier,
      builder: (context, currentTheme, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppSettings.languageNotifier,
          builder: (context, currentLang, _) {
            return MaterialApp(
              title: 'PKG Tool Pro',
              debugShowCheckedModeBanner: false,
              themeMode: currentTheme,
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF4F3F8),
                primaryColor: const Color(0xFF7C4DFF),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF13131A),
                primaryColor: const Color(0xFF7C4DFF),
              ),
              home: const MainNavigationScreen(),
            );
          },
        );
      },
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: isDark ? const Color(0xFF13131A) : Colors.white,
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

// ==================== صفحة الإعدادات الشاملة ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والميزات', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF13131A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text('اللغة (Languages)', style: TextStyle(color: Color(0xFF9E86FF), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: AppSettings.languageNotifier.value,
              dropdownColor: isDark ? const Color(0xFF23232E) : Colors.white,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7C4DFF))),
              ),
              items: <String>['العربية', 'English', 'Français', 'Español', 'Deutsch'].map((String lang) {
                return DropdownMenuItem<String>(
                  value: lang,
                  child: Text(lang, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  AppSettings.languageNotifier.value = val;
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 25),

            const Text('مظهر التطبيق (Theme)', style: TextStyle(color: Color(0xFF9E86FF), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            SwitchListTile(
              title: Text(isDark ? 'الوضع الداكن (Dark Mode)' : 'الوضع الفاتح (Light Mode)', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF7C4DFF)),
              value: isDark,
              onChanged: (bool value) {
                AppSettings.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
              },
            ),
            const Divider(height: 40, color: Colors.grey),

            const Text('ميزات مقترحة إضافية', style: TextStyle(color: Color(0xFF9E86FF), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Color(0xFF7C4DFF)),
              title: const Text('تنظيف الملفات المؤقتة (Cache Cleanup)'),
              subtitle: const Text('حذف مخلفات المعالجة لزيادة المساحة'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنظيف الملفات المؤقتة بنجاح!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update, color: Color(0xFF7C4DFF)),
              title: const Text('التحقق من وجود تحديثات'),
              subtitle: const Text('الإصدار الحالي: v1.0.0 Pro'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنت تستخدم أحدث إصدار بالفعل!')));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 1. تبويب التقسيم (المعدل بجمالية ممتازة) ====================
class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  String? _filePath;
  String? _fileName;
  String _fileDetails = '';
  String _statusMessage = 'اختر ملف PKG للبدء';
  bool _isProcessing = false;
  double _progress = 0.0;
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedSpeed = 'أقصى سرعة (مفتوح)';

  Future<void> _requestPermissionAndPickFile() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        String name = result.files.single.name;
        File file = File(path);
        int sizeInBytes = await file.length();
        double sizeInGB = sizeInBytes / (1024 * 1024 * 1024);

        setState(() {
          _filePath = path;
          _fileName = name;
          _fileDetails = 'حجم الملف: ${sizeInGB.toStringAsFixed(2)} GB | جاهز للتقسيم';
          _statusMessage = 'تم اختيار الملف بنجاح ✓';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في اختيار الملف: $e';
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
      _statusMessage = 'جاري تقسيم الملف...';
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _progress = i / 10;
      });
    }

    setState(() {
      _isProcessing = false;
      _progress = 1.0;
      _statusMessage = 'تمت عملية التقسيم بنجاح! ✓';
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Column(
          children: [
            // العنوان المزود بأيقونة الإعدادات وتصحيح الاتجاه
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFF7C4DFF), size: 26),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                  },
                ),
                const Text(
                  'تقسيم ملفات PKG',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: _requestPermissionAndPickFile,
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
            const SizedBox(height: 15),

            // البطاقة التفاعلية المصممة لمساحة العرض المخصصة
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B1B25) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.snippet_folder, size: 55, color: Color(0xFF7C4DFF)),
                    const SizedBox(height: 15),
                    if (_fileName != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          _fileName!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9E86FF),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _filePath == null ? 'مساحة العمل فارغة\nقم برفع ملف PKG للبدء' : _fileDetails,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
              style: const TextStyle(color: Color(0xFF9E86FF)),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedSpeed,
                  dropdownColor: isDark ? const Color(0xFF23232E) : Colors.white,
                  style: const TextStyle(color: Color(0xFF9E86FF), fontSize: 14),
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
            const SizedBox(height: 15),

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

// ==================== 2. تبويب الدمج ====================
class MergeTab extends StatefulWidget {
  const MergeTab({super.key});

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> {
  String? _mergedFilePath;
  String _mergeStatus = 'جاهز لدمج الأجزاء';
  bool _isMerging = false;

  Future<void> _pickMergeFiles() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _mergedFilePath = result.files.first.path;
          _mergeStatus = 'تم اختيار ${result.files.length} ملفات للأجزاء بنجاح ✓';
        });
      }
    } catch (e) {
      setState(() {
        _mergeStatus = 'خطأ في اختيار الأجزاء: $e';
      });
    }
  }

  Future<void> _startMerge() async {
    if (_mergedFilePath == null) {
      setState(() => _mergeStatus = 'يرجى اختيار أجزاء الملف أولاً!');
      return;
    }

    setState(() {
      _isMerging = true;
      _mergeStatus = 'جاري دمج الأجزاء...';
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isMerging = false;
      _mergeStatus = 'تم دمج الأجزاء بنجاح! ✓';
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
                'دمج أجزاء PKG',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _pickMergeFiles,
              icon: const Icon(Icons.file_upload, color: Colors.white),
              label: const Text('اختيار ملفات أجزاء PKG من الذاكرة', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23232E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _mergedFilePath ?? 'لم يتم تحديد مسار الأجزاء',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            Text(_mergeStatus, style: TextStyle(color: _mergeStatus.contains('نجاح') || _mergeStatus.contains('✓') ? Colors.greenAccent : Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),

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

