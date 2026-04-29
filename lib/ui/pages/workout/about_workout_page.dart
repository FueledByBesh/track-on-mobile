import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/workout.dart';
import '../../../data/providers/fitness_provider.dart';
import 'widgets/add_to_day_sheet.dart';
import 'widgets/add_to_program_sheet.dart';
import 'widgets/workout_muscle_bars.dart';
import 'widgets/workout_video_player.dart';

/// Shared helper: look up the full [Workout] for a [PlannedWorkout] in
/// the local library cache and navigate to the about-workout page with
/// the "my day" context (remove from day + toggle complete actions).
///
/// If the library cache is empty or missing this workout, shows a
/// SnackBar instead of navigating. The library is cached on first use
/// via `WorkoutLibraryService`, so this should almost never hit the
/// error path in practice.
Future<void> openAboutWorkoutFromPlanned(
  BuildContext context,
  PlannedWorkout pw,
) async {
  final fitness = context.read<FitnessProvider>();
  Workout? workout;
  try {
    workout = fitness.allWorkouts.firstWhere((w) => w.id == pw.workoutId);
  } catch (_) {
    workout = null;
  }
  if (workout == null) {
    // Try to trigger a library load in case it wasn't cached yet —
    // doesn't block the tap.
    fitness.loadWorkoutLibrary();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading workout info — try again in a moment')),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AboutWorkoutPage(
        workout: workout!,
        pageContext: AboutWorkoutContext(
          alreadyCompleted: pw.completed,
          onToggleCompleted: () {
            fitness.toggleWorkoutCompleted(pw.id, !pw.completed);
            Navigator.pop(context);
          },
          onRemoveFromDay: () {
            fitness.deletePlannedWorkout(pw.id);
            Navigator.pop(context);
          },
        ),
      ),
    ),
  );
}

/// Configures which action buttons the [AboutWorkoutPage] shows. The
/// page itself is one shared widget reused from library / today's plan /
/// program detail — only the action set differs by call site.
class AboutWorkoutContext {
  /// Show "Add to Program" button at the bottom.
  final bool canAddToProgram;

  /// Show "Add to Day" button at the bottom.
  final bool canAddToDay;

  /// When non-null, render a "Remove from this program" button that
  /// calls [onRemoveFromProgram] with the given program id. Used from
  /// the (future) Program Detail page.
  final String? removeFromProgramId;
  final VoidCallback? onRemoveFromProgram;

  /// When non-null, render a "Remove from day" button for the planned
  /// workout in question. Used from the "My Day" tab.
  final VoidCallback? onRemoveFromDay;

  /// When non-null, render a "Mark complete" / "Mark incomplete" toggle.
  /// Used from the "My Day" tab.
  final VoidCallback? onToggleCompleted;
  final bool alreadyCompleted;

  const AboutWorkoutContext({
    this.canAddToProgram = false,
    this.canAddToDay = false,
    this.removeFromProgramId,
    this.onRemoveFromProgram,
    this.onRemoveFromDay,
    this.onToggleCompleted,
    this.alreadyCompleted = false,
  });

  /// Shortcut for the library tab — both add actions enabled.
  const AboutWorkoutContext.library()
      : canAddToProgram = true,
        canAddToDay = true,
        removeFromProgramId = null,
        onRemoveFromProgram = null,
        onRemoveFromDay = null,
        onToggleCompleted = null,
        alreadyCompleted = false;
}

/// Full-page workout detail view. Opens from library taps, today's plan
/// cards, and future program detail tiles.
class AboutWorkoutPage extends StatelessWidget {
  final Workout workout;
  final AboutWorkoutContext pageContext;

  const AboutWorkoutPage({
    super.key,
    required this.workout,
    required this.pageContext,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: WorkoutVideoPlayer(videoUrl: workout.tutorialVideoUrl),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      workout.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
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
                      _metaPill(
                        Icons.repeat,
                        '${workout.recommendedSets} sets × ${workout.recommendedReps} reps',
                      ),
                      if (workout.approxDurationMinutes != null)
                        _metaPill(
                          Icons.timer_outlined,
                          '${workout.approxDurationMinutes} min',
                        ),
                      if (workout.restTimeSeconds != null)
                        _metaPill(
                          Icons.pause_circle_outline,
                          '${workout.restTimeSeconds}s rest',
                        ),
                    ],
                  ),
                  if (workout.muscles.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Targeted muscles',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    WorkoutMuscleBars(muscles: workout.muscles),
                  ],
                  // Leave room at the bottom so the action bar doesn't
                  // cover the last muscle row.
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ActionBar(
        workout: workout,
        pageContext: pageContext,
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ActionBar extends StatelessWidget {
  final Workout workout;
  final AboutWorkoutContext pageContext;
  const _ActionBar({required this.workout, required this.pageContext});

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (pageContext.canAddToProgram) {
      buttons.add(_button(
        label: 'Add to Program',
        icon: Icons.playlist_add,
        primary: false,
        onTap: () => showAddToProgramSheet(context, workout),
      ));
    }
    if (pageContext.canAddToDay) {
      buttons.add(_button(
        label: 'Add to Day',
        icon: Icons.event,
        primary: true,
        onTap: () => showAddToDaySheet(context, workout),
      ));
    }
    if (pageContext.onToggleCompleted != null) {
      buttons.add(_button(
        label:
            pageContext.alreadyCompleted ? 'Mark incomplete' : 'Mark complete',
        icon: pageContext.alreadyCompleted
            ? Icons.undo
            : Icons.check_circle_outline,
        primary: !pageContext.alreadyCompleted,
        onTap: pageContext.onToggleCompleted!,
      ));
    }
    if (pageContext.onRemoveFromDay != null) {
      buttons.add(_button(
        label: 'Remove from day',
        icon: Icons.delete_outline,
        primary: false,
        destructive: true,
        onTap: pageContext.onRemoveFromDay!,
      ));
    }
    if (pageContext.removeFromProgramId != null &&
        pageContext.onRemoveFromProgram != null) {
      buttons.add(_button(
        label: 'Remove from program',
        icon: Icons.playlist_remove,
        primary: false,
        destructive: true,
        onTap: pageContext.onRemoveFromProgram!,
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required bool primary,
    bool destructive = false,
    required VoidCallback onTap,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final bg = destructive
          ? scheme.errorContainer
          : primary
              ? scheme.primary
              : scheme.surfaceContainerHighest;
      final fg = destructive
          ? scheme.onErrorContainer
          : primary
              ? Colors.white
              : scheme.onSurface;
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    });
  }
}
