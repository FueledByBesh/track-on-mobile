import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/providers/fitness_provider.dart';
import '../../program/program_detail_page.dart';

/// List of the viewer's saved workout programs. FAB opens a name-only
/// create dialog (the program builder lives on ProgramDetailPage).
class MyProgramsTab extends StatelessWidget {
  const MyProgramsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final programs = provider.programs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : programs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No programs yet',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text('Tap + to create one',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    final program = programs[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProgramDetailPage(program: program)),
                      ),
                      child: Builder(builder: (context) {
                        final scheme = Theme.of(context).colorScheme;
                        final cardColor =
                            Theme.of(context).cardTheme.color ??
                                scheme.surface;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: program.active
                                      ? scheme.primary.withAlpha(30)
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.list_alt,
                                    color: program.active
                                        ? scheme.primary
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      program.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${program.items.length} exercises',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: scheme
                                                      .onSurfaceVariant),
                                        ),
                                        if (program.schedule.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            _scheduleLabel(program.schedule),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: scheme.primary,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                        if (!program.active) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'Inactive',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.orange,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: scheme.onSurfaceVariant),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
    );
  }

  static String _scheduleLabel(List<int> weekdays) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays
        .where((d) => d >= 1 && d <= 7)
        .map((d) => names[d - 1])
        .join(' · ');
  }

  static Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Program'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Program name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<FitnessProvider>().createProgram(name, []);
    }
  }
}
