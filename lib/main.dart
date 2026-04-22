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
import 'data/providers/logger_provider.dart';
import 'data/providers/notification_provider.dart';
import 'data/providers/permission_provider.dart';
import 'data/providers/theme_provider.dart';
import 'data/services/logger_service.dart';
import 'data/services/permission_service.dart';
import 'data/services/step_service.dart';
import 'data/services/step_sync_service.dart';
import 'data/services/activity_service.dart';
import 'data/services/activity_recorder.dart';
import 'data/services/activity_sync_service.dart';
import 'data/services/location_tracker.dart';
import 'data/services/workout_library_service.dart';
import 'data/services/workout_service.dart';
import 'data/services/club_post_service.dart';
import 'data/services/club_service.dart';
import 'data/services/follow_service.dart';
import 'data/services/post_service.dart';
import 'data/services/user_post_service.dart';
import 'data/services/user_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/cache_store.dart';
import 'data/services/cached_http.dart';
import 'data/services/storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'ui/myapp.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env (git-ignored)
  await dotenv.load(fileName: '.env');

  // Warm the in-app logger so the first real call doesn't race the DB open.
  Logger.i('APP', 'App launched');

  // Load theme preferences before runApp so the first frame has the
  // right mode + accent (no flash of wrong colors).
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Initialize MapBox with the public access token
  final mapboxToken = dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '';
  MapboxOptions.setAccessToken(mapboxToken);

  final apiClient = ApiClient();
  final connectivityProvider = ConnectivityProvider();

  // Wire connectivity to ApiClient so it can short-circuit requests when offline
  apiClient.connectivityProvider = connectivityProvider;
  connectivityProvider.start();

  // Stateless service singletons. Exposed at the top level so pages
  // with local state (club detail, settings, profile, notification
  // prefs) can call the API directly without proxying through a
  // ChangeNotifier.
  final cacheStore = CacheStore();
  final cachedHttp = CachedHttp(dio: apiClient.dio, store: cacheStore);

  final clubApiService = ClubApiService(apiClient);
  final clubPostApiService = ClubPostApiService(apiClient);
  final userPostApiService = UserPostApiService(apiClient);
  final postApiService = PostApiService(apiClient);
  final userApiService = UserApiService(apiClient, cachedHttp, cacheStore);
  final followApiService = FollowApiService(apiClient);
  final storageApiService = StorageApiService(apiClient);
  final activityApiService = ActivityApiService(apiClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: connectivityProvider),
        Provider<ClubApiService>.value(value: clubApiService),
        Provider<ClubPostApiService>.value(value: clubPostApiService),
        Provider<UserPostApiService>.value(value: userPostApiService),
        Provider<PostApiService>.value(value: postApiService),
        Provider<UserApiService>.value(value: userApiService),
        Provider<FollowApiService>.value(value: followApiService),
        Provider<CacheStore>.value(value: cacheStore),
        Provider<CachedHttp>.value(value: cachedHttp),
        Provider<StorageApiService>.value(value: storageApiService),
        Provider<ActivityApiService>.value(value: activityApiService),
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = AuthProvider(apiClient);
            // When the interceptor clears tokens on a refresh failure, the
            // whole UI needs to bounce to the login page. Wire it here,
            // once both objects exist.
            apiClient.onAuthExpired = authProvider.handleAuthExpired;
            // Wipe the HTTP response cache on sign-out / auth-expiry so
            // the next user doesn't inherit the previous session's data.
            authProvider.onSignedOut = cacheStore.clear;
            return authProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final stepApi = StepApiService(apiClient);
            return StepsProvider(stepApi, StepSyncService(stepApi, apiClient));
          },
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityHistoryProvider(activityApiService),
        ),
        ChangeNotifierProxyProvider<ActivityHistoryProvider, ActivityProvider>(
          create: (ctx) {
            final recorder = ActivityRecorder(GeolocatorLocationTracker());
            final sync = ActivitySyncService(activityApiService);
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
            WorkoutLibraryService(WorkoutApiService(apiClient)),
            ProgramApiService(apiClient),
            PlannedWorkoutApiService(apiClient),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupsProvider(
            clubs: clubApiService,
            clubPosts: clubPostApiService,
            userPosts: userPostApiService,
            posts: postApiService,
            users: userApiService,
            follows: followApiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              NotificationProvider(NotificationApiService(apiClient)),
        ),
        ChangeNotifierProvider(create: (_) => LoggerProvider()),
        ChangeNotifierProvider(
          create: (_) => PermissionProvider(PermissionService()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
