import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/workout.dart';
import '../../../../data/providers/fitness_provider.dart';

/// Bottom sheet for "Add to Program". Per-row immediate save — each tap
/// fires an atomic backend toggle (add or remove), no "Save" button.
///
/// Matches the mental model of Spotify's "Add to playlist" or Apple
/// Music's "Add to library": each tap is a discrete, committed decision.
void showAddToProgramSheet(BuildContext context, Workout workout) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToProgramSheet(workout: workout),
  );
}

class _AddToProgramSheet extends StatefulWidget {
  final Workout workout;
  const _AddToProgramSheet({required this.workout});

  @override
  State<_AddToProgramSheet> createState() => _AddToProgramSheetState();
}

class _AddToProgramSheetState extends State<_AddToProgramSheet> {
  bool _showCreateForm = false;
  final TextEditingController _newProgramName = TextEditingController();

  /// Per-program in-flight state so we can show spinners on only the
  /// row the user tapped, not block the whole sheet.
  final Set<String> _busyProgramIds = {};
  bool _creatingProgram = false;

  @override
  void initState() {
    super.initState();
    // Make sure programs are loaded before the sheet opens content.
    // loadPrograms is already idempotent via _hasLoadedPrograms flag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FitnessProvider>().loadPrograms();
    });
  }

  @override
  void dispose() {
    _newProgramName.dispose();
    super.dispose();
  }

  Future<void> _toggleProgram(String programId) async {
    final provider = context.read<FitnessProvider>();
    final isIn = provider.isWorkoutInProgram(programId, widget.workout.id);
    setState(() => _busyProgramIds.add(programId));
    try {
      if (isIn) {
        await provider.removeWorkoutFromProgram(programId, widget.workout.id);
      } else {
        await provider.addWorkoutToProgram(programId, widget.workout.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyProgramIds.remove(programId));
      }
    }
  }

  Future<void> _submitCreate() async {
    final name = _newProgramName.text.trim();
    if (name.isEmpty) return;
    setState(() => _creatingProgram = true);
    try {
      await context
          .read<FitnessProvider>()
          .createProgramWithWorkout(name, widget.workout.id);
      if (mounted) {
        setState(() {
          _showCreateForm = false;
          _newProgramName.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creatingProgram = false);
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('409') || s.contains('already')) return 'Already in program';
    if (s.contains('404')) return 'Not found';
    return 'Try again';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final programs = provider.programs;
    final scheme = Theme.of(context).colorScheme;
    final sheetColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to Program',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _CreateNewProgramRow(
                    isExpanded: _showCreateForm,
                    isBusy: _creatingProgram,
                    controller: _newProgramName,
                    onExpand: () => setState(() => _showCreateForm = true),
                    onCancel: () => setState(() {
                      _showCreateForm = false;
                      _newProgramName.clear();
                    }),
                    onSubmit: _submitCreate,
                  ),
                  if (programs.isEmpty && !provider.isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Center(
                        child: Text(
                          'No programs yet. Create one above.',
                          style:
                              TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ...programs.map((program) {
                    final isIn = provider.isWorkoutInProgram(
                        program.id, widget.workout.id);
                    final isBusy = _busyProgramIds.contains(program.id);
                    return _ProgramRow(
                      program: program,
                      isIn: isIn,
                      isBusy: isBusy,
                      onTap: () => _toggleProgram(program.id),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _CreateNewProgramRow extends StatelessWidget {
  final bool isExpanded;
  final bool isBusy;
  final TextEditingController controller;
  final VoidCallback onExpand;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _CreateNewProgramRow({
    required this.isExpanded,
    required this.isBusy,
    required this.controller,
    required this.onExpand,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!isExpanded) {
      return ListTile(
        leading: Icon(Icons.add_circle_outline, color: scheme.primary),
        title: Text(
          'Create new program',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
        onTap: onExpand,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              enabled: !isBusy,
              decoration: const InputDecoration(
                hintText: 'Program name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.check, color: scheme.primary),
            onPressed: isBusy ? null : onSubmit,
          ),
          IconButton(
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            onPressed: isBusy ? null : onCancel,
          ),
        ],
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget {
  final WorkoutProgram program;
  final bool isIn;
  final bool isBusy;
  final VoidCallback onTap;

  const _ProgramRow({
    required this.program,
    required this.isIn,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(
        program.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        '${program.items.length} exercises',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isIn ? Icons.check_circle : Icons.add_circle_outline,
              // Green for "already in" is a widely-recognized success
              // semantic that holds up in both light + dark themes;
              // the "add" state uses the user's accent color.
              color: isIn ? Colors.green : scheme.primary,
              size: 28,
            ),
      onTap: isBusy ? null : onTap,
    );
  }
}
