import 'package:flutter/material.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6B5FFF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6B5FFF),
            tabs: const [
              Tab(text: 'My Workouts'),
              Tab(text: 'Workout Library'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [MyWorkoutsTab(), WorkoutLibraryTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class MyWorkoutsTab extends StatefulWidget {
  const MyWorkoutsTab({super.key});

  @override
  State<MyWorkoutsTab> createState() => _MyWorkoutsTabState();
}

class _MyWorkoutsTabState extends State<MyWorkoutsTab> {
  final List<WorkoutItem> workouts = [
    WorkoutItem(
      title: 'Chest Day',
      day: 'Monday',
      exercises: 4,
      duration: 45,
      color: Colors.blue,
    ),
    WorkoutItem(
      title: 'Leg Day',
      day: 'Wednesday',
      exercises: 5,
      duration: 50,
      color: Colors.orange,
    ),
    WorkoutItem(
      title: 'Back & Biceps',
      day: 'Friday',
      exercises: 4,
      duration: 48,
      color: Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => WorkoutDetailSheet(workout: workout),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: workout.color.withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fitness_center,
                      color: workout.color,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${workout.exercises} exercises • ${workout.duration} min',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workout.day,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: workout.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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

class WorkoutLibraryTab extends StatefulWidget {
  const WorkoutLibraryTab({super.key});

  @override
  State<WorkoutLibraryTab> createState() => _WorkoutLibraryTabState();
}

class _WorkoutLibraryTabState extends State<WorkoutLibraryTab> {
  String selectedCategory = 'All';
  final List<String> categories = [
    'All',
    'Strength',
    'Cardio',
    'Flexibility',
    'HIIT',
  ];

  final List<WorkoutItem> allWorkouts = [
    WorkoutItem(
      title: 'Push Ups',
      day: 'Strength',
      exercises: 1,
      duration: 15,
      color: Colors.blue,
    ),
    WorkoutItem(
      title: 'Running',
      day: 'Cardio',
      exercises: 1,
      duration: 30,
      color: Colors.orange,
    ),
    WorkoutItem(
      title: 'Yoga Session',
      day: 'Flexibility',
      exercises: 8,
      duration: 30,
      color: Colors.green,
    ),
    WorkoutItem(
      title: 'HIIT Training',
      day: 'HIIT',
      exercises: 6,
      duration: 20,
      color: Colors.red,
    ),
    WorkoutItem(
      title: 'Squats',
      day: 'Strength',
      exercises: 1,
      duration: 20,
      color: Colors.purple,
    ),
    WorkoutItem(
      title: 'Swimming',
      day: 'Cardio',
      exercises: 1,
      duration: 45,
      color: Colors.cyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = selectedCategory == 'All'
        ? allWorkouts
        : allWorkouts.where((w) => w.day == selectedCategory).toList();

    return Column(
      children: [
        // Category Filter
        SizedBox(
          height: 50,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category == selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6B5FFF)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6B5FFF)
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Workout List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final workout = filtered[index];
              return GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => WorkoutDetailSheet(workout: workout),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: workout.color.withAlpha(100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.fitness_center,
                            color: workout.color,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${workout.exercises} exercises • ${workout.duration} min',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              workout.day,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: workout.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${workout.title} added to your workouts',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B5FFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class WorkoutDetailSheet extends StatelessWidget {
  final WorkoutItem workout;

  const WorkoutDetailSheet({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: workout.color.withAlpha(100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    color: workout.color,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${workout.exercises} exercises • ${workout.duration} min',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Exercises',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            workout.exercises,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: workout.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exercise ${index + 1}: ${['Chest Press', 'Dumbbell Flyes', 'Incline Press', 'Cable Crossovers'][index % 4]}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${3 + index} x ${10 + index * 2}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Video Tutorial',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 50,
                color: workout.color,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5FFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Workout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutItem {
  final String title;
  final String day;
  final int exercises;
  final int duration;
  final Color color;

  WorkoutItem({
    required this.title,
    required this.day,
    required this.exercises,
    required this.duration,
    required this.color,
  });
}
