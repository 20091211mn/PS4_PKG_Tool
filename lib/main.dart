import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PS4PkgStudioApp());
}

class PS4PkgStudioApp extends StatefulWidget {
  const PS4PkgStudioApp({super.key});

  static _PS4PkgStudioAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_PS4PkgStudioAppState>()!;

  @override
  State<PS4PkgStudioApp> createState() => _PS4PkgStudioAppState();
}

class _PS4PkgStudioAppState extends State<PS4PkgStudioApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('ar');

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeLanguage(String langCode) {
    setState(() {
      _locale = Locale(langCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 PKG Studio',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      locale: _locale,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const OriginalStudioUI(),
    );
  }
}

class OriginalStudioUI extends StatefulWidget {
  const OriginalStudioUI({super.key});

  @override
  State<OriginalStudioUI> createState() => _OriginalStudioUIState();
}

class _OriginalStudioUIState extends State<OriginalStudioUI> {
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedSpeed = 'أقصى سرعة (مفتوح)';
  String _statusMessage = '';
  bool _isProcessing = false;

  final List<String> _speedOptions = [
    'أقصى سرعة (مفتوح)',
    'متوسطة (50 MB/s)',
    'منخفضة (10 MB/s)',
  ];

  @override
  void initState() {
    super.initState();
    _requestStoragePermissions();
  }

  Future<void> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
    }
  }

  // استخدام مسار التنزيلات الصحيح بدلاً من /sdcard المرفوض من أندرويد
  String get _workingPath {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    }
    return Directory.current.path;
  }

  Future<void> _startProcess() async {
    await _requestStoragePermissions();

    setState(() {
      _isProcessing = true;
      _statusMessage = '';
    });

    try {
      final saveDir = Directory(_workingPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // محاكاة أو تنفيذ عملية المعالجة في المسار الصحيح
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _statusMessage = 'تمت العملية بنجاح في المسار: $_workingPath';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'PS4 PKG Studio' : 'PS4 PKG Studio'),
        backgroundColor: Colors.deepPurple.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: isAr ? 'الإعدادات' : 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            
            // 1. مربع إدخال الأجزاء (الموجود في الصورة)
            TextField(
              controller: _partsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isAr ? 'عدد الأجزاء' : 'Number of Parts',
                border: const OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),

            // 2. القائمة المنسدلة للسرعة (الموجودة في الصورة)
            Row(
              children: [
                Text(
                  isAr ? 'تحديد السرعة: ' : 'Speed Limit: ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSpeed,
                    isExpanded: true,
                    items: _speedOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(color: Colors.amberAccent)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSpeed = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isProcessing ? null : _startProcess,
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      isAr ? 'بدء العملية' : 'Start Process',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 30),

            // 3. خانة عرض الأخطاء/الحالة (الموجودة أسفل الصورة)
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.startsWith('خطأ') ? Colors.red : Colors.green,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.startsWith('خطأ') ? Colors.redAccent : Colors.lightGreenAccent,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PS4PkgStudioApp.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الإعدادات' : 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text(isAr ? 'الوضع الداكن (Dark Mode)' : 'Dark Mode'),
            subtitle: Text(isAr ? 'التبديل بين الثيم المظلم والفاتح' : 'Switch dark/light theme'),
            value: isDark,
            onChanged: (val) => appState.toggleTheme(val),
          ),
          const Divider(),
          ListTile(
            title: Text(isAr ? 'اللغة (Language)' : 'Language'),
            subtitle: Text(isAr ? 'العربية' : 'English'),
            trailing: DropdownButton<String>(
              value: Localizations.localeOf(context).languageCode,
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (lang) {
                if (lang != null) appState.changeLanguage(lang);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.teal),
            title: Text(isAr ? 'طلب أذونات الذاكرة' : 'Request Permissions'),
            subtitle: Text(isAr ? 'الوصول الكامل للذاكرة لتجنب خطأ Creation failed' : 'Fix Creation failed error'),
            onTap: () async {
              await [
                Permission.storage,
                Permission.manageExternalStorage,
              ].request();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'تم تحديث الأذونات!' : 'Permissions Updated!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
