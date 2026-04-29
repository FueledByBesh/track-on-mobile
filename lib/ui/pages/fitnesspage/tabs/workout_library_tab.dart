import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/workout.dart';
import '../../../../data/providers/fitness_provider.dart';
import '../../../sharedwidgets/workout_thumbnail.dart';
import '../../workout/about_workout_page.dart';

/// Browseable catalog of every workout in the library. Filter bar at
/// the top (category chips + a tune icon for muscle filters), then a
/// scrollable list of compact cards. Tapping a card opens the full
/// workout detail page.
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
        _LibraryFilterBar(
          selectedCategory: provider.selectedCategory,
          onCategoryChanged: provider.setCategory,
          activeMuscleCount: provider.selectedMuscleGroupIds.length,
          hasMuscleOptions: muscleFilters.isNotEmpty,
          onOpenMuscleFilters: () => _openMuscleFilterSheet(
            context,
            muscleFilters,
            provider,
          ),
        ),
        const SizedBox(height: 4),
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: workouts.length,
                    itemBuilder: (context, index) =>
                        _WorkoutCardLibrary(workout: workouts[index]),
                  ),
          ),
        ),
      ],
    );
  }

  void _openMuscleFilterSheet(
    BuildContext context,
    List<WorkoutMuscle> muscles,
    FitnessProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _MuscleFilterSheet(
        muscles: muscles,
        selected: provider.selectedMuscleGroupIds,
        onToggle: provider.toggleMuscleFilter,
        onClear: provider.clearMuscleFilters,
      ),
    );
  }
}

/// Single compact filter row: category chips that scroll horizontally
/// plus a trailing "tune" icon that opens the muscle-filter sheet.
/// Muscle filters moved into the sheet so the main page loses a whole
/// second chip row — the library list gets more breathing room, and
/// rare filters (muscle groups) stay one tap away.
class _LibraryFilterBar extends StatelessWidget {
  final WorkoutCategory? selectedCategory;
  final ValueChanged<WorkoutCategory?> onCategoryChanged;
  final int activeMuscleCount;
  final bool hasMuscleOptions;
  final VoidCallback onOpenMuscleFilters;

  const _LibraryFilterBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.activeMuscleCount,
    required this.hasMuscleOptions,
    required this.onOpenMuscleFilters,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: _CategoryChips(
              selected: selectedCategory,
              onSelected: onCategoryChanged,
            ),
          ),
          if (hasMuscleOptions)
            _FilterIconButton(
              badgeCount: activeMuscleCount,
              onTap: onOpenMuscleFilters,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final WorkoutCategory? selected;
  final ValueChanged<WorkoutCategory?> onSelected;

  const _CategoryChips({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <(String, WorkoutCategory?)>[
      ('All', null),
      ...WorkoutCategory.all.map((c) => (c.label, c)),
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final (label, value) = entries[index];
        final isSelected = (value == null && selected == null) ||
            (value != null && selected?.value == value.value);
        final scheme = Theme.of(context).colorScheme;
        final cardColor =
            Theme.of(context).cardTheme.color ?? scheme.surface;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : cardColor,
                border: Border.all(
                  color:
                      isSelected ? scheme.primary : scheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Tune" icon with a small dot badge counting active muscle filters.
/// Consistent 36×36 hit-target so it sits nicely inside the 44px filter
/// bar.
class _FilterIconButton extends StatelessWidget {
  final int badgeCount;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBadge = badgeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color:
              hasBadge ? scheme.primary.withAlpha(30) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.tune,
                size: 20,
                color:
                    hasBadge ? scheme.primary : scheme.onSurfaceVariant),
            if (hasBadge)
              Positioned(
                right: 4,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minWidth: 14),
                  child: Text(
                    '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking muscle-group filters. Multi-select; each
/// tap toggles immediately against the provider so the library list
/// updates live behind the sheet.
class _MuscleFilterSheet extends StatelessWidget {
  final List<WorkoutMuscle> muscles;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onClear;

  const _MuscleFilterSheet({
    required this.muscles,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: StatefulBuilder(
        // Rebuild the chip grid when the user taps a chip — the
        // provider notifies listeners but the bottom sheet's own
        // context doesn't rebuild unless we locally trigger it.
        builder: (ctx, setInner) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Muscle groups',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (selected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        onClear();
                        setInner(() {});
                      },
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: muscles.map((m) {
                  final isSelected = selected.contains(m.muscleGroupId);
                  return GestureDetector(
                    onTap: () {
                      onToggle(m.muscleGroupId);
                      setInner(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary.withAlpha(30)
                            : scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(Icons.check,
                                size: 14, color: scheme.primary),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact library row. Thumbnail on the left, name + meta + top
/// muscles stacked on the right. Tapping opens the full detail page —
/// the "add to today" button lives there now, so the card doesn't need
/// its own action bar and stays short.
class _WorkoutCardLibrary extends StatelessWidget {
  final Workout workout;
  const _WorkoutCardLibrary({required this.workout});

  @override
  Widget build(BuildContext context) {
    // Show top 2 muscles for the compact card row, full list in the
    // detail sheet.
    final topMuscles = workout.muscles.take(2).toList();

    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AboutWorkoutPage(
                  workout: workout,
                  pageContext: const AboutWorkoutContext.library(),
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkoutThumbnail(
                    videoUrl: workout.tutorialVideoUrl,
                    size: WorkoutThumbnailSize.medium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workout.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (workout.tutorialVideoUrl != null) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.play_circle_outline,
                                  size: 16, color: scheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Category + sets×reps + duration on one meta row.
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CategoryPill(category: workout.category),
                            _MetaPill(
                              icon: Icons.repeat,
                              label:
                                  '${workout.recommendedSets}×${workout.recommendedReps}',
                            ),
                            if (workout.approxDurationMinutes != null)
                              _MetaPill(
                                icon: Icons.timer_outlined,
                                label:
                                    '${workout.approxDurationMinutes} min',
                              ),
                          ],
                        ),
                        if (topMuscles.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ...topMuscles.map(
                                (m) => _MusclePill(name: m.name),
                              ),
                              if (workout.muscles.length >
                                  topMuscles.length)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '+${workout.muscles.length - topMuscles.length} more',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _CategoryPill extends StatelessWidget {
  final WorkoutCategory category;
  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _MusclePill extends StatelessWidget {
  final String name;
  const _MusclePill({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
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
