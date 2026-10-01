#!/bin/bash

# 1. إعداد ملف build.gradle لفصل النسخة العامة عن نسخة المطور
cat << 'GRADLE_EOF' > android/app/build.gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.example.ps4_pkg_tool"
    compileSdk 34

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    flavorDimensions "app_type"

    productFlavors {
        official {
            dimension "app_type"
            applicationId "com.example.ps4_pkg_tool"
            resValue "string", "app_name", "PS4 PKG Tool"
        }
        dev {
            dimension "app_type"
            applicationId "com.example.ps4_pkg_tool.dev"
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "PS4 PKG Admin"
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
            minifyEnabled false
            shrinkResources false
        }
    }
}

flutter {
    source '../..'
}
GRADLE_EOF

# 2. كود Flutter الرئيسي المحدث (يدعم اختيار أجزاء متعددة للدمج + اللغات + المظهر بدون تغيير التصميم)
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

class PS4PkgStudioApp extends StatefulWidget {
  const PS4PkgStudioApp({super.key});

  static _PS4PkgStudioAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_PS4PkgStudioAppState>();

  @override
  State<PS4PkgStudioApp> createState() => _PS4PkgStudioAppState();
}

class _PS4PkgStudioAppState extends State<PS4PkgStudioApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  String _currentLang = 'ar';

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeLanguage(String langCode) {
    setState(() {
      _currentLang = langCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 PKG Tool',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        primaryColor: const Color(0xFF6C5CE7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFFFFFFFF),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121216),
        primaryColor: const Color(0xFF6C5CE7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121216),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFF1E1E24),
        ),
      ),
      home: MainTabScreen(
        currentLang: _currentLang,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class AppTranslations {
  static const Map<String, Map<String, String>> _data = {
    'ar': {
      'title': 'تقسيم ملفات PKG',
      'split': 'تقسيم',
      'merge': 'دمج',
      'send_ps4': 'نقل لـ PS4',
      'settings': 'الإعدادات',
      'theme_dark': 'الوضع الداكن',
      'language': 'اللغة',
      'select_file': 'اختيار ملف PKG من الذاكرة',
      'no_file': 'لم يتم اختيار ملف',
      'parts_count': 'عدد الأجزاء',
      'speed': 'تحديد السرعة:',
      'start_split': 'بدء التقسيم',
      'start_merge': 'بدء الدمج',
      'send_btn': 'إرسال إلى PS4',
      'base_path': 'مسار/اختيار الملف الأساسي',
      'ip_ps4': 'عنوان IP الخاص بـ PS4',
      'close': 'إغلاق',
      'speed_fast': 'أقصى سرعة (مفتوح)',
      'speed_med': 'متوسطة (50 MB/s)',
      'speed_low': 'منخفضة (10 MB/s)',
    },
    'en': {
      'title': 'PKG File Tool',
      'split': 'Split',
      'merge': 'Merge',
      'send_ps4': 'Send to PS4',
      'settings': 'Settings',
      'theme_dark': 'Dark Mode',
      'language': 'Language',
      'select_file': 'Select PKG File',
      'no_file': 'No file selected',
      'parts_count': 'Parts Count',
      'speed': 'Speed Limit:',
      'start_split': 'Start Split',
      'start_merge': 'Start Merge',
      'send_btn': 'Send to PS4',
      'base_path': 'Base File Path',
      'ip_ps4': 'PS4 IP Address',
      'close': 'Close',
      'speed_fast': 'Max Speed (Unlimited)',
      'speed_med': 'Medium (50 MB/s)',
      'speed_low': 'Low (10 MB/s)',
    },
    'es': {
      'title': 'Herramienta PKG',
      'split': 'Dividir',
      'merge': 'Unir',
      'send_ps4': 'Enviar a PS4',
      'settings': 'Ajustes',
      'theme_dark': 'Modo Oscuro',
      'language': 'Idioma',
      'select_file': 'Seleccionar Archivo PKG',
      'no_file': 'Ningún archivo seleccionado',
      'parts_count': 'Número de Partes',
      'speed': 'Velocidad:',
      'start_split': 'Iniciar División',
      'start_merge': 'Iniciar Unión',
      'send_btn': 'Enviar a PS4',
      'base_path': 'Ruta del Archivo Base',
      'ip_ps4': 'Dirección IP de PS4',
      'close': 'Cerrar',
      'speed_fast': 'Máxima Velocidad',
      'speed_med': 'Media (50 MB/s)',
      'speed_low': 'Baja (10 MB/s)',
    },
    'fr': {
      'title': 'Outil Fichier PKG',
      'split': 'Diviser',
      'merge': 'Fusionner',
      'send_ps4': 'Envoyer vers PS4',
      'settings': 'Paramètres',
      'theme_dark': 'Mode Sombre',
      'language': 'Langue',
      'select_file': 'Sélectionner Fichier PKG',
      'no_file': 'Aucun fichier sélectionné',
      'parts_count': 'Nombre de parties',
      'speed': 'Vitesse:',
      'start_split': 'Lancer la division',
      'start_merge': 'Lancer la fusion',
      'send_btn': 'Envoyer à la PS4',
      'base_path': 'Chemin du fichier de base',
      'ip_ps4': 'Adresse IP PS4',
      'close': 'Fermer',
      'speed_fast': 'Vitesse Max',
      'speed_med': 'Moyenne (50 MB/s)',
      'speed_low': 'Basse (10 MB/s)',
    },
  };

  static String get(String lang, String key) {
    return _data[lang]?[key] ?? _data['ar']![key] ?? key;
  }
}

class MainTabScreen extends StatefulWidget {
  final String currentLang;
  final bool isDark;

  const MainTabScreen({super.key, required this.currentLang, required this.isDark});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final appState = PS4PkgStudioApp.of(context);
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                AppTranslations.get(widget.currentLang, 'settings'),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(AppTranslations.get(widget.currentLang, 'theme_dark')),
                    value: widget.isDark,
                    onChanged: (val) {
                      appState?.toggleTheme(val);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(AppTranslations.get(widget.currentLang, 'language')),
                    trailing: DropdownButton<String>(
                      value: widget.currentLang,
                      items: const [
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                      ],
                      onChanged: (lang) {
                        if (lang != null) {
                          appState?.changeLanguage(lang);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppTranslations.get(widget.currentLang, 'close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SplitTab(lang: widget.currentLang),
      MergeTab(lang: widget.currentLang),
      SendPs4Tab(lang: widget.currentLang),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsDialog,
        ),
        title: Text(
          AppTranslations.get(widget.currentLang, 'title'),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: screens[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF9D84FF),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.call_split),
            label: AppTranslations.get(widget.currentLang, 'split'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.merge_type),
            label: AppTranslations.get(widget.currentLang, 'merge'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.send),
            label: AppTranslations.get(widget.currentLang, 'send_ps4'),
          ),
        ],
      ),
    );
  }
}

