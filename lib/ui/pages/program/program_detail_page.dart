import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/workout.dart';
import '../../../data/providers/fitness_provider.dart';
import '../fitnesspage/core.dart';
import '../workout/about_workout_page.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class ProgramDetailPage extends StatefulWidget {
  final WorkoutProgram program;
  const ProgramDetailPage({super.key, required this.program});

  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> {
  bool _editing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late bool _active;
  late Set<int> _schedule;
  late List<ProgramWorkoutItem> _items;

  @override
  void initState() {
    super.initState();
    _resetEditState();
  }

  void _resetEditState() {
    _nameCtrl = TextEditingController(text: widget.program.name);
    _descCtrl = TextEditingController(text: widget.program.description ?? '');
    _active = widget.program.active;
    _schedule = Set.of(widget.program.schedule);
    _items = List.of(widget.program.items);
  }

  void _enterEdit() => setState(() => _editing = true);

  void _cancelEdit() {
    _resetEditState();
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final provider = context.read<FitnessProvider>();
    try {
      await provider.updateProgram(
        widget.program.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        active: _active,
        schedule: _schedule.toList()..sort(),
        items: _items
            .asMap()
            .entries
            .map((e) => {
                  'workout_id': e.value.workoutId,
                  'sort_order': e.key,
                })
            .toList(),
      );
      if (mounted) {
        setState(() => _editing = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        title: _editing
            ? const Text('Edit Program')
            : Text(program.name),
        actions: [
          if (_editing) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _enterEdit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name + description
          if (_editing) ...[
            _field('Name', _nameCtrl),
            const SizedBox(height: 12),
            _field('Description (optional)', _descCtrl, maxLines: 3),
            const SizedBox(height: 16),
          ] else ...[
            if (program.description != null &&
                program.description!.isNotEmpty) ...[
              Text(
                program.description!,
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
          ],

          // Schedule
          _sectionLabel('Schedule'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final isOn = _editing
                  ? _schedule.contains(weekday)
                  : program.schedule.contains(weekday);
              return GestureDetector(
                onTap: _editing
                    ? () => setState(() {
                          if (_schedule.contains(weekday)) {
                            _schedule.remove(weekday);
                          } else {
                            _schedule.add(weekday);
                          }
                        })
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOn
                        ? const Color(0xFF6B5FFF)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _weekdayLabels[i],
                    style: TextStyle(
                      color: isOn ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Active toggle
          Row(
            children: [
              const Text('Active',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value: _editing ? _active : program.active,
                activeColor: const Color(0xFF6B5FFF),
                onChanged: _editing
                    ? (v) => setState(() => _active = v)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Exercises
          _sectionLabel('Exercises (${_editing ? _items.length : program.items.length})'),
          const SizedBox(height: 8),

          if (_editing)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _editableItemCard(context, item, index);
              },
            )
          else
            ...program.items.asMap().entries.map((e) {
              final index = e.key;
              final item = e.value;
              return _readOnlyItemCard(context, item, index);
            }),

          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: _editing
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context
                              .read<FitnessProvider>()
                              .addProgramToDay(program.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('${program.name} added to today')),
                          );
                        },
                        icon: const Icon(Icons.event),
                        label: const Text('Add to Today'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B5FFF),
                          side: const BorderSide(color: Color(0xFF6B5FFF)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final workouts = program.items
                              .map((item) => PlannedWorkout(
                                    id: item.id,
                                    workoutId: item.workoutId,
                                    workoutName: item.workoutName,
                                    category: item.category,
                                    plannedDate: '',
                                    sets: item.sets,
                                    reps: item.reps,
                                    completed: false,
                                    sortOrder: item.sortOrder,
                                  ))
                              .toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrainingSessionPage(workouts: workouts),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Training'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B5FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _readOnlyItemCard(
      BuildContext context, ProgramWorkoutItem item, int index) {
    return GestureDetector(
      onTap: () {
        final fitness = context.read<FitnessProvider>();
        Workout? workout;
        try {
          workout =
              fitness.allWorkouts.firstWhere((w) => w.id == item.workoutId);
        } catch (_) {}
        if (workout != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AboutWorkoutPage(
                workout: workout!,
                pageContext: AboutWorkoutContext(
                  removeFromProgramId: widget.program.id,
                  onRemoveFromProgram: () {
                    fitness.removeWorkoutFromProgram(
                        widget.program.id, item.workoutId);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6B5FFF).withAlpha(30),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Color(0xFF6B5FFF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.workoutName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${item.sets} sets × ${item.reps} reps',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _editableItemCard(
      BuildContext context, ProgramWorkoutItem item, int index) {
    return Container(
      key: ValueKey(item.workoutId),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF6B5FFF).withAlpha(30),
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: Color(0xFF6B5FFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.workoutName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
            onPressed: () => _removeItem(index),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    );
  }
}
