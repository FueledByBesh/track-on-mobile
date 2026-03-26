import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostSheet(context),
        backgroundColor: const Color(0xFF6B5FFF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _ProfileHeader()),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF6B5FFF),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF6B5FFF),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Analysis'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            _PostsTab(),
            _AnalysisTab(),
          ],
        ),
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'New Post',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _AttachButton(
                  icon: Icons.image_outlined,
                  label: 'Photo',
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _AttachButton(
                  icon: Icons.insert_chart_outlined,
                  label: 'Activity',
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _AttachButton(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5FFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6B5FFF)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6B5FFF), Color(0xFF9B8FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B5FFF).withAlpha(80),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'RG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ryan Gosling',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@ryangosling',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Actor by day, runner by dawn. Chasing PRs and sunsets. '
              'Marathon finisher x3. Let\'s keep moving.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileStat(value: '142', label: 'Posts'),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _ProfileStat(value: '2.1k', label: 'Followers'),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _ProfileStat(value: '348', label: 'Following'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _InfoChip(icon: Icons.location_on_outlined, label: 'Los Angeles, CA'),
              _InfoChip(icon: Icons.directions_run, label: '1,240 km total'),
              _InfoChip(icon: Icons.calendar_today, label: 'Joined Jan 2024'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// Posts tab

class _PostsTab extends StatelessWidget {
  const _PostsTab();

  @override
  Widget build(BuildContext context) {
    final posts = [
      _UserPost(
        text: 'Just finished a half marathon in 1:32:15! New personal record. '
            'The last 3km were brutal but the crowd energy was unreal.',
        time: '2 hours ago',
        likes: 347,
        comments: 52,
        hasImage: true,
        imageColor: Colors.orange.shade200,
        imageIcon: Icons.directions_run,
        imageCaption: 'Half Marathon Finish Line',
      ),
      _UserPost(
        text: 'Morning trail run through Griffith Park. Nothing beats LA sunrises.',
        time: 'Yesterday',
        likes: 512,
        comments: 38,
        hasImage: true,
        imageColor: Colors.green.shade200,
        imageIcon: Icons.landscape,
        imageCaption: 'Griffith Park Trail',
      ),
      _UserPost(
        text: 'Recovery day. Stretching, foam rolling, and a light swim. '
            'Rest days are training days too.',
        time: '3 days ago',
        likes: 189,
        comments: 14,
        hasImage: false,
      ),
      _UserPost(
        text: 'Week 12 of marathon training complete. Mileage is up to 70km/week. '
            'Feeling strong heading into taper.',
        time: '5 days ago',
        likes: 423,
        comments: 67,
        hasImage: true,
        imageColor: const Color(0xFF6B5FFF).withAlpha(50),
        imageIcon: Icons.insert_chart,
        imageCaption: 'Weekly Training Summary',
      ),
      _UserPost(
        text: 'New shoes day! Testing out the Vaporfly for the upcoming race.',
        time: '1 week ago',
        likes: 278,
        comments: 91,
        hasImage: true,
        imageColor: Colors.blue.shade100,
        imageIcon: Icons.shopping_bag,
        imageCaption: 'Nike Vaporfly Next%',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) => _PostCard(post: posts[index]),
    );
  }
}

class _UserPost {
  final String text;
  final String time;
  final int likes;
  final int comments;
  final bool hasImage;
  final Color? imageColor;
  final IconData? imageIcon;
  final String? imageCaption;

  _UserPost({
    required this.text,
    required this.time,
    required this.likes,
    required this.comments,
    required this.hasImage,
    this.imageColor,
    this.imageIcon,
    this.imageCaption,
  });
}

class _PostCard extends StatelessWidget {
  final _UserPost post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6B5FFF), Color(0xFF9B8FFF)],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'RG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ryan Gosling',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      post.time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
          if (post.hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 180,
                color: post.imageColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      post.imageIcon ?? Icons.image,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.imageCaption ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _PostAction(
                icon: Icons.favorite_outline,
                label: post.likes.toString(),
              ),
              const SizedBox(width: 20),
              _PostAction(
                icon: Icons.mode_comment_outlined,
                label: post.comments.toString(),
              ),
              const SizedBox(width: 20),
              _PostAction(
                icon: Icons.share_outlined,
                label: 'Share',
              ),
              const Spacer(),
              Icon(Icons.bookmark_outline, size: 20, color: Colors.grey.shade500),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PostAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// Analysis tab

class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Weekly distance chart
        _AnalysisCard(
          title: 'Weekly Distance',
          subtitle: 'Last 7 weeks',
          trailing: _ShareButton(),
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        const labels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
                        return Text(
                          labels[value.toInt() % 7],
                          style: const TextStyle(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                barGroups: [
                  _bar(0, 42),
                  _bar(1, 55),
                  _bar(2, 48),
                  _bar(3, 62),
                  _bar(4, 58),
                  _bar(5, 70),
                  _bar(6, 65),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Pace trend
        _AnalysisCard(
          title: 'Pace Trend',
          subtitle: 'Average min/km over last 8 runs',
          trailing: _ShareButton(),
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        'R${value.toInt() + 1}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, _) => Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 3.5,
                maxY: 5.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 4.8),
                      FlSpot(1, 4.6),
                      FlSpot(2, 4.5),
                      FlSpot(3, 4.3),
                      FlSpot(4, 4.4),
                      FlSpot(5, 4.1),
                      FlSpot(6, 4.0),
                      FlSpot(7, 3.9),
                    ],
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withAlpha(30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Activity breakdown
        _AnalysisCard(
          title: 'Activity Breakdown',
          subtitle: 'This month',
          trailing: _ShareButton(),
          child: SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          value: 45,
                          color: const Color(0xFF6B5FFF),
                          title: '45%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: 25,
                          color: Colors.orange,
                          title: '25%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: 20,
                          color: Colors.green,
                          title: '20%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                        PieChartSectionData(
                          value: 10,
                          color: Colors.blue,
                          title: '10%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          radius: 50,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(color: const Color(0xFF6B5FFF), label: 'Running'),
                    const SizedBox(height: 8),
                    _LegendItem(color: Colors.orange, label: 'Strength'),
                    const SizedBox(height: 8),
                    _LegendItem(color: Colors.green, label: 'Yoga'),
                    const SizedBox(height: 8),
                    _LegendItem(color: Colors.blue, label: 'Swimming'),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Monthly summary
        _AnalysisCard(
          title: 'Monthly Summary',
          subtitle: 'March 2026',
          trailing: _ShareButton(),
          child: Column(
            children: [
              _SummaryRow(label: 'Total Distance', value: '284 km'),
              _SummaryRow(label: 'Total Time', value: '22h 15m'),
              _SummaryRow(label: 'Avg Pace', value: '4:42 /km'),
              _SummaryRow(label: 'Calories Burned', value: '18,420 kcal'),
              _SummaryRow(label: 'Elevation Gain', value: '3,150 m'),
              _SummaryRow(label: 'Longest Run', value: '21.1 km'),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static BarChartGroupData _bar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF6B5FFF),
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;

  const _AnalysisCard({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared to your feed!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6B5FFF).withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share, size: 14, color: Color(0xFF6B5FFF)),
            SizedBox(width: 4),
            Text(
              'Share',
              style: TextStyle(
                color: Color(0xFF6B5FFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
