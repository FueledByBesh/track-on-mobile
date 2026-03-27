import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trackon_mobile/ui/pages/homepage/core.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      showPerformanceOverlay: false,
      title: 'TrackOn',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          // seedColor: const Color(0xFF3A4A5C),
          seedColor: const Color.fromARGB(255, 17, 0, 255),
          brightness: Brightness.light,
        ),
        // scaffoldBackgroundColor: const Color(0xFFFAFBFC),
        scaffoldBackgroundColor: const Color.fromARGB(255, 246, 247, 255),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAFBFC),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1C2A3A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const Center(child: Text('Run Page')),
    const Center(child: Text('Fitness Page')),
    const Center(child: Text('Groups Page')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_selectedIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(220),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                  tooltip: "Hello World",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.directions_run_outlined),
                  activeIcon: Icon(Icons.directions_run),
                  label: 'Run',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center_outlined),
                  activeIcon: Icon(Icons.fitness_center),
                  label: 'Fitness',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  activeIcon: Icon(Icons.group),
                  label: 'Groups',
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: const Color(0xFF8B95A5),
              // unselectedItemColor: Theme.of(context).colorScheme.,
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
