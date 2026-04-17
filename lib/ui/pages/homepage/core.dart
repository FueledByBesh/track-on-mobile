import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'statistics.dart';
import 'dart:ui';
import 'package:trackon_mobile/data/providers/fitness_provider.dart';
import 'package:trackon_mobile/data/providers/connectivity_provider.dart';
import 'package:trackon_mobile/data/providers/permission_provider.dart';
import 'package:trackon_mobile/data/providers/steps_provider.dart';
import 'package:trackon_mobile/data/services/permission_service.dart';
import 'package:trackon_mobile/data/models/workout.dart';
import 'package:trackon_mobile/data/models/daily_steps.dart';
import 'package:trackon_mobile/ui/pages/logs/logs_page.dart';
import 'package:trackon_mobile/ui/pages/program/program_detail_page.dart';
import 'package:trackon_mobile/ui/pages/workout/about_workout_page.dart';
import 'package:trackon_mobile/ui/sharedwidgets/notifications_page.dart';
import 'package:trackon_mobile/ui/sharedwidgets/workout_thumbnail.dart';
import 'package:trackon_mobile/ui/sharedwidgets/profile_page.dart';
import 'package:trackon_mobile/ui/sharedwidgets/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isOnline = context.read<ConnectivityProvider>().isOnline;
      context.read<StepsProvider>().loadSteps(isOnline: isOnline);
      final fitness = context.read<FitnessProvider>();
      fitness.loadDayItems();
      // Warm the library cache so tapping a planned workout card
      // can open the full AboutWorkoutPage without a round trip.
      fitness.loadWorkoutLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HomeHeader(),
            Expanded(child: HomePageBody()),
          ],
        ),
      ),
    );
  }
}

class HomePageBody extends StatelessWidget {
  const HomePageBody({super.key});
  static const double horizontalPadding = 16;

  /// Build 7-day data array from history. Today is always last.
  /// Pads with zeros for missing days.
  static List<double> _build7DayData(
    List<DailySteps> history,
    double Function(DailySteps) extractor,
  ) {
    final now = DateTime.now();
    final result = List<double>.filled(7, 0);
    final dateMap = {for (final d in history) d.date: d};

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      final dateStr = date.toLocal().toIso8601String().split('T')[0];
      final entry = dateMap[dateStr];
      if (entry != null) {
        result[i] = extractor(entry);
      }
    }
    return result;
  }

  /// Day labels for last 7 days, today is last.
  static List<String> _buildDayLabels() {
    final now = DateTime.now();
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return names[d.weekday - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stepsProvider = context.watch<StepsProvider>();
    final fitnessProvider = context.watch<FitnessProvider>();
    final permissions = context.watch<PermissionProvider>();
    final fitnessStatus = permissions.statusOf(AppPermission.fitness);
    final showFitnessBanner =
        fitnessStatus != AppPermissionStatus.granted &&
        fitnessStatus != AppPermissionStatus.unknown;
    final dayItems = fitnessProvider.dayItems;

    final todaySteps = stepsProvider.today;
    final dayLabels = _buildDayLabels();
    final stepsWeekly = _build7DayData(
      stepsProvider.history,
      (d) => d.stepCount.toDouble(),
    );
    final activityWeekly = _build7DayData(
      stepsProvider.history,
      (d) => d.stepCount * 0.004,
    );
    final mileageWeekly = _build7DayData(
      stepsProvider.history,
      (d) => d.distanceKm,
    );

    final statsData = [
      StatisticsData(
        type: StatsItemType.steps,
        todayValue: '${todaySteps.stepCount}',
        weeklyData: stepsWeekly,
        dayLabels: dayLabels,
        goal: todaySteps.goal,
      ),
      StatisticsData(
        type: StatsItemType.activity,
        todayValue: (todaySteps.stepCount * 0.004).toStringAsFixed(0),
        weeklyData: activityWeekly,
        dayLabels: dayLabels,
      ),
      StatisticsData(
        type: StatsItemType.mileage,
        todayValue: todaySteps.distanceKm.toStringAsFixed(1),
        weeklyData: mileageWeekly,
        dayLabels: dayLabels,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        horizontalPadding,
        10,
        horizontalPadding,
        0,
      ),
      child: Column(
        spacing: 20,
        children: [
          if (showFitnessBanner)
            _FitnessPermissionBanner(
              status: fitnessStatus,
              onAllow: () => permissions.request(AppPermission.fitness),
              onOpenSettings: () => permissions.openAppSettings(),
            ),
          stepsProvider.isLoading
              ? const SizedBox(
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                )
              : StatisticsWidget(
                  data: statsData,
                  onRefresh: () {
                    final isOnline = context
                        .read<ConnectivityProvider>()
                        .isOnline;
                    stepsProvider.forceRefresh(isOnline: isOnline);
                  },
                  isSyncing: stepsProvider.isSyncing,
                ),
          // Today's Plan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Today\'s Plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (dayItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${dayItems.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (dayItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_available, size: 40, color: scheme.onSurfaceVariant.withAlpha(100)),
                      const SizedBox(height: 8),
                      Text(
                        'No workouts planned for today',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ...dayItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: switch (item) {
                      DayWorkout dw => _WorkoutCard(dayWorkout: dw),
                      DayProgram dp => _HomeProgramCard(dayProgram: dp),
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Inline header row at the top of the home page scroll view.
/// Theme-aware: avatar accent, icon colors, and greeting text all
/// derive from Theme.of(context).colorScheme.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();
  static const double horizontalPadding = HomePageBody.horizontalPadding;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withAlpha(40),
                border: Border.all(
                  color: scheme.primary.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.person, size: 22, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _greeting,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_outlined),
            color: iconColor,
          ),
          // Dev-only in-app logs — remove before release
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsPage()),
            ),
            icon: const Icon(Icons.bug_report_outlined),
            color: iconColor,
            tooltip: 'Logs (dev)',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
            color: iconColor,
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final DayWorkout dayWorkout;

  const _WorkoutCard({required this.dayWorkout});

  @override
  Widget build(BuildContext context) {
    final dw = dayWorkout;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return GestureDetector(
      onTap: () {
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dw.completed
              ? Colors.green.withAlpha(15)
              : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dw.completed
                ? Colors.green.withAlpha(80)
                : scheme.outlineVariant.withAlpha(80),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail or completed check
            dw.completed
                ? Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle, color: Colors.green, size: 24),
                    ),
                  )
                : WorkoutThumbnail(
                    videoUrl: dw.tutorialVideoUrl,
                    size: WorkoutThumbnailSize.small,
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
                      decoration: dw.completed ? TextDecoration.lineThrough : null,
                      color: dw.completed
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${dw.sets} × ${dw.reps}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dw.category.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant.withAlpha(120), size: 20),
          ],
        ),
      ),
    );
  }
}

