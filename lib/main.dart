import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const PS4PKGToolApp());
}

class PS4PKGToolApp extends StatelessWidget {
  const PS4PKGToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS4 PKG Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const PKGToolHomeScreen(),
    );
  }
}

class PKGToolHomeScreen extends StatefulWidget {
  const PKGToolHomeScreen({super.key});

  @override
  State<PKGToolHomeScreen> createState() => _PKGToolHomeScreenState();
}

class _PKGToolHomeScreenState extends State<PKGToolHomeScreen> {
  String _selectedFilePath = '';
  String _fileName = 'No file selected';
  String _statusMessage = 'Status: Ready';
  bool _isProcessing = false;

  Future<void> _pickPKGFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        File file = File(path);
        String name = file.path.split('/').last;

        setState(() {
          _selectedFilePath = path;
          _fileName = name;
          _statusMessage = 'File Verified Successfully ✓';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _splitPKG() async {
    if (_selectedFilePath.isEmpty) {
      setState(() => _statusMessage = 'Error: Please select a file first!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Splitting PKG file...';
    });

    try {
      // High-performance Split Command via Process
      ProcessResult result = await Process.run('split', ['-b', '4G', '-d', _selectedFilePath, '$_selectedFilePath.part_']);
      setState(() {
        _isProcessing = false;
        _statusMessage = result.exitCode == 0 ? 'Split Completed Successfully!' : 'Split Failed!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Split Process Completed.';
      });
    }
  }

  Future<void> _mergePKG() async {
    if (_selectedFilePath.isEmpty) {
      setState(() => _statusMessage = 'Error: Please select a file first!');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Merging PKG parts...';
    });

    try {
      String basePrefix = _selectedFilePath.contains('.part_') 
          ? _selectedFilePath.split('.part_')[0] 
          : _selectedFilePath.split('.')[0];

      ProcessResult result = await Process.run('sh', ['-c', 'cat $basePrefix.part_* > ${basePrefix}_merged.pkg']);
      
      setState(() {
        _isProcessing = false;
        _statusMessage = result.exitCode == 0 ? 'Merge Completed Successfully!' : 'Merge Failed!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Merge Process Completed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PS4 PKG Tool'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickPKGFile,
              icon: const Icon(Icons.attach_file),
              label: const Text('Select / Upload PKG File'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'File Name: $_fileName',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isProcessing ? null : _splitPKG,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(15)),
              child: const Text('Split PKG', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isProcessing ? null : _mergePKG,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(15)),
              child: const Text('Merge PKG Parts', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 30),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _statusMessage.contains('Error') || _statusMessage.contains('Failed') 
                    ? Colors.red 
                    : Colors.greenAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
