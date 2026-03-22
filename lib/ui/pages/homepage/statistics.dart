import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsData {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String unit;
  final String todayValue;
  final List<double> weeklyData; // 7 days of data

  const StatisticsData({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.unit,
    required this.todayValue,
    required this.weeklyData,
  });
}

class StatisticsWidget extends StatefulWidget {
  const StatisticsWidget({super.key});

  @override
  State<StatisticsWidget> createState() => _StatisticsState();
}

class _SizeData {
  final double width;
  final double height;

  const _SizeData(this.width, this.height);

  static _SizeData lerp(_SizeData a, _SizeData b, double t) {
    return _SizeData(
      a.width + (b.width - a.width) * t,
      a.height + (b.height - a.height) * t,
    );
  }
}

class _SizeDataTween extends Tween<_SizeData> {
  _SizeDataTween({required _SizeData begin, required _SizeData end})
    : super(begin: begin, end: end);

  @override
  _SizeData lerp(double t) => _SizeData.lerp(begin!, end!, t);
}

class _PositionData {
  // final double? width, height;
  final double fromTop, fromLeft;

  const _PositionData({required this.fromTop, required this.fromLeft});

  const _PositionData.fromLT({required double left, required double top})
    : fromTop = top,
      fromLeft = left;

  const _PositionData.fromRB({
    required double right,
    required double bottom,
    required double width,
    required double height,
  }) : fromTop = height - bottom,
       fromLeft = width - right;

  const _PositionData.fromLB({
    required double left,
    required double bottom,
    required double height,
  }) : fromTop = height - bottom,
       fromLeft = left;
  const _PositionData.fromRT({
    required double right,
    required double top,
    required double width,
  }) : fromTop = top,
       fromLeft = width - right;

  static _PositionData lerp(_PositionData a, _PositionData b, double t) {
    return _PositionData(
      fromTop: a.fromTop + (b.fromTop - a.fromTop) * t,
      fromLeft: a.fromLeft + (b.fromLeft - a.fromLeft) * t,
    );
  }
}

class _PositionDataTween extends Tween<_PositionData> {
  _PositionDataTween({required _PositionData begin, required _PositionData end})
    : super(begin: begin, end: end);

  @override
  _PositionData lerp(double t) => _PositionData.lerp(begin!, end!, t);
}