class _HomeProgramCard extends StatelessWidget {
  final DayProgram dayProgram;
  const _HomeProgramCard({required this.dayProgram});

  @override
  Widget build(BuildContext context) {
    final dp = dayProgram;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
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
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dp.completed
                ? [Colors.green.withAlpha(isDark ? 30 : 15), Colors.green.withAlpha(isDark ? 50 : 25)]
                : [scheme.primary.withAlpha(isDark ? 30 : 15), scheme.primary.withAlpha(isDark ? 50 : 25)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dp.completed
                ? Colors.green.withAlpha(80)
                : scheme.primary.withAlpha(60),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: dp.completed
                    ? Colors.green.withAlpha(40)
                    : scheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  dp.completed ? Icons.check_circle : Icons.list_alt_rounded,
                  color: dp.completed ? Colors.green : scheme.primary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dp.programName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: dp.completed ? TextDecoration.lineThrough : null,
                      color: dp.completed
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dp.workoutCount} exercises',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'PROGRAM',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline banner shown when the user hasn't granted Health Connect /
/// HealthKit access. Non-blocking — it sits above the step stats but
/// doesn't hide them. Button label and action depend on the current
/// permission state.
class _FitnessPermissionBanner extends StatelessWidget {
  final AppPermissionStatus status;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  const _FitnessPermissionBanner({
    required this.status,
    required this.onAllow,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isPermanent = status == AppPermissionStatus.permanentlyDenied;
    final isUnavailable = status == AppPermissionStatus.unavailable;

    final String title;
    final String subtitle;
    if (isUnavailable) {
      title = 'Step tracking unavailable';
      subtitle = 'Health Connect is not installed on this device.';
    } else if (isPermanent) {
      title = 'Step access is blocked';
      subtitle = 'Enable Health Connect access in system settings.';
    } else {
      title = 'Step tracking is off';
      subtitle = 'Allow Health Connect access to see your step count.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_outline, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          if (!isUnavailable)
            TextButton(
              onPressed: isPermanent ? onOpenSettings : onAllow,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade900,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(isPermanent ? 'Settings' : 'Allow'),
            ),
        ],
      ),
    );
  }
}
