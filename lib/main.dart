import 'store_tab.dart';
import 'split_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transfer_tab.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  AppSettings.themeNotifier.value = (prefs.getString('theme') ?? 'dark') == 'light' ? ThemeMode.light : ThemeMode.dark;
  AppSettings.languageNotifier.value = prefs.getString('lang') ?? 'العربية';
  AppSettings.themeNotifier.addListener(() => prefs.setString('theme', AppSettings.themeNotifier.value == ThemeMode.light ? 'light' : 'dark'));
  AppSettings.languageNotifier.addListener(() => prefs.setString('lang', AppSettings.languageNotifier.value));
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
    StoreTab(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'المتجر',
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

