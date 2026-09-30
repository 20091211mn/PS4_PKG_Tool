import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PS4PkgStudioApp());
}

class PS4PkgStudioApp extends StatelessWidget {
  const PS4PkgStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 PKG Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestStoragePermissions();
  }

  Future<void> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PS4 PKG Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'أهلاً بك في PS4 PKG Studio',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'اختر القسم المناسب للبدء في إدارة وتقطيع ملفات الـ PKG',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            _buildMenuButton(
              context,
              title: 'تصفح ومدير الملفات',
              subtitle: 'تصفح الذاكرة وتقطيع ملفات PKG مباشرة',
              icon: Icons.folder_open,
              color: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FileManagerScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            _buildMenuButton(
              context,
              title: 'طلب أذونات الذاكرة',
              subtitle: 'تأكيد منح صلاحية الوصول للذاكرة الخارجية',
              icon: Icons.security,
              color: Colors.teal,
              onTap: () async {
                await _requestStoragePermissions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث أذونات الذاكرة!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 26,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  late Directory _currentDir;
  List<FileSystemEntity> _files = [];
  bool _isLoading = false;
  String _statusMessage = 'جاهز للعمليات';

  @override
  void initState() {
    super.initState();
    _initInitialDirectory();
  }

  Future<void> _initInitialDirectory() async {
    Directory targetDir;
    if (Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0');
      if (!await targetDir.exists()) {
        targetDir = Directory.current;
      }
    } else {
      targetDir = Directory.current;
    }
    _loadDirectory(targetDir);
  }

  Future<void> _loadDirectory(Directory dir) async {
    setState(() {
      _isLoading = true;
    });
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الوصول للمسار: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _splitPkgStream(File file) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري تقطيع الملف بأقل استهلاك للرام...';
    });

    try {
      final int chunkSize = 4 * 1024 * 1024 * 1024; // 4GB Part Size
      final String basePath = file.path;

      int partIndex = 0;
      int bytesCopiedCurrentPart = 0;

      IOSink? currentSink;
      final inputStream = file.openRead();

      await for (List<int> chunk in inputStream) {
        if (currentSink == null || bytesCopiedCurrentPart >= chunkSize) {
          await currentSink?.flush();
          await currentSink?.close();

          final partPath = '$basePath.part$partIndex';
          final partFile = File(partPath);
          currentSink = partFile.openWrite();
          partIndex++;
          bytesCopiedCurrentPart = 0;
        }

        currentSink.add(chunk);
        bytesCopiedCurrentPart += chunk.length;
      }

      await currentSink?.flush();
      await currentSink?.close();

      setState(() {
        _statusMessage = 'تم تقطيع الملف بنجاح إلى $partIndex جزء!';
      });
      _loadDirectory(_currentDir);
    } catch (e) {
      setState(() {
        _statusMessage = 'فشلت العملية: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدير الملفات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'المجلد الأعلى',
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
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black.withOpacity(0.25),
            width: double.infinity,
            child: Text(
              'المسار: ${_currentDir.path}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.deepPurple.shade900,
            width: double.infinity,
            child: Text(
              _statusMessage,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                          color: isDir ? Colors.amber : Colors.lightBlueAccent,
                        ),
                        title: Text(name),
                        subtitle: isDir
                            ? null
                            : FutureBuilder<int>(
                                future: (entity as File).length(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const Text('...');
                                  final mb = (snapshot.data! / (1024 * 1024)).toStringAsFixed(2);
                                  return Text('$mb MB');
                                },
                              ),
                        onTap: () {
                          if (isDir) {
                            _loadDirectory(entity as Directory);
                          } else if (name.toLowerCase().endsWith('.pkg')) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('معالجة $name'),
                                content: const Text('هل تريد تقطيع ملف الـ PKG للأجهزة الضعيفة؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('إلغاء'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _splitPkgStream(entity as File);
                                    },
                                    child: const Text('تقطيع (Stream)'),
                                  ),
                                ],
                              ),
                            );
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
