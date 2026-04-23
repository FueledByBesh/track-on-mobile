import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trackon_mobile/data/providers/auth_provider.dart';
import 'package:trackon_mobile/data/providers/connectivity_provider.dart';
import 'package:trackon_mobile/data/providers/activity_provider.dart';
import 'package:trackon_mobile/data/providers/theme_provider.dart';
import 'package:trackon_mobile/ui/pages/auth/login_page.dart';
import 'package:trackon_mobile/ui/pages/homepage/core.dart';
import 'package:trackon_mobile/ui/pages/fitnesspage/core.dart';
import 'package:trackon_mobile/ui/pages/groupspage/core.dart';
import 'package:trackon_mobile/ui/pages/runpage/core.dart';

/// Exposed so code outside a Scaffold (e.g. AuthWrapper while showing the
/// login page) can still push SnackBars.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    // Adapt status bar icons to current brightness
    final isDark =
        themeProvider.mode == ThemeMode.dark ||
        (themeProvider.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    return MaterialApp(
      title: 'TrackOn',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.mode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check auth state on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // One-shot "session expired" toast. Drained after it fires so the next
    // rebuild doesn't re-show it.
    if (authProvider.showExpiredMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Session expired — please sign in again.'),
            backgroundColor: Color(0xFF1C2A3A),
            duration: Duration(seconds: 4),
          ),
        );
        authProvider.consumeExpiredMessage();
      });
    }

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isLoggedIn) {
      return const LoginPage();
    }

    return const MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const RunPage(),
    const FitnessPage(),
    const GroupsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final activity = context.watch<ActivityProvider>();
    final isRecording = activity.isTracking;
    // Hide the bottom nav only while a recording is *actively* running.
    // Paused counts as still-in-session but the user is stationary, so
    // we bring the nav back so they can peek at other tabs without
    // having to resume first.
    final activelyRecording = activity.isTracking && !activity.isPaused;

    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Offline banner — sits above bottom nav
          if (!connectivity.isOnline)
            GestureDetector(
              onTap: connectivity.isChecking
                  ? null
                  : () => connectivity.checkHealth(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: connectivity.offlineReason == OfflineReason.noConnection
                    ? Colors.grey.shade700
                    : Colors.orange.shade700,
                child: Row(
                  children: [
                    Icon(
                      connectivity.offlineReason == OfflineReason.noConnection
                          ? Icons.wifi_off
                          : Icons.cloud_off,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connectivity.offlineMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (connectivity.isChecking)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Text(
                        'Tap to retry',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          // Bottom navigation bar — theme-aware. Collapsed via
          // AnimatedSize when a recording is actively running so the
          // Run tab gets the full screen. Paused brings it back.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: activelyRecording
                ? const SizedBox(width: double.infinity)
                : Builder(
                    builder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final navBg = isDark
                          ? scheme.surface.withAlpha(220)
                          : scheme.surface.withAlpha(200);
                      final borderColor = isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200;

                      return ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: navBg,
                              border: Border(
                                top: BorderSide(color: borderColor, width: 0.5),
                              ),
                            ),
                            child: BottomNavigationBar(
                              currentIndex: _currentIndex,
                              onTap: (index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              type: BottomNavigationBarType.fixed,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              selectedItemColor: scheme.primary,
                              unselectedItemColor: scheme.onSurfaceVariant,
                              items: [
                                const BottomNavigationBarItem(
                                  icon: Icon(Icons.home),
                                  label: 'Home',
                                ),
                                BottomNavigationBarItem(
                                  icon: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.directions_run),
                                      if (isRecording)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: scheme.error,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: scheme.surface,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  label: 'Run',
                                ),
                                const BottomNavigationBarItem(
                                  icon: Icon(Icons.fitness_center),
                                  label: 'Fitness',
                                ),
                                const BottomNavigationBarItem(
                                  icon: Icon(Icons.group),
                                  label: 'Groups',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
