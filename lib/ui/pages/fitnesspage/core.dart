import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/fitness_provider.dart';
import 'package:trackon_mobile/data/models/workout.dart';

class FitnessPage extends StatefulWidget {
  const FitnessPage({super.key});

  @override
  State<FitnessPage> createState() => _FitnessPageState();
}

class _FitnessPageState extends State<FitnessPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FitnessProvider>();
      provider.loadPlannedWorkouts();
      provider.loadPrograms();
      provider.loadWorkoutLibrary();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Fitness',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6B5FFF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6B5FFF),
            tabs: const [
              Tab(text: 'My Day'),
              Tab(text: 'My Programs'),
              Tab(text: 'Library'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [MyDayTab(), MyProgramsTab(), WorkoutLibraryTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ TAB 1: MY DAY ============

class MyDayTab extends StatelessWidget {
  const MyDayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final selectedDate = provider.selectedDate;
    final plannedWorkouts = provider.plannedWorkouts;
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Column(
      children: [
        _WeekCalendar(
          selectedDate: selectedDate,
          onDateSelected: (date) => provider.setSelectedDate(date),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : plannedWorkouts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No workouts for this day', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: plannedWorkouts.length + (isToday ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isToday && index == plannedWorkouts.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TrainingSessionPage(workouts: plannedWorkouts),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text('Start Training', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B5FFF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          );
                        }
                        final pw = plannedWorkouts[index];
                        return _PlannedWorkoutCard(plannedWorkout: pw);
                      },
                    ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekCalendar({required this.selectedDate, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day, selectedDate);
          final isToday = DateUtils.isSameDay(day, now);
          return GestureDetector(
            onTap: () => onDateSelected(day),
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6B5FFF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected ? const Color(0xFF6B5FFF) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day).substring(0, 2),
                    style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlannedWorkoutCard extends StatelessWidget {
  final PlannedWorkout plannedWorkout;

  const _PlannedWorkoutCard({required this.plannedWorkout});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(plannedWorkout.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => context.read<FitnessProvider>().deletePlannedWorkout(plannedWorkout.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => context.read<FitnessProvider>().toggleWorkoutCompleted(plannedWorkout.id, !plannedWorkout.completed),
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
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: const Color(0xFF6B5FFF).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.fitness_center, color: Color(0xFF6B5FFF))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plannedWorkout.workoutName, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600, decoration: plannedWorkout.completed ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 4),
                    Text('${plannedWorkout.sets} sets x ${plannedWorkout.reps} reps', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
              Icon(plannedWorkout.completed ? Icons.check_circle : Icons.circle_outlined, color: plannedWorkout.completed ? Colors.green : Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ TAB 2: MY PROGRAMS ============

class MyProgramsTab extends StatelessWidget {
  const MyProgramsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final programs = provider.programs;

    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : programs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No programs yet', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  final program = programs[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramDetailPage(program: program))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(color: const Color(0xFF6B5FFF).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Icon(Icons.fitness_center, color: Color(0xFF6B5FFF), size: 30)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(program.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('${program.items.length} exercises', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              provider.addProgramToDay(program.id);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${program.name} added to today')));
                            },
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6B5FFF)),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              );
  }
}

class ProgramDetailPage extends StatelessWidget {
  final WorkoutProgram program;
  const ProgramDetailPage({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(program.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: program.items.length,
        itemBuilder: (context, index) {
          final item = program.items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF6B5FFF).withAlpha(30), child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF6B5FFF)))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.workoutName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${item.sets} sets x ${item.reps} reps', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============ TAB 3: LIBRARY ============

class WorkoutLibraryTab extends StatelessWidget {
  const WorkoutLibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FitnessProvider>();
    final workouts = provider.workoutLibrary;
    final muscleFilters = provider.availableMuscleFilters;

    if (provider.isLoading && workouts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Category chip row
        _CategoryFilterRow(
          selected: provider.selectedCategory,
          onSelected: provider.setCategory,
        ),
        // Muscle filter chip row — only render if we actually have muscles
        if (muscleFilters.isNotEmpty)
          _MuscleFilterRow(
            muscles: muscleFilters,
            selected: provider.selectedMuscleGroupIds,
            onToggle: provider.toggleMuscleFilter,
            onClear: provider.clearMuscleFilters,
          ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.forceRefreshLibrary(),
            color: const Color(0xFF6B5FFF),
            child: workouts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No workouts match your filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: workouts.length,
                    itemBuilder: (context, index) =>
                        _WorkoutCardLibrary(workout: workouts[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  final WorkoutCategory? selected;
  final ValueChanged<WorkoutCategory?> onSelected;

  const _CategoryFilterRow({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <(String, WorkoutCategory?)>[
      ('All', null),
      ...WorkoutCategory.all.map((c) => (c.label, c)),
    ];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final (label, value) = entries[index];
          final isSelected = (value == null && selected == null) ||
              (value != null && selected?.value == value.value);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6B5FFF) : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6B5FFF)
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MuscleFilterRow extends StatelessWidget {
  final List<WorkoutMuscle> muscles;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onClear;

  const _MuscleFilterRow({
    required this.muscles,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: muscles.length + (selected.isEmpty ? 0 : 1),
        itemBuilder: (context, index) {
          // Trailing "clear" chip when any muscle is selected
          if (selected.isNotEmpty && index == muscles.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final muscle = muscles[index];
          final isSelected = selected.contains(muscle.muscleGroupId);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onToggle(muscle.muscleGroupId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6B5FFF).withAlpha(30)
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6B5FFF)
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  muscle.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF6B5FFF)
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorkoutCardLibrary extends StatelessWidget {
  final Workout workout;
  const _WorkoutCardLibrary({required this.workout});

  @override
  Widget build(BuildContext context) {
    // Show top 3 muscles for the card row, full list in the detail sheet
    final topMuscles = workout.muscles.take(3).toList();

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _WorkoutDetailSheet(workout: workout),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B5FFF).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    workout.category.label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B5FFF),
                    ),
                  ),
                ),
                const Spacer(),
                if (workout.tutorialVideoUrl != null)
                  const Icon(Icons.play_circle_outline,
                      size: 18, color: Color(0xFF6B5FFF)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              workout.name,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MetaPill(icon: Icons.repeat,
                    label: '${workout.recommendedSets}×${workout.recommendedReps}'),
                if (workout.approxDurationMinutes != null) ...[
                  const SizedBox(width: 6),
                  _MetaPill(
                    icon: Icons.timer_outlined,
                    label: '${workout.approxDurationMinutes} min',
                  ),
                ],
                if (workout.restTimeSeconds != null) ...[
                  const SizedBox(width: 6),
                  _MetaPill(
                    icon: Icons.pause_circle_outline,
                    label: '${workout.restTimeSeconds}s rest',
                  ),
                ],
              ],
            ),
            if (topMuscles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...topMuscles.map((m) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${m.name} ${m.percentage}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )),
                  if (workout.muscles.length > 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '+${workout.muscles.length - 3} more',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    context.read<FitnessProvider>().addWorkoutToDay(workout.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${workout.name} added to today')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B5FFF),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add to today',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutDetailSheet extends StatelessWidget {
  final Workout workout;
  const _WorkoutDetailSheet({required this.workout});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B5FFF).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  workout.category.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B5FFF),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                workout.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.repeat,
                    label:
                        '${workout.recommendedSets} sets × ${workout.recommendedReps} reps',
                  ),
                  if (workout.approxDurationMinutes != null)
                    _MetaPill(
                      icon: Icons.timer_outlined,
                      label: '${workout.approxDurationMinutes} min',
                    ),
                  if (workout.restTimeSeconds != null)
                    _MetaPill(
                      icon: Icons.pause_circle_outline,
                      label: '${workout.restTimeSeconds}s rest',
                    ),
                ],
              ),
              if (workout.muscles.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Targeted muscles',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...workout.muscles.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: m.percentage / 100.0,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6B5FFF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${m.percentage}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              if (workout.tutorialVideoUrl != null) ...[
                const SizedBox(height: 24),
                Text('Video tutorial',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.play_circle_outline,
                        size: 50, color: Color(0xFF6B5FFF)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<FitnessProvider>().addWorkoutToDay(workout.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${workout.name} added to today')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B5FFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add to Today',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============ TRAINING SESSION ============

class TrainingSessionPage extends StatefulWidget {
  final List<PlannedWorkout> workouts;
  const TrainingSessionPage({super.key, required this.workouts});

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  int _currentIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;
  int _restSeconds = 60;

  List<PlannedWorkout> get _workouts => widget.workouts.where((w) => !w.completed).toList();
  PlannedWorkout? get _currentWorkout => _currentIndex < _workouts.length ? _workouts[_currentIndex] : null;
  bool get _isLastSet => _currentWorkout != null && _currentSet >= _currentWorkout!.sets;
  bool get _isLastWorkout => _currentIndex >= _workouts.length - 1;

  void _finishSet() {
    if (_isLastSet) { _finishWorkout(); return; }
    setState(() { _isResting = true; _restSeconds = 60; });
    _startRestTimer();
  }

  void _startRestTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isResting) return false;
      setState(() => _restSeconds--);
      if (_restSeconds <= 0) { setState(() { _isResting = false; _currentSet++; }); return false; }
      return true;
    });
  }

  void _finishWorkout() {
    if (_currentWorkout != null) {
      context.read<FitnessProvider>().toggleWorkoutCompleted(_currentWorkout!.id, true);
    }
    if (_isLastWorkout) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Training complete!')));
    } else {
      setState(() { _currentIndex++; _currentSet = 1; _isResting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentWorkout == null) {
      return Scaffold(appBar: AppBar(title: const Text('Training')), body: const Center(child: Text('No workouts to do!')));
    }
    final workout = _currentWorkout!;

    return Scaffold(
      appBar: AppBar(title: Text('${_currentIndex + 1}/${_workouts.length}'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(workout.workoutName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${workout.sets} sets x ${workout.reps} reps', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
          const Spacer(),
          if (_isResting)
            Column(children: [
              Text('Rest', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey)),
              const SizedBox(height: 8),
              Text('$_restSeconds', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF6B5FFF))),
              const SizedBox(height: 8),
              TextButton(onPressed: () => setState(() { _isResting = false; _currentSet++; }), child: const Text('Skip Rest')),
            ])
          else
            Column(children: [
              Text('Set $_currentSet of ${workout.sets}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${workout.reps} reps', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF6B5FFF))),
            ]),
          const Spacer(),
          if (!_isResting)
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: _finishSet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B5FFF), minimumSize: const Size(0, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_isLastSet ? 'Finish Workout' : 'Finish Set', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              )),
              if (!_isLastSet) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _finishWorkout,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(56, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Icon(Icons.skip_next, color: Colors.white),
                ),
              ],
            ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
