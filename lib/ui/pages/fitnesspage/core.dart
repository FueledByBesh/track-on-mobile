import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/fitness_provider.dart';
import 'package:trackon_mobile/data/models/workout.dart';
import 'package:trackon_mobile/ui/pages/program/program_detail_page.dart';
import 'package:trackon_mobile/ui/pages/workout/about_workout_page.dart';
import 'package:trackon_mobile/ui/sharedwidgets/workout_thumbnail.dart';

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
      provider.loadDayItems();
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
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
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
    final items = provider.dayItems;
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
              : items.isEmpty
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
                      itemCount: items.length + (isToday ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isToday && index == items.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: items.isEmpty ? null : () {
                                  // Build PlannedWorkout list from DayWorkout items
                                  // for the existing TrainingSessionPage. Programs are
                                  // handled separately (tap the program card to start).
                                  final workoutItems = items
                                      .whereType<DayWorkout>()
                                      .map((dw) => PlannedWorkout(
                                            id: dw.id,
                                            workoutId: dw.workoutId,
                                            workoutName: dw.workoutName,
                                            category: dw.category,
                                            tutorialVideoUrl: dw.tutorialVideoUrl,
                                            plannedDate: selectedDate.toIso8601String().split('T')[0],
                                            sets: dw.sets,
                                            reps: dw.reps,
                                            completed: dw.completed,
                                            sortOrder: dw.sortOrder,
                                          ))
                                      .toList();
                                  if (workoutItems.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrainingSessionPage(
                                          workouts: workoutItems,
                                          isStandaloneWorkouts: true,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text('Start Training', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          );
                        }
                        final item = items[index];
                        return switch (item) {
                          DayWorkout dw => _PlannedWorkoutCard(dayWorkout: dw),
                          DayProgram dp => _PlannedProgramCard(dayProgram: dp),
                        };
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
          final scheme = Theme.of(context).colorScheme;
          final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
          return GestureDetector(
            onTap: () => onDateSelected(day),
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected ? scheme.primary : scheme.outlineVariant,
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : scheme.onSurface),
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
  final DayWorkout dayWorkout;

  const _PlannedWorkoutCard({required this.dayWorkout});

  @override
  Widget build(BuildContext context) {
    final dw = dayWorkout;
    return Dismissible(
      key: Key(dw.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          context.read<FitnessProvider>().deletePlannedWorkout(dw.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          // Build a PlannedWorkout from DayWorkout for the about page helper.
          final pw = PlannedWorkout(
            id: dw.id,
            workoutId: dw.workoutId,
            workoutName: dw.workoutName,
            category: dw.category,
            tutorialVideoUrl: dw.tutorialVideoUrl,
            plannedDate: '',
            sets: dw.sets,
            reps: dw.reps,
            completed: dw.completed,
            sortOrder: dw.sortOrder,
          );
          openAboutWorkoutFromPlanned(context, pw);
        },
        child: Builder(builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context
                      .read<FitnessProvider>()
                      .toggleWorkoutCompleted(dw.id, !dw.completed),
                  child: dw.completed
                      ? Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child:
                                Icon(Icons.check_circle, color: Colors.green),
                          ),
                        )
                      : WorkoutThumbnail(
                          videoUrl: dw.tutorialVideoUrl,
                          size: WorkoutThumbnailSize.small,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dw.workoutName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: dw.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dw.sets} sets x ${dw.reps} reps',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Program card on the My Day timeline. Shows the program name, workout
/// count, and a completion toggle. Tap navigates to ProgramDetailPage
/// (when we build it — for now just toggles complete).
class _PlannedProgramCard extends StatelessWidget {
  final DayProgram dayProgram;

  const _PlannedProgramCard({required this.dayProgram});

  @override
  Widget build(BuildContext context) {
    final dp = dayProgram;
    return Dismissible(
      key: Key(dp.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          context.read<FitnessProvider>().deletePlannedProgram(dp.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          final provider = context.read<FitnessProvider>();
          final program = provider.programs.firstWhere(
            (p) => p.id == dp.programId,
            orElse: () => WorkoutProgram(
                id: dp.programId, name: dp.programName, items: []),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProgramDetailPage(
                  program: program,
                  plannedProgramId: dp.id,
                )),
          );
        },
        child: Builder(builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dp.completed ? scheme.surfaceContainerHighest : cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dp.completed
                    ? Colors.green.shade200
                    : scheme.primary.withAlpha(60),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: dp.completed
                        ? Colors.green.withAlpha(40)
                        : scheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      dp.completed ? Icons.check_circle : Icons.list_alt,
                      color: dp.completed
                          ? Colors.green
                          : scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dp.programName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: dp.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dp.workoutCount} exercises',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PROGRAM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
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
                      Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No programs yet', style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text('Tap + to create one', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
                        MaterialPageRoute(builder: (_) => ProgramDetailPage(program: program)),
                      ),
                      child: Builder(builder: (context) {
                        final scheme = Theme.of(context).colorScheme;
                        final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      program.name,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${program.items.length} exercises',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                        ),
                                        if (program.schedule.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            _scheduleLabel(program.schedule),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: scheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                        if (!program.active) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'Inactive',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.orange,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
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
    if (name != null && name.isNotEmpty) {
      await context.read<FitnessProvider>().createProgram(name, []);
    }
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
            color: Theme.of(context).colorScheme.primary,
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
          final scheme = Theme.of(context).colorScheme;
          final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : cardColor,
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : scheme.onSurfaceVariant,
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
          final scheme = Theme.of(context).colorScheme;
          // Trailing "clear" chip when any muscle is selected
          if (selected.isNotEmpty && index == muscles.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
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
                      ? scheme.primary.withAlpha(30)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
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
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AboutWorkoutPage(
            workout: workout,
            pageContext: const AboutWorkoutContext.library(),
          ),
        ),
      ),
      child: Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
        return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    workout.category.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (workout.tutorialVideoUrl != null)
                  Icon(Icons.play_circle_outline,
                      size: 18, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkoutThumbnail(
                  videoUrl: workout.tutorialVideoUrl,
                  size: WorkoutThumbnailSize.medium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workout.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${m.name} ${m.percentage}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
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
                          color: scheme.onSurfaceVariant,
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
                    backgroundColor: scheme.primary,
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
        );
      }),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// ============ TRAINING SESSION ============

class TrainingSessionPage extends StatefulWidget {
  final List<PlannedWorkout> workouts;

  /// When non-null, this session was started from a scheduled program
  /// card on My Day. Completing the last exercise auto-marks the whole
  /// planned_program as done via a single API call. Individual exercises
  /// are NOT marked on the server — per-exercise completion is in-memory
  /// only for programs (since they're a single card, not exploded rows).
  ///
  /// When null, this is either a standalone-workouts session (each
  /// exercise IS a planned_workout row) or a practice session from the
  /// program template (no server calls at all).
  final String? plannedProgramId;

  /// True when the workouts are standalone planned_workout rows (from
  /// the My Day timeline's individual workout cards). Each exercise has
  /// its own planned_workout ID and should be marked completed per-row.
  final bool isStandaloneWorkouts;

  const TrainingSessionPage({
    super.key,
    required this.workouts,
    this.plannedProgramId,
    this.isStandaloneWorkouts = false,
  });

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
    // Per-exercise server completion ONLY for standalone planned_workout
    // rows. Program exercises are tracked in memory — the whole program
    // gets one completion call when the session ends.
    if (widget.isStandaloneWorkouts && _currentWorkout != null) {
      context.read<FitnessProvider>().toggleWorkoutCompleted(_currentWorkout!.id, true);
    }

    if (_isLastWorkout) {
      // If this is a program session, mark the planned_program as done.
      if (widget.plannedProgramId != null) {
        context.read<FitnessProvider>().toggleProgramCompleted(
          widget.plannedProgramId!,
          true,
        );
      }
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${_currentIndex + 1}/${_workouts.length}'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(workout.workoutName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${workout.sets} sets x ${workout.reps} reps', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const Spacer(),
          if (_isResting)
            Column(children: [
              Text('Rest', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('$_restSeconds', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => setState(() { _isResting = false; _currentSet++; }), child: const Text('Skip Rest')),
            ])
          else
            Column(children: [
              Text('Set $_currentSet of ${workout.sets}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${workout.reps} reps', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
            ]),
          const Spacer(),
          if (!_isResting)
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: _finishSet,
                style: ElevatedButton.styleFrom(backgroundColor: scheme.primary, minimumSize: const Size(0, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
