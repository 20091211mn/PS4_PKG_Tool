import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kPurple = Color(0xFF7C4DFF);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? err;
  try {
    await Firebase.initializeApp();
  } catch (e) {
    err = e;
  }
  runApp(AdminApp(initError: err));
}

class AdminApp extends StatelessWidget {
  final Object? initError;
  const AdminApp({super.key, this.initError});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 Admin',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF13131A), primaryColor: kPurple),
      home: initError != null
          ? Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('خطأ Firebase: $initError', textAlign: TextAlign.center))))
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (c, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return s.data == null ? const LoginPage() : const AdminHome();
              },
            ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String _err = '';
  bool _busy = false;

  Future<void> _login() async {
    setState(() { _busy = true; _err = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
    } on FirebaseAuthException catch (e) {
      _err = 'فشل الدخول: ${e.code}';
    } catch (e) {
      _err = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.admin_panel_settings, size: 64, color: kPurple),
            const SizedBox(height: 10),
            const Text('دخول الأدمن', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'الإيميل', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            if (_err.isNotEmpty) Text(_err, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _login,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: Text(_busy ? '...' : 'دخول'),
            ),
          ]),
        ),
      ),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final _c = {for (final k in ['name', 'desc', 'iconUrl', 'fileUrl', 'version', 'tag']) k: TextEditingController()};
  static const _labels = {
    'name': 'الاسم',
    'desc': 'الوصف',
    'iconUrl': 'رابط الأيقونة (صورة)',
    'fileUrl': 'رابط الملف أو الصفحة',
    'version': 'الإصدار',
    'tag': 'التصنيف (نظام، متجر، أدوات...)',
  };
  String _plat = 'PS4';
  String _msg = '';
  bool _busy = false;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('items');

  Future<void> _save() async {
    if (_c['name']!.text.trim().isEmpty || _c['fileUrl']!.text.trim().isEmpty) {
      setState(() => _msg = 'الاسم ورابط الملف مطلوبين');
      return;
    }
    setState(() { _busy = true; _msg = ''; });
    try {
      await _col.add({
        for (final e in _c.entries) e.key: e.value.text.trim(),
        'platform': _plat,
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final t in _c.values) { t.clear(); }
      _msg = 'تم الرفع ✓';
    } catch (e) {
      _msg = 'فشل: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      if (mounted) setState(() => _msg = 'فشل الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الأدمن'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in _c.entries) ...[
          TextField(controller: e.value, decoration: InputDecoration(labelText: _labels[e.key], border: const OutlineInputBorder())),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<String>(
          value: _plat,
          decoration: const InputDecoration(labelText: 'النظام', border: OutlineInputBorder()),
          items: const ['PS4', 'PS5', 'PS4+PS5'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _plat = v ?? 'PS4'),
        ),
        const SizedBox(height: 12),
        if (_msg.isNotEmpty) Text(_msg, textAlign: TextAlign.center, style: TextStyle(color: _msg.contains('✓') ? Colors.greenAccent : Colors.redAccent)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: Text(_busy ? '...' : 'رفع للمتجر'),
        ),
        const Divider(height: 32),
        const Text('الأدوات المرفوعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _col.snapshots(),
          builder: (c, s) {
            if (s.hasError) return Text('خطأ: ${s.error}');
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final docs = s.data!.docs;
            if (docs.isEmpty) return const Text('ما فيش أدوات بعد');
            return Column(children: [
              for (final d in docs)
                Card(
                  child: ListTile(
                    title: Text('${d.data()['name'] ?? ''}'),
                    subtitle: Text('${d.data()['platform'] ?? ''}  •  v${d.data()['version'] ?? ''}'),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _delete(d.id)),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
