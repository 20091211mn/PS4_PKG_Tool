import 'dart:io';
import 'package:flutter/material.dart';

void main() {
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
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Directory _currentDir = Directory.current;
  List<FileSystemEntity> _files = [];
  bool _isLoading = false;
  String _statusMessage = 'مرحباً بك في PS4 PKG Studio';

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentDir);
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
        title: const Text('PS4 PKG Studio - مدير الملفات'),
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
              'المسار الحالي: ${_currentDir.path}',
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
                                    child: const Text('تقطيع خفيف (Stream)'),
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
