import 'package:flutter/material.dart';
import 'statistics.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
  static const double height = 200;
  static const double horizontalPadding = 16;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        MediaQuery.of(context).padding.top,
        horizontalPadding,
        0,
      ),
      child: Column(
        spacing: 20,
        children: [const StatisticsWidget(), const SizedBox(height: 20)],
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});
  static const double appBarHeight = 60;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: appBarHeight,
        decoration: BoxDecoration(color: Colors.transparent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Profile(),
            const Spacer(),
            const Text(
              'TrackOn',
              style: TextStyle(
                color: Color(0xFF1C2A3A),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(Icons.notifications_none, size: 28),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(appBarHeight);
}

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  var imageUrl = 'https://avatars.githubusercontent.com/u/12345678?v=4';
  var notificationCount = 0;

  // Future<String> fetchProfileImage() async {
  //   // Simulate network delay
  //   await Future.delayed(const Duration(seconds: 2));
  //   // Return a new image URL (you can replace this with an actual API call)
  //   return 'https://avatars.githubusercontent.com/u/87654321?v=4';
  // }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.network(
          imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
