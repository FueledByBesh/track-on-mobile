import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/steps_provider.dart';
import 'data/providers/activity_provider.dart';
import 'data/providers/fitness_provider.dart';
import 'data/providers/groups_provider.dart';
import 'data/providers/notification_provider.dart';
import 'data/services/step_service.dart';
import 'data/services/activity_service.dart';
import 'data/services/workout_service.dart';
import 'data/services/friendship_service.dart';
import 'data/services/club_service.dart';
import 'data/services/post_service.dart';
import 'data/services/notification_service.dart';
import 'ui/myapp.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => StepsProvider(StepApiService(apiClient))),
        ChangeNotifierProvider(create: (_) => ActivityProvider(ActivityApiService(apiClient))),
        ChangeNotifierProvider(
          create: (_) => FitnessProvider(
            WorkoutApiService(apiClient),
            ProgramApiService(apiClient),
            PlannedWorkoutApiService(apiClient),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupsProvider(
            PostApiService(apiClient),
            ClubApiService(apiClient),
            FriendshipApiService(apiClient),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(NotificationApiService(apiClient)),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