class SplitTab extends StatefulWidget {
  final String lang;
  const SplitTab({super.key, required this.lang});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  final TextEditingController _partsController = TextEditingController(text: '4');
  String _selectedFilePath = '';
  String _selectedFileName = '';
  String _selectedSpeed = 'max';
  String _statusMessage = '';
  bool _isProcessing = false;
  double _progress = 0.0;

  Future<Directory> _getOutputDir() async {
    final Directory dir = Directory('/storage/emulated/0/Download/PS4_PKG_Tools');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _pickFile() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path!;
        _selectedFileName = result.files.single.name;
        _statusMessage = 'جاهز للتقسيم';
      });
    }
  }

  Future<void> _startSplit() async {
    if (_selectedFilePath.isEmpty) return;

    final inputFile = File(_selectedFilePath);
    if (!await inputFile.exists()) return;

    final partsCount = int.tryParse(_partsController.text.trim()) ?? 4;
    if (partsCount <= 1) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'جاري التقسيم...';
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
        final bufferSize = 2 * 1024 * 1024;

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
        _statusMessage = 'تم الحفظ في /Download/PS4_PKG_Tools!';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_outlined),
              label: Text(AppTranslations.get(widget.lang, 'select_file')),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFileName.isEmpty ? AppTranslations.get(widget.lang, 'no_file') : _selectedFileName,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _partsController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: AppTranslations.get(widget.lang, 'parts_count'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(AppTranslations.get(widget.lang, 'speed'), style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedSpeed,
                items: [
                  DropdownMenuItem(value: 'max', child: Text(AppTranslations.get(widget.lang, 'speed_fast'))),
                  DropdownMenuItem(value: 'med', child: Text(AppTranslations.get(widget.lang, 'speed_med'))),
                  DropdownMenuItem(value: 'low', child: Text(AppTranslations.get(widget.lang, 'speed_low'))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSpeed = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing) LinearProgressIndicator(value: _progress, color: const Color(0xFF6C5CE7)),
          const SizedBox(height: 10),
          Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _isProcessing ? null : _startSplit,
              child: Text(AppTranslations.get(widget.lang, 'start_split'), style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class MergeTab extends StatefulWidget {
  final String lang;
  const MergeTab({super.key, required this.lang});

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> {
  final TextEditingController _pathController =
      TextEditingController(text: '/storage/emulated/0/Download/PS4_PKG_Tools/game.pkg');
  List<String> _selectedFiles = [];
  String _status = '';
  bool _isProcessing = false;

  Future<void> _pickMergeFiles() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
    // تفعيل الاختيار المتعدد لملفات الأجزاء
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      List<String> paths = result.paths.whereType<String>().toList();
      paths.sort();
      setState(() {
        _selectedFiles = paths;
        String firstFile = paths.first;
        if (firstFile.contains('.part')) {
          _pathController.text = firstFile.substring(0, firstFile.indexOf('.part'));
        } else {
          _pathController.text = firstFile;
        }
        _status = 'تم تحديد ${paths.length} جزء للدمج';
      });
    }
  }

  Future<void> _startMerge() async {
    final basePath = _pathController.text.trim();
    if (basePath.isEmpty && _selectedFiles.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _status = 'جاري الدمج...';
    });

    try {
      final outputFile = File('${basePath}_merged.pkg');
      final RandomAccessFile writer = await outputFile.open(mode: FileMode.write);
      int mergedCount = 0;

      if (_selectedFiles.isNotEmpty) {
        for (String filePath in _selectedFiles) {
          File partFile = File(filePath);
          if (await partFile.exists()) {
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
        }
      } else {
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
      }

      await writer.close();

      setState(() {
        _status = mergedCount > 0 ? 'تم الدمج بنجاح!' : 'لم يتم العثور على أجزاء!';
      });
    } catch (e) {
      setState(() => _status = 'خطأ: $e');
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: AppTranslations.get(widget.lang, 'base_path'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.folder_open, size: 30),
                onPressed: _pickMergeFiles,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _isProcessing ? null : _startMerge,
              child: Text(AppTranslations.get(widget.lang, 'start_merge')),
            ),
          ),
        ],
      ),
    );
  }
}

