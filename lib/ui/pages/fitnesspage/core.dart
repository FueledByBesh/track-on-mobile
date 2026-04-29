import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/fitness_provider.dart';
import 'tabs/my_day_tab.dart';
import 'tabs/my_programs_tab.dart';
import 'tabs/workout_library_tab.dart';

/// Top-level Fitness tab shell. Title row + 3-tab bar over a TabBarView.
/// All the heavy lifting lives in the per-tab files under `tabs/`.
/// Training-session flow is its own page in `training_session_page.dart`.
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
              children: const [
                MyDayTab(),
                MyProgramsTab(),
                WorkoutLibraryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
