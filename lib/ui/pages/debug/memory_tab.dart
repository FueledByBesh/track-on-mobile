import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:trackon_mobile/data/local/activity_database.dart';
import 'package:trackon_mobile/data/local/logger_database.dart';
import 'package:trackon_mobile/data/local/step_database.dart';
import 'package:trackon_mobile/data/local/workout_library_database.dart';

/// Inspect/delete on-device state: the four SQLite DBs and
/// SharedPreferences. Read-only by default, with per-row delete
/// (and optional cascade on FK-parent tables).
class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});

  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

enum _Mode { databases, prefs }

class _MemoryTabState extends State<MemoryTab> {
  _Mode _mode = _Mode.databases;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                value: _Mode.databases,
                label: Text('Databases'),
                icon: Icon(Icons.storage_outlined),
              ),
              ButtonSegment(
                value: _Mode.prefs,
                label: Text('Prefs'),
                icon: Icon(Icons.tune),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        Expanded(
          child: _mode == _Mode.databases
              ? const _DatabasesView()
              : const _PrefsView(),
        ),
      ],
    );
  }
}

// ========== DATABASES ==========

class _ChildSpec {
  final String table;
  final String fkColumn; // column in child table
  final String parentKey; // column in parent row
  const _ChildSpec({
    required this.table,
    required this.fkColumn,
    required this.parentKey,
  });
}

class _DbMeta {
  final String key;
  final String label;
  final Future<Database> Function() open;
  final Map<String, List<_ChildSpec>> parents;
  const _DbMeta({
    required this.key,
    required this.label,
    required this.open,
    this.parents = const {},
  });
}

final List<_DbMeta> _dbs = [
  _DbMeta(
    key: 'logs',
    label: 'Logs',
    open: () => LoggerDatabase.database,
  ),
  _DbMeta(
    key: 'activity',
    label: 'Activity',
    open: () => ActivityDatabase.database,
    parents: {
      'activity_sessions': [
        _ChildSpec(
          table: 'location_points',
          fkColumn: 'session_id',
          parentKey: 'id',
        ),
        _ChildSpec(
          table: 'pause_intervals',
          fkColumn: 'session_id',
          parentKey: 'id',
        ),
      ],
    },
  ),
  _DbMeta(
    key: 'steps',
    label: 'Steps',
    open: () => StepDatabase.database,
  ),
  _DbMeta(
    key: 'workouts',
    label: 'Workouts',
    open: () => WorkoutLibraryDatabase.database,
  ),
];

const int _pageSize = 100;

class _DatabasesView extends StatefulWidget {
  const _DatabasesView();

  @override
  State<_DatabasesView> createState() => _DatabasesViewState();
}

