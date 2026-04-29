import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/workout.dart';
import '../../../../data/providers/fitness_provider.dart';
import '../../../sharedwidgets/workout_thumbnail.dart';
import '../../program/program_detail_page.dart';
import '../../workout/about_workout_page.dart';
import '../training_session_page.dart';

/// Day-by-day timeline of planned workouts and programs. Top of the
/// tab is a horizontal week strip; below is a list of cards for the
/// selected date with a "Start Training" button at the bottom when
/// that date is today.
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
                          Icon(Icons.event_available,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No workouts for this day',
                              style:
                                  TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length + (isToday ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isToday && index == items.length) {
                          return _StartTrainingButton(
                            items: items,
                            selectedDate: selectedDate,
                          );
                        }
                        final item = items[index];
                        return switch (item) {
                          DayWorkout dw =>
                            _PlannedWorkoutCard(dayWorkout: dw),
                          DayProgram dp =>
                            _PlannedProgramCard(dayProgram: dp),
                        };
                      },
                    ),
        ),
      ],
    );
  }
}

/// Trailing button on today's list. Only enabled when there's at
/// least one standalone DayWorkout to start (programs are launched
/// from their own card).
class _StartTrainingButton extends StatelessWidget {
  final List<DayItem> items;
  final DateTime selectedDate;

  const _StartTrainingButton({
    required this.items,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: items.isEmpty ? null : () => _startTraining(context),
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text(
            'Start Training',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  void _startTraining(BuildContext context) {
    // Build PlannedWorkout list from the standalone DayWorkout items
    // (programs are launched from their own cards, not this button).
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
    if (workoutItems.isEmpty) return;
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
}

/// Horizontal Mon-Sun strip showing the current week. Selected day is
/// highlighted with the primary color; today gets a primary-colored
/// outline when not selected.
class _WeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekCalendar(
      {required this.selectedDate, required this.onDateSelected});

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
                  color: isToday && !isSelected
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day).substring(0, 2),
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isSelected ? Colors.white70 : Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : scheme.onSurface),
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

/// Single-workout row on the My Day timeline. Swipe left to delete,
/// tap to open AboutWorkoutPage with the planned-day context (toggle
/// complete + remove from day actions live there).
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
          final cardColor =
              Theme.of(context).cardTheme.color ?? scheme.surface;
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
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
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

/// Program card on the My Day timeline. Shows the program name,
/// workout count, and a completion toggle. Tap navigates to the
/// program detail page with the planned-program id wired in.
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
          final cardColor =
              Theme.of(context).cardTheme.color ?? scheme.surface;
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
                      color: dp.completed ? Colors.green : scheme.primary,
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
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
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
