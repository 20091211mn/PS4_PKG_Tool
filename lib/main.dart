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
      home: const PS4StudioV203Main(),
    );
  }
}

class PS4StudioV203Main extends StatefulWidget {
  const PS4StudioV203Main({super.key});

  @override
  State<PS4StudioV203Main> createState() => _PS4StudioV203MainState();
}

class _PS4StudioV203MainState extends State<PS4StudioV203Main> {
  Directory _currentDir = Directory('/storage/emulated/0');
  List<FileSystemEntity> _files = [];
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
    _loadDirectory(_currentDir);
  }

  Future<void> _requestAllPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.notification,
      ].request();
    }
  }

  Future<void> _loadDirectory(Directory dir) async {
    setState(() => _isLoading = true);
    try {
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        entities.sort((a, b) {
          if (a is Directory && b is! Directory) return -1;
          if (a is! Directory && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
        setState(() {
          _currentDir = dir;
          _files = entities;
        });
      } else {
        setState(() {
          _currentDir = Directory.current;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المسار: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'PS4 PKG Studio - مدير الملفات' : 'PS4 PKG Studio - File Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: isAr ? 'المجلد الأعلى' : 'Up Directory',
            onPressed: () {
              if (_currentDir.parent.path != _currentDir.path) {
                _loadDirectory(_currentDir.parent);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDirectory(_currentDir),
          ),
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black26,
            width: double.infinity,
            child: Text(
              '${isAr ? "المسار الحالي" : "Current Path"}: ${_currentDir.path}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.deepPurple.shade900,
              width: double.infinity,
              child: Text(
                _statusMessage,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final entity = _files[index];
                      final isDir = entity is Directory;
                      final name = entity.path.split(Platform.pathSeparator).last;

                      return ListTile(
                        leading: Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file,
                          color: isDir ? Colors.amber : Colors.lightBlue,
                        ),
                        title: Text(name),
                        onTap: () {
                          if (isDir) {
                            _loadDirectory(entity as Directory);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
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
            title: Text(isAr ? 'الوضع الداكن' : 'Dark Mode'),
            subtitle: Text(isAr ? 'تفعيل أو إيقاف الثيم المظلم' : 'Enable or disable dark theme'),
            value: isDark,
            onChanged: (val) => appState.toggleTheme(val),
          ),
          const Divider(),
          ListTile(
            title: Text(isAr ? 'اللغة' : 'Language'),
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
            title: Text(isAr ? 'إعادة طلب الأذونات' : 'Re-request Permissions'),
            subtitle: Text(isAr ? 'الوصول للذاكرة والإشعارات' : 'Storage & Notification permissions'),
            onTap: () async {
              await [
                Permission.storage,
                Permission.manageExternalStorage,
                Permission.notification,
              ].request();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'تم حديث حالة الأذونات!' : 'Permissions updated!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
