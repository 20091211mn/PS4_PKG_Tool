import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreItem {
  final String name, desc, url, tag;
  const StoreItem(this.name, this.desc, this.url, this.tag);
}

// عدّل القائمة هنا: أضف أي أداة (اسم، وصف، رابط الصفحة الرسمية، تصنيف)
const List<StoreItem> kItems = [
  StoreItem('GoldHEN', 'Homebrew enabler للـ PS4', 'https://github.com/GoldHEN/GoldHEN', 'نظام'),
  StoreItem('PS4 Store', 'متجر homebrew مفتوح المصدر', 'https://github.com/LightningMods/PS4-Store', 'متجر'),
];

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  String _q = '';

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرتش أفتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = kItems.where((e) => e.name.toLowerCase().contains(_q.toLowerCase()) || e.desc.contains(_q)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Align(alignment: Alignment.centerRight, child: Text('متجر الأدوات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 15),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'ابحث...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7C4DFF)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                return Card(
                  color: const Color(0xFF1B1B25),
                  child: ListTile(
                    leading: const Icon(Icons.extension, color: Color(0xFF7C4DFF)),
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${e.desc}\n${e.tag}', style: const TextStyle(fontSize: 12)),
                    isThreeLine: true,
                    trailing: IconButton(icon: const Icon(Icons.open_in_new, color: Color(0xFF9E86FF)), onPressed: () => _open(e.url)),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
