import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/logger_provider.dart';
import 'package:trackon_mobile/data/services/logger_service.dart';

/// Dev-only log viewer. Shows the contents of the local logs DB as cards,
/// newest first, with a level filter and a delete-all button.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final Set<LogLevel> _visibleLevels = {
    LogLevel.info,
    LogLevel.warn,
    LogLevel.error,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoggerProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoggerProvider>();
    final filtered = provider.entries
        .where((e) => _visibleLevels.contains(e.level))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.refresh(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(context, provider),
            tooltip: 'Delete all',
          ),
        ],
      ),
      body: Column(
        children: [
          _LevelFilterRow(
            visible: _visibleLevels,
            onToggle: (level) {
              setState(() {
                if (_visibleLevels.contains(level)) {
                  _visibleLevels.remove(level);
                } else {
                  _visibleLevels.add(level);
                }
              });
            },
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      provider.entries.isEmpty
                          ? 'No logs yet'
                          : 'No logs at selected levels',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemBuilder: (context, index) =>
                        _LogCard(entry: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext ctx, LoggerProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete all logs?'),
        content: const Text('This truncates the local log database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.clear();
    }
  }
}

class _LevelFilterRow extends StatelessWidget {
  final Set<LogLevel> visible;
  final ValueChanged<LogLevel> onToggle;

  const _LevelFilterRow({required this.visible, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: LogLevel.values.map((level) {
          final active = visible.contains(level);
          final color = _levelColor(level);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_levelLabel(level)),
              selected: active,
              onSelected: (_) => onToggle(level),
              selectedColor: color.withAlpha(40),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: active ? color : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: active ? color : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final LogEntry entry;

  const _LogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(entry.level);
    final timeStr = DateFormat('HH:mm:ss.SSS').format(entry.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _levelLabel(entry.level),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.tag,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              entry.message,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _levelColor(LogLevel level) {
  switch (level) {
    case LogLevel.debug:
      return Colors.grey;
    case LogLevel.info:
      return const Color(0xFF6B5FFF);
    case LogLevel.warn:
      return Colors.orange;
    case LogLevel.error:
      return Colors.red;
  }
}

String _levelLabel(LogLevel level) {
  switch (level) {
    case LogLevel.debug:
      return 'DEBUG';
    case LogLevel.info:
      return 'INFO';
    case LogLevel.warn:
      return 'WARN';
    case LogLevel.error:
      return 'ERROR';
  }
}
