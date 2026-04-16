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
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(),
      body: const HomePageBody(),
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
    final stepsWeekly = _build7DayData(stepsProvider.history, (d) => d.stepCount.toDouble());
    final activityWeekly = _build7DayData(stepsProvider.history, (d) => d.stepCount * 0.004);
    final mileageWeekly = _build7DayData(stepsProvider.history, (d) => d.distanceKm);

    final statsData = [
      StatisticsData(
        type: StatsItemType.steps,
        todayValue: '${todaySteps.stepCount}',
        weeklyData: stepsWeekly,
        dayLabels: dayLabels,
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
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        MediaQuery.of(context).padding.top,
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
                    final isOnline = context.read<ConnectivityProvider>().isOnline;
                    stepsProvider.forceRefresh(isOnline: isOnline);
                  },
                  isSyncing: stepsProvider.isSyncing,
                ),
          // Today's Plan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Plan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${dayItems.length} items',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (dayItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_available, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'No workouts planned for today',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...dayItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: switch (item) {
                    DayWorkout dw => _WorkoutCard(dayWorkout: dw),
                    DayProgram dp => _HomeProgramCard(dayProgram: dp),
                  },
                )),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});
  static const double appBarHeight = 60;

  @override
  Size get preferredSize => const Size.fromHeight(appBarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withAlpha(100),
            padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6B5FFF).withAlpha(80),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 22,
                      color: Color(0xFF6B5FFF),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined),
                  color: Colors.grey.shade700,
                ),
                // Dev-only in-app logs — remove before release
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LogsPage()),
                    );
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                  color: Colors.grey.shade700,
                  tooltip: 'Logs (dev)',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                  icon: const Icon(Icons.settings_outlined),
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            WorkoutThumbnail(
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
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${dw.sets} sets x ${dw.reps} reps',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (dw.completed)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B5FFF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check, color: Colors.white, size: 16),
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  shape: BoxShape.circle,
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dp.completed
              ? Colors.green.shade200
              : const Color(0xFF6B5FFF).withAlpha(60),
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
                  : const Color(0xFF6B5FFF).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                dp.completed ? Icons.check_circle : Icons.list_alt,
                color: dp.completed ? Colors.green : const Color(0xFF6B5FFF),
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
                      ),
                ),
                Text(
                  '${dp.workoutCount} exercises',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6B5FFF).withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PROGRAM',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B5FFF),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
          if (!isUnavailable)
            TextButton(
              onPressed: isPermanent ? onOpenSettings : onAllow,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(isPermanent ? 'Settings' : 'Allow'),
            ),
        ],
      ),
    );
  }
}
