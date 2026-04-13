import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/connectivity_provider.dart';
import 'data/providers/steps_provider.dart';
import 'data/providers/activity_provider.dart';
import 'data/providers/activity_history_provider.dart';
import 'data/providers/fitness_provider.dart';
import 'data/providers/groups_provider.dart';
import 'data/providers/notification_provider.dart';
import 'data/services/step_service.dart';
import 'data/services/step_sync_service.dart';
import 'data/services/activity_service.dart';
import 'data/services/activity_recorder.dart';
import 'data/services/activity_sync_service.dart';
import 'data/services/location_tracker.dart';
import 'data/services/workout_service.dart';
import 'data/services/friendship_service.dart';
import 'data/services/club_service.dart';
import 'data/services/post_service.dart';
import 'data/services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'ui/myapp.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env (git-ignored)
  await dotenv.load(fileName: '.env');

  // Initialize MapBox with the public access token
  final mapboxToken = dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '';
  MapboxOptions.setAccessToken(mapboxToken);

  final apiClient = ApiClient();
  final connectivityProvider = ConnectivityProvider();

  // Wire connectivity to ApiClient so it can short-circuit requests when offline
  apiClient.connectivityProvider = connectivityProvider;
  connectivityProvider.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivityProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
        ChangeNotifierProvider(
          create: (_) {
            final stepApi = StepApiService(apiClient);
            return StepsProvider(stepApi, StepSyncService(stepApi, apiClient));
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final activityApi = ActivityApiService(apiClient);
            return ActivityHistoryProvider(activityApi);
          },
        ),
        ChangeNotifierProxyProvider<ActivityHistoryProvider, ActivityProvider>(
          create: (ctx) {
            final activityApi = ActivityApiService(apiClient);
            final recorder = ActivityRecorder(GeolocatorLocationTracker());
            final sync = ActivitySyncService(activityApi);
            return ActivityProvider(
              recorder,
              sync,
              ctx.read<ActivityHistoryProvider>(),
            );
          },
          update: (ctx, history, previous) => previous!,
        ),
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
          create: (_) =>
              NotificationProvider(NotificationApiService(apiClient)),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
