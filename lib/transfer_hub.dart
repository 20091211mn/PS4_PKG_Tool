import 'package:flutter/material.dart';
import 'transfer_tab.dart';
import 'direct_tab.dart';

class TransferHub extends StatefulWidget {
  const TransferHub({super.key});
  @override
  State<TransferHub> createState() => _TransferHubState();
}

class _TransferHubState extends State<TransferHub> {
  int _m = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('عبر RPI')),
              ButtonSegment(value: 1, label: Text('مباشر (بدون RPI)')),
            ],
            selected: {_m},
            onSelectionChanged: (s) => setState(() => _m = s.first),
          ),
        ),
        Expanded(child: IndexedStack(index: _m, children: const [TransferTab(), DirectTab()])),
      ]),
    );
  }
}
