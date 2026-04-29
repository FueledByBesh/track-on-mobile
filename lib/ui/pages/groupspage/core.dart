import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/groups_provider.dart';
import 'tabs/clubs_tab.dart';
import 'tabs/feed_tab.dart';
import 'tabs/people_tab.dart';

/// Top-level Groups tab shell. Title row + 3-tab bar over a TabBarView.
/// All the heavy lifting lives in the per-tab files under `tabs/`.
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GroupsProvider>();
      provider.loadFeed();
      provider.loadMyClubs();
      provider.loadIncomingFollowRequests();
      provider.loadIncomingTransfers();
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
              'Groups',
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
              Tab(text: 'Feed'),
              Tab(text: 'Clubs'),
              Tab(text: 'People'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [FeedTab(), ClubsTab(), PeopleTab()],
            ),
          ),
        ],
      ),
    );
  }
}