class SendPs4Tab extends StatefulWidget {
  final String lang;
  const SendPs4Tab({super.key, required this.lang});

  @override
  State<SendPs4Tab> createState() => _SendPs4TabState();
}

class _SendPs4TabState extends State<SendPs4Tab> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.50');
  final TextEditingController _fileController =
      TextEditingController(text: '/storage/emulated/0/Download/PS4_PKG_Tools/game.pkg');
  String _status = '';
  bool _isProcessing = false;

  Future<void> _pickSendFile() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileController.text = result.files.single.path!;
      });
    }
  }

  Future<void> _sendToPs4() async {
    final ip = _ipController.text.trim();
    final filePath = _fileController.text.trim();

    setState(() {
      _isProcessing = true;
      _status = 'جاري الإرسال...';
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
        _status = response.statusCode == 200 ? 'تم الإرسال لـ PS4 بنجاح!' : 'خطأ: ${response.statusCode}';
      });
      client.close();
    } catch (e) {
      setState(() => _status = 'فشل الاتصال: $e');
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
            decoration: InputDecoration(
              labelText: AppTranslations.get(widget.lang, 'ip_ps4'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fileController,
                  decoration: const InputDecoration(
                    labelText: 'مسار الملف',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.folder_open, size: 30),
                onPressed: _pickSendFile,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _isProcessing ? null : _sendToPs4,
              child: Text(AppTranslations.get(widget.lang, 'send_btn')),
            ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# 3. إعداد GitHub Actions لتوليد النسختين معاً رفعهما في Artifacts
mkdir -p .github/workflows
cat << 'WORKFLOW_EOF' > .github/workflows/main.yml
name: Build Official and Dev Admin APKs

on:
  push:
    branches:
      - main
      - master

jobs:
  build-official:
    name: Build Official User APK
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Get Dependencies
        run: flutter pub get

      - name: Build Official Release APK
        run: flutter build apk --flavor official --target lib/main.dart --release --no-tree-shake-icons

      - name: Upload Official APK
        uses: actions/upload-artifact@v4
        with:
          name: Official-User-APK
          path: build/app/outputs/flutter-apk/app-official-release.apk

  build-dev:
    name: Build Developer Admin APK
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Get Dependencies
        run: flutter pub get

      - name: Build Dev Admin Release APK
        run: flutter build apk --flavor dev --target lib/main.dart --release --no-tree-shake-icons

      - name: Upload Dev Admin APK
        uses: actions/upload-artifact@v4
        with:
          name: Developer-Admin-APK
          path: build/app/outputs/flutter-apk/app-dev-release.apk
WORKFLOW_EOF

# 4. حفظ وتطبيق التعديلات على GitHub
git add .
git commit -m "Fix multi-file picker for merge and split official/dev builds"
git push origin main || git push origin master

