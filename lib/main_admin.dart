import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
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

class Gh {
  final String token, repo;
  Gh(this.token, this.repo);
  Map<String, String> get _h => {'Authorization': 'Bearer $token', 'Accept': 'application/vnd.github+json'};

  Future<int> _release() async {
    final r = await http.get(Uri.parse('https://api.github.com/repos/$repo/releases/tags/store'), headers: _h);
    if (r.statusCode == 200) return jsonDecode(r.body)['id'] as int;
    final c = await http.post(Uri.parse('https://api.github.com/repos/$repo/releases'),
        headers: {..._h, 'Content-Type': 'application/json'},
        body: jsonEncode({'tag_name': 'store', 'name': 'store', 'body': 'store files'}));
    if (c.statusCode != 201) throw 'GitHub release: ${c.statusCode} ${c.body}';
    return jsonDecode(c.body)['id'] as int;
  }

  Future<Map<String, dynamic>> upload(File f, void Function(double) onP) async {
    final id = await _release();
    final name = '${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last.replaceAll(' ', '_')}';
    final size = await f.length();
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('https://uploads.github.com/repos/$repo/releases/$id/assets?name=${Uri.encodeQueryComponent(name)}'));
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.contentType = ContentType('application', 'octet-stream');
      req.contentLength = size;
      req.bufferOutput = false;
      int sent = 0;
      double last = 0;
      final raf = await f.open();
      try {
        while (true) {
          final chunk = await raf.read(4194304);
          if (chunk.isEmpty) break;
          req.add(chunk);
          await req.flush();
          sent += chunk.length;
          final p = sent / size;
          if (p - last >= 0.01 || p >= 1) { last = p; onP(p); }
        }
      } finally {
        await raf.close();
      }
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 201) throw 'GitHub upload: ${res.statusCode} $body';
      final j = jsonDecode(body);
      return {'url': j['browser_download_url'], 'id': j['id']};
    } finally {
      client.close();
    }
  }

  Future<void> deleteAsset(String id) async {
    await http.delete(Uri.parse('https://api.github.com/repos/$repo/releases/assets/$id'), headers: _h);
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _version = TextEditingController();
  final _tag = TextEditingController();
  File? _icon;
  File? _file;
  String _plat = 'PS4', _msg = '', _step = '', _token = '', _repo = '';
  double _progress = 0;
  bool _busy = false;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('items');

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _token = p.getString('gh_token') ?? '';
      _repo = p.getString('gh_repo') ?? '20091211mn/ps4-store-files';
    });
  }

  Future<void> _settings() async {
    final t = TextEditingController(text: _token);
    final r = TextEditingController(text: _repo);
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إعدادات الرفع (GitHub)'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: r, decoration: const InputDecoration(labelText: 'المستودع (owner/name)')),
          TextField(controller: t, obscureText: true, decoration: const InputDecoration(labelText: 'Token')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              await p.setString('gh_token', t.text.trim());
              await p.setString('gh_repo', r.text.trim());
              if (mounted) setState(() { _token = t.text.trim(); _repo = r.text.trim(); });
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickIcon() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    if (r != null && r.files.single.path != null) setState(() => _icon = File(r.files.single.path!));
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r != null && r.files.single.path != null) setState(() => _file = File(r.files.single.path!));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _file == null) {
      setState(() => _msg = 'الاسم والملف مطلوبين');
      return;
    }
    if (_token.isEmpty) {
      setState(() => _msg = 'حط الـ Token من زر الإعدادات فوق');
      return;
    }
    final gh = Gh(_token, _repo);
    setState(() { _busy = true; _msg = ''; _progress = 0; });
    try {
      String iconUrl = '', iconAsset = '';
      if (_icon != null) {
        setState(() => _step = 'رفع الأيقونة...');
        final r = await gh.upload(_icon!, (p) { if (mounted) setState(() => _progress = p); });
        iconUrl = '${r['url']}';
        iconAsset = '${r['id']}';
      }
      setState(() { _step = 'رفع الملف...'; _progress = 0; });
      final r = await gh.upload(_file!, (p) { if (mounted) setState(() => _progress = p); });
      final size = await _file!.length();
      await _col.add({
        'name': _name.text.trim(),
        'desc': _desc.text.trim(),
        'version': _version.text.trim(),
        'tag': _tag.text.trim(),
        'platform': _plat,
        'iconUrl': iconUrl,
        'iconAsset': iconAsset,
        'fileUrl': '${r['url']}',
        'fileAsset': '${r['id']}',
        'size': size,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _name.clear(); _desc.clear(); _version.clear(); _tag.clear();
      _icon = null;
      _file = null;
      _msg = 'تم الرفع ✓';
    } catch (e) {
      _msg = 'فشل: $e';
    }
    if (mounted) setState(() { _busy = false; _step = ''; });
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> d) async {
    final m = d.data();
    if (_token.isNotEmpty) {
      final gh = Gh(_token, _repo);
      for (final k in ['fileAsset', 'iconAsset']) {
        final id = '${m[k] ?? ''}';
        if (id.isNotEmpty) { try { await gh.deleteAsset(id); } catch (_) {} }
      }
    }
    try {
      await _col.doc(d.id).delete();
    } catch (e) {
      if (mounted) setState(() => _msg = 'فشل الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الأدمن'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _settings),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _version, decoration: const InputDecoration(labelText: 'الإصدار', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _tag, decoration: const InputDecoration(labelText: 'التصنيف (نظام، متجر، أدوات...)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _plat,
          decoration: const InputDecoration(labelText: 'النظام', border: OutlineInputBorder()),
          items: const ['PS4', 'PS5', 'PS4+PS5'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _plat = v ?? 'PS4'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickIcon,
          icon: const Icon(Icons.image),
          label: Text(_icon == null ? 'اختيار أيقونة من الجهاز' : _icon!.path.split('/').last, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickFile,
          icon: const Icon(Icons.attach_file),
          label: Text(_file == null ? 'اختيار الملف من الجهاز' : _file!.path.split('/').last, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: 12),
        if (_token.isEmpty) const Text('لازم تحط الـ Token من زر الإعدادات فوق', textAlign: TextAlign.center, style: TextStyle(color: Colors.orangeAccent)),
        if (_busy) ...[
          Text(_step, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: _progress, color: kPurple),
          Text('${(_progress * 100).toStringAsFixed(0)}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
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
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _delete(d)),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