class _StatisticsState extends State<StatisticsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  late String expandedOne;
  late String shrinkedLeft;
  late String shrinkedRight;

  late Animation<_SizeData> expandShrinkedAnim;
  late Animation<_PositionData> moveExpandingAnimFromLeft;
  late Animation<_PositionData> moveExpandingAnimFromRight;
  late Animation<_SizeData> shrinkExpandedAnim;
  late Animation<_PositionData> moveShrinkingAnimLeft;
  late Animation<_PositionData> moveShrinkingAnimRight;
  late Animation<_PositionData> moveShrinkedAnimLeft;
  late Animation<_PositionData> moveShrinkedAnimRight;
  late Animation<_SizeData> unchangedSize;

  static const double widgetWidth = 380;
  static const double widgetHeight = 350;

  static const double expandedBarWidth = widgetWidth;
  static const double expandedBarHeight = 230;

  static const double shrinkedBarWidth = (widgetWidth - 20) / 2;
  static const double shrinkedBarHeight = 100;

  @override
  void initState() {
    super.initState();
    expandedOne = 'a';
    shrinkedLeft = 'b';
    shrinkedRight = 'c';
    const defaultCurve = Curves.easeInOut;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    expandShrinkedAnim =
        _SizeDataTween(
          begin: _SizeData(shrinkedBarWidth, shrinkedBarHeight),
          end: _SizeData(expandedBarWidth, expandedBarHeight),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    shrinkExpandedAnim =
        _SizeDataTween(
          begin: _SizeData(expandedBarWidth, expandedBarHeight),
          end: _SizeData(shrinkedBarWidth, shrinkedBarHeight),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    moveExpandingAnimFromLeft =
        _PositionDataTween(
          begin: const _PositionData.fromLB(
            left: 0,
            bottom: shrinkedBarHeight,
            height: widgetHeight,
          ),
          end: const _PositionData.fromLT(left: 0, top: 0),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    moveExpandingAnimFromRight =
        _PositionDataTween(
          begin: const _PositionData.fromRB(
            right: shrinkedBarWidth,
            bottom: shrinkedBarHeight,
            width: widgetWidth,
            height: widgetHeight,
          ),
          end: const _PositionData.fromLT(left: 0, top: 0),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    moveShrinkingAnimLeft =
        _PositionDataTween(
          begin: const _PositionData.fromLT(left: 0, top: 0),
          end: const _PositionData.fromLB(
            left: 0,
            bottom: shrinkedBarHeight,
            height: widgetHeight,
          ),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    moveShrinkingAnimRight =
        _PositionDataTween(
          begin: const _PositionData.fromLT(left: 0, top: 0),
          end: const _PositionData.fromRB(
            right: shrinkedBarWidth,
            bottom: shrinkedBarHeight,
            width: widgetWidth,
            height: widgetHeight,
          ),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    moveShrinkedAnimLeft =
        _PositionDataTween(
          begin: const _PositionData.fromRB(
            right: shrinkedBarWidth,
            bottom: shrinkedBarHeight,
            width: widgetWidth,
            height: widgetHeight,
          ),
          end: const _PositionData.fromLB(
            left: 0,
            bottom: shrinkedBarHeight,
            height: widgetHeight,
          ),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );

    moveShrinkedAnimRight =
        _PositionDataTween(
          begin: const _PositionData.fromLB(
            left: 0,
            bottom: shrinkedBarHeight,
            height: widgetHeight,
          ),
          end: const _PositionData.fromRB(
            right: shrinkedBarWidth,
            bottom: shrinkedBarHeight,
            width: widgetWidth,
            height: widgetHeight,
          ),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );
    unchangedSize =
        _SizeDataTween(
          begin: const _SizeData(shrinkedBarWidth, shrinkedBarHeight),
          end: const _SizeData(shrinkedBarWidth, shrinkedBarHeight),
        ).animate(
          CurvedAnimation(parent: _animationController, curve: defaultCurve),
        );
    setupAnimations(
      expandingLabel: "b",
      prevExpandedLabel: "a",
      positionFrom: "left",
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  late Animation<_SizeData> aSize;
  late Animation<_PositionData> aMove;

  late Animation<_SizeData> bSize;
  late Animation<_PositionData> bMove;

  late Animation<_SizeData> cSize;
  late Animation<_PositionData> cMove;

  void setupAnimations({
    required String expandingLabel,
    required String prevExpandedLabel,
    required String positionFrom,
  }) {
    if (expandingLabel == 'a') {
      aSize = expandShrinkedAnim;
      aMove = positionFrom == 'left'
          ? moveExpandingAnimFromLeft
          : moveExpandingAnimFromRight;
    } else if (expandingLabel == 'b') {
      bSize = expandShrinkedAnim;
      bMove = positionFrom == 'left'
          ? moveExpandingAnimFromLeft
          : moveExpandingAnimFromRight;
    } else if (expandingLabel == 'c') {
      cSize = expandShrinkedAnim;
      cMove = positionFrom == 'left'
          ? moveExpandingAnimFromLeft
          : moveExpandingAnimFromRight;
    }
    switch (prevExpandedLabel) {
      case 'a':
        aSize = shrinkExpandedAnim;
        aMove = positionFrom == 'left'
            ? moveShrinkingAnimRight
            : moveShrinkingAnimLeft;
        break;
      case 'b':
        bSize = shrinkExpandedAnim;
        bMove = positionFrom == 'left'
            ? moveShrinkingAnimRight
            : moveShrinkingAnimLeft;
        break;
      case 'c':
        cSize = shrinkExpandedAnim;
        cMove = positionFrom == 'left'
            ? moveShrinkingAnimRight
            : moveShrinkingAnimLeft;
        break;
    }

    if (expandingLabel != 'a' && prevExpandedLabel != 'a') {
      aSize = unchangedSize;
      aMove = positionFrom == 'left'
          ? moveShrinkedAnimLeft
          : moveShrinkedAnimRight;
    }
    if (expandingLabel != 'b' && prevExpandedLabel != 'b') {
      bSize = unchangedSize;
      bMove = positionFrom == 'left'
          ? moveShrinkedAnimLeft
          : moveShrinkedAnimRight;
    }
    if (expandingLabel != 'c' && prevExpandedLabel != 'c') {
      cSize = unchangedSize;
      cMove = positionFrom == 'left'
          ? moveShrinkedAnimLeft
          : moveShrinkedAnimRight;
    }
  }

  void expandShrinked(String label) {
    firstBuild = false;
    if (expandedOne == label) return; // Already expanded
    final position = shrinkedLeft == label ? "left" : "right";
    setupAnimations(
      expandingLabel: label,
      prevExpandedLabel: expandedOne,
      positionFrom: position,
    );
    if (position == "left") {
      shrinkedLeft = shrinkedRight;
      shrinkedRight = expandedOne;
    } else {
      shrinkedRight = shrinkedLeft;
      shrinkedLeft = expandedOne;
    }
    expandedOne = label;
    setState(() {
      _animate();
    });
  }

  void _animate() {
    _animationController.forward(from: 0.0);
  }

  static const List<StatisticsData> statisticsData = [
    StatisticsData(
      label: 'Steps',
      icon: Icons.directions_walk,
      iconColor: Color(0xFF6366F1),
      unit: 'steps',
      todayValue: '8,432',
      weeklyData: [6200, 7500, 8200, 8432, 7100, 6800, 7900],
    ),
    StatisticsData(
      label: 'Activity',
      icon: Icons.access_time,
      iconColor: Color.fromARGB(255, 106, 226, 97),
      unit: 'min',
      todayValue: '45',
      weeklyData: [30, 35, 50, 45, 40, 55, 48],
    ),
    StatisticsData(
      label: 'Mileage',
      icon: Icons.directions_run,
      iconColor: Color.fromARGB(255, 220, 81, 74),
      unit: 'km',
      todayValue: '5.5',
      weeklyData: [3.2, 4.5, 5.0, 5.5, 4.8, 3.9, 5.2],
    ),
  ];

  var firstBuild = true;

  static const _PositionData bStartPosition = _PositionData.fromLB(
    left: 0,
    bottom: shrinkedBarHeight,
    height: widgetHeight,
  );

  static const _PositionData cStartPosition = _PositionData.fromRB(
    right: shrinkedBarWidth,
    bottom: shrinkedBarHeight,
    width: widgetWidth,
    height: widgetHeight,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (_, _) {
        return Container(
          decoration: BoxDecoration(color: Colors.grey.withAlpha(150)),
          width: widgetWidth,
          height: widgetHeight,
          child: Stack(
            children: [
              Positioned(
                top: firstBuild ? 0 : aMove.value.fromTop,
                left: firstBuild ? 0 : aMove.value.fromLeft,
                width: firstBuild ? expandedBarWidth : aSize.value.width,
                height: firstBuild ? expandedBarHeight : aSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('a'),
                  child: StatsItem(data: statisticsData[0]),
                ),
              ),
              Positioned(
                top: firstBuild ? bStartPosition.fromTop : bMove.value.fromTop,
                left: firstBuild
                    ? bStartPosition.fromLeft
                    : bMove.value.fromLeft,
                width: firstBuild ? shrinkedBarWidth : bSize.value.width,
                height: firstBuild ? shrinkedBarHeight : bSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('b'),
                  child: StatsItem(data: statisticsData[1]),
                ),
              ),
              Positioned(
                top: firstBuild ? cStartPosition.fromTop : cMove.value.fromTop,
                left: firstBuild
                    ? cStartPosition.fromLeft
                    : cMove.value.fromLeft,
                width: firstBuild ? shrinkedBarWidth : cSize.value.width,
                height: firstBuild ? shrinkedBarHeight : cSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('c'),
                  child: StatsItem(data: statisticsData[2]),
                ),
              ),
              Center(
                child: Container(
                  alignment: Alignment.center,
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(color: Colors.transparent),
                  child: Column(
                    children: [
                      Text("Expanded: $expandedOne"),
                      Text("Shrinked Left: $shrinkedLeft"),
                      Text("Shrinked Right: $shrinkedRight"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    // return Column(
    //   spacing: 12,
    //   children: [
    //     // Expanded bar at top
    //     ExpandableStatisticsItem(
    //       data: expandedData,
    //       isExpanded: true,
    //       onTap: () {},
    //       animationController: _animationController,
    //     ),
    //     // Shrinked bars in a row
    //     Row(
    //       spacing: 12,
    //       children: [
    //         for (var item in shrinkedData)
    //           Expanded(
    //             child: ExpandableStatisticsItem(
    //               data: item,
    //               isExpanded: false,
    //               onTap: () => _onStatisticTapped(item.label.toLowerCase()),
    //               animationController: _animationController,
    //             ),
    //           ),
    //       ],
    //     ),
    //   ],
    // );
  }
}

class StatsItem extends StatelessWidget {
  final StatisticsData data;

  const StatsItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: data.iconColor,
        border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0),
          width: 1.5,
        ),

        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [Text(data.label), Text(data.todayValue)]),
    );
  }
}

class ExpandableStatisticsItem extends StatelessWidget {
  final StatisticsData data;
  final bool isExpanded;
  final int shrinkedPosition; // 0 for left, 1 for right
  final AnimationController animationController;

  const ExpandableStatisticsItem({
    super.key,
    required this.data,
    required this.isExpanded,

    required this.shrinkedPosition,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isExpanded ? 350 : 150,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(100),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: isExpanded ? _buildExpandedView() : _buildCollapsedView(),
    );
  }

  Widget _buildCollapsedView() {
    // Calculate progress percentage (0-100)
    final double maxValue = _getMaxValueForType();
    final double currentValue =
        double.tryParse(data.todayValue.replaceAll(',', '')) ?? 0;
    final double progressPercent = (currentValue / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.iconColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C2A3A),
                      ),
                    ),
                    Text(
                      'Today: ${data.todayValue} ${data.unit}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: Colors.grey[500], size: 24),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercent,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(data.iconColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progressPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, color: data.iconColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C2A3A),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: data.todayValue,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: data.iconColor,
                              ),
                            ),
                            TextSpan(
                              text: ' ${data.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_less, color: Colors.grey[500], size: 28),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Weekly Overview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: _buildChart(),
            ),
            const SizedBox(height: 12),
            _buildWeeklyStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final double maxValue =
        data.weeklyData.reduce((a, b) => a > b ? a : b) * 1.2;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.grey[200], strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  const days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  if (value.toInt() < days.length) {
                    return Text(
                      days[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            data.weeklyData.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data.weeklyData[index],
                  color: data.iconColor,
                  width: 12,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          minY: 0,
          maxY: maxValue,
        ),
      ),
    );
  }

  Widget _buildWeeklyStats() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = data.weeklyData.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Avg: ${(data.weeklyData.reduce((a, b) => a + b) / data.weeklyData.length).toStringAsFixed(1)} ${data.unit}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Max: ${maxValue.toStringAsFixed(1)} ${data.unit}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  double _getMaxValueForType() {
    // Return max expected value for each type for progress calculation
    final label = data.label.toLowerCase();
    if (label == 'steps') return 20000;
    if (label == 'activity') return 120;
    if (label == 'mileage') return 10;
    return 100;
  }
}
