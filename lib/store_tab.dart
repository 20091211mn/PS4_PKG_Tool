import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreItem {
  final String name, desc, url, tag, icon, platform, version;
  const StoreItem(this.name, this.desc, this.url, this.tag,
      {this.icon = '', this.platform = 'PS4', this.version = ''});
}

const List<StoreItem> kItems = [
  StoreItem('GoldHEN', 'Homebrew enabler للـ PS4', 'https://github.com/GoldHEN/GoldHEN', 'نظام'),
  StoreItem('PS4 Store', 'متجر homebrew مفتوح المصدر', 'https://github.com/LightningMods/PS4-Store', 'متجر'),
];

String _s(dynamic v) => v == null ? '' : v.toString();

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  String _q = '';
  String _plat = 'الكل';

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرتش أفتح الرابط')));
    }
  }

  List<StoreItem> _filter(List<StoreItem> all) => all.where((e) {
        final q = _q.toLowerCase();
        final okQ = e.name.toLowerCase().contains(q) || e.desc.toLowerCase().contains(q);
        final okP = _plat == 'الكل' || e.platform == 'PS4+PS5' || e.platform == _plat;
        return okQ && okP;
      }).toList();

  Widget _list(List<StoreItem> items) {
    if (items.isEmpty) return const Center(child: Text('ما فيش نتائج'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final e = items[i];
        final lead = e.icon.isEmpty
            ? const Icon(Icons.extension, color: Color(0xFF7C4DFF), size: 40)
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(e.icon, width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.extension, color: Color(0xFF7C4DFF), size: 40)),
              );
        return Card(
          color: const Color(0xFF1B1B25),
          child: ListTile(
            leading: lead,
            title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${e.desc}\n${e.platform}${e.version.isEmpty ? '' : '  •  v${e.version}'}  •  ${e.tag}',
                style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, color: Color(0xFF9E86FF)),
              onPressed: () => _open(e.url),
            ),
          ),
        );
      },
    );
  }

  Widget _body() {
    if (Firebase.apps.isEmpty) return _list(_filter(kItems));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (c, snap) {
        if (snap.hasError) return _list(_filter(kItems));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _list(_filter(kItems));
        final items = docs.map((d) {
          final m = d.data();
          return StoreItem(_s(m['name']), _s(m['desc']), _s(m['fileUrl']).isEmpty ? _s(m['url']) : _s(m['fileUrl']),
              _s(m['tag']), icon: _s(m['iconUrl']), platform: _s(m['platform']).isEmpty ? 'PS4' : _s(m['platform']),
              version: _s(m['version']));
        }).toList();
        return _list(_filter(items));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Wrap(spacing: 8, children: [
            for (final p in ['الكل', 'PS4', 'PS5'])
              ChoiceChip(label: Text(p), selected: _plat == p, onSelected: (_) => setState(() => _plat = p)),
          ]),
          const SizedBox(height: 10),
          Expanded(child: _body()),
        ]),
      ),
    );
  }
}
