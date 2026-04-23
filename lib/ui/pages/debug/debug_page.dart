import 'package:flutter/material.dart';

import 'logs_tab.dart';
import 'memory_tab.dart';

/// Dev-only inspector: live log viewer + on-device storage inspector
/// (SQLite tables and SharedPreferences). Not used in production.
class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debug'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Logs'),
              Tab(text: 'Memory'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LogsTab(),
            MemoryTab(),
          ],
        ),
      ),
    );
  }
}