class _DatabasesViewState extends State<_DatabasesView> {
  _DbMeta _selectedDb = _dbs.first;
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, Object?>> _rows = [];
  int _total = 0;
  int _offset = 0;
  bool _loadingTables = false;
  bool _loadingRows = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() {
      _loadingTables = true;
      _error = null;
      _tables = [];
      _selectedTable = null;
      _rows = [];
      _total = 0;
      _offset = 0;
    });
    try {
      final db = await _selectedDb.open();
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
        "AND name NOT LIKE 'android_metadata' "
        "ORDER BY name",
      );
      final tables = rows.map((r) => r['name'] as String).toList();
      setState(() {
        _tables = tables;
        _loadingTables = false;
      });
      if (tables.isNotEmpty) {
        await _selectTable(tables.first);
      }
    } catch (e) {
      setState(() {
        _loadingTables = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectTable(String table) async {
    setState(() {
      _selectedTable = table;
      _rows = [];
      _total = 0;
      _offset = 0;
    });
    await _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    final table = _selectedTable;
    if (table == null) return;
    setState(() => _loadingRows = true);
    try {
      final db = await _selectedDb.open();
      final offset = reset ? 0 : _offset;
      final rows = await db.rawQuery(
        'SELECT rowid AS _rowid, * FROM "$table" LIMIT ? OFFSET ?',
        [_pageSize, offset],
      );
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM "$table"',
      );
      final total = (countRows.first['c'] as int?) ?? 0;
      setState(() {
        if (reset) {
          _rows = rows;
        } else {
          _rows = [..._rows, ...rows];
        }
        _total = total;
        _offset = offset + rows.length;
        _loadingRows = false;
      });
    } catch (e) {
      setState(() {
        _loadingRows = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteRow(Map<String, Object?> row,
      {bool cascade = false}) async {
    final table = _selectedTable;
    if (table == null) return;
    final rowid = row['_rowid'] as int?;
    if (rowid == null) return;

    final children = _selectedDb.parents[table] ?? const [];

    try {
      final db = await _selectedDb.open();
      await db.transaction((txn) async {
        if (cascade) {
          for (final c in children) {
            await txn.delete(
              c.table,
              where: '${c.fkColumn} = ?',
              whereArgs: [row[c.parentKey]],
            );
          }
        }
        await txn.delete(table, where: 'rowid = ?', whereArgs: [rowid]);
      });
      await _loadPage(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, Object?> row) async {
    final table = _selectedTable!;
    final children = _selectedDb.parents[table] ?? const [];
    final hasChildren = children.isNotEmpty;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete row?'),
        content: Text(
          hasChildren
              ? 'This row has related rows in: ${children.map((c) => c.table).join(', ')}.\n\n'
                  'FK cascades are not enabled, so child rows will remain unless '
                  'you pick "Delete with children".'
              : 'This permanently removes the row.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (hasChildren)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cascade'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete with children'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'row'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(hasChildren ? 'Delete row only' : 'Delete'),
          ),
        ],
      ),
    );
    if (choice == 'row') {
      await _deleteRow(row);
    } else if (choice == 'cascade') {
      await _deleteRow(row, cascade: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _rows.length < _total;
    final parentSpec = _selectedTable == null
        ? null
        : _selectedDb.parents[_selectedTable!];

    return Column(
      children: [
        _ChipRow(
          items: _dbs.map((d) => d.label).toList(),
          selected: _selectedDb.label,
          onSelected: (label) {
            final db = _dbs.firstWhere((d) => d.label == label);
            setState(() => _selectedDb = db);
            _loadTables();
          },
          icon: Icons.storage_outlined,
        ),
        if (_loadingTables)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          )
        else if (_tables.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No tables', style: TextStyle(color: Colors.grey)),
          )
        else
          _ChipRow(
            items: _tables,
            selected: _selectedTable,
            onSelected: _selectTable,
            icon: Icons.table_chart_outlined,
          ),
        if (parentSpec != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Parent table. Children: ${parentSpec.map((c) => c.table).join(", ")}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (_selectedTable != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Showing ${_rows.length} / $_total',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: _loadingRows
                      ? null
                      : () => _loadPage(reset: true),
                ),
              ],
            ),
          ),
        Expanded(
          child: _selectedTable == null
              ? const Center(
                  child: Text('Select a table',
                      style: TextStyle(color: Colors.grey)))
              : _rows.isEmpty && !_loadingRows
                  ? const Center(
                      child: Text('Empty table',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: _rows.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _rows.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _loadingRows ? null : () => _loadPage(),
                                icon: _loadingRows
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.expand_more, size: 18),
                                label: Text(
                                    'Load more (${_total - _rows.length} remaining)'),
                              ),
                            ),
                          );
                        }
                        return _RowCard(
                          row: _rows[index],
                          onDelete: () => _confirmDelete(_rows[index]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelected;
  final IconData icon;

  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = items[index];
          final active = label == selected;
          return ChoiceChip(
            label: Text(label),
            avatar: Icon(icon,
                size: 14,
                color: active ? scheme.primary : Colors.grey.shade600),
            selected: active,
            onSelected: (_) => onSelected(label),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? scheme.primary : Colors.grey.shade800,
            ),
          );
        },
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final Map<String, Object?> row;
  final VoidCallback onDelete;

  const _RowCard({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final entries = row.entries.where((e) => e.key != '_rowid').toList();
    final rowid = row['_rowid'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
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
                Text(
                  'rowid $rowid',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...entries.map((e) => _KvLine(k: e.key, v: e.value)),
          ],
        ),
      ),
    );
  }
}

class _KvLine extends StatelessWidget {
  final String k;
  final Object? v;

  const _KvLine({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
          children: [
            TextSpan(
              text: '$k: ',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: v == null ? 'null' : v.toString(),
              style: TextStyle(
                color: v == null ? Colors.grey.shade500 : Colors.black87,
                fontStyle: v == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== SHARED PREFERENCES ==========

class _PrefsView extends StatefulWidget {
  const _PrefsView();

  @override
  State<_PrefsView> createState() => _PrefsViewState();
}

class _PrefsViewState extends State<_PrefsView> {
  SharedPreferences? _prefs;
  List<String> _keys = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList()..sort();
      setState(() {
        _prefs = prefs;
        _keys = keys;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirmDelete(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete key?'),
        content: Text('Remove "$key" from SharedPreferences?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _prefs?.remove(key);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_keys.length} keys',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
        ),
        Expanded(
          child: _keys.isEmpty
              ? const Center(
                  child:
                      Text('Empty', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _keys.length,
                  itemBuilder: (context, index) {
                    final key = _keys[index];
                    final value = _prefs?.get(key);
                    return _PrefCard(
                      prefKey: key,
                      value: value,
                      onDelete: () => _confirmDelete(key),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PrefCard extends StatelessWidget {
  final String prefKey;
  final Object? value;
  final VoidCallback onDelete;

  const _PrefCard({
    required this.prefKey,
    required this.value,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeOf(value);
    final typeColor = _typeColor(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prefKey,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              value == null ? 'null' : value.toString(),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: value == null ? Colors.grey.shade500 : Colors.black87,
                fontStyle: value == null ? FontStyle.italic : FontStyle.normal,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeOf(Object? v) {
    if (v == null) return 'NULL';
    if (v is bool) return 'BOOL';
    if (v is int) return 'INT';
    if (v is double) return 'DBL';
    if (v is String) return 'STR';
    if (v is List) return 'LIST';
    return 'OBJ';
  }

  Color _typeColor(Object? v) {
    if (v == null) return Colors.grey;
    if (v is bool) return Colors.purple;
    if (v is int || v is double) return Colors.blue;
    if (v is String) return Colors.green;
    if (v is List) return Colors.orange;
    return Colors.grey;
  }
}
