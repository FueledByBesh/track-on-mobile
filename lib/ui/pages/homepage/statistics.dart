import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

enum StatsItemType {
  steps(Icons.directions_walk, 'Steps'),
  activity(Icons.access_time, 'Activity Time'),
  mileage(Icons.directions_run, 'Mileage');

  final IconData icon;
  final String label;
  const StatsItemType(this.icon, this.label);
}

class StatisticsData {
  final StatsItemType type;
  final String todayValue;
  final List<double> weeklyData; // 7 values, oldest first, today last
  final List<String> dayLabels;  // 7 labels matching weeklyData
  final int? goal; // step goal — used for the ring on the steps card

  const StatisticsData({
    required this.type,
    required this.todayValue,
    required this.weeklyData,
    required this.dayLabels,
    this.goal,
  });
}

class PreparedItemData {
  final StatsItemType type;
  final String collapsedDisplayValue;

  const PreparedItemData({
    required this.type,
    required this.collapsedDisplayValue,
  });

  factory PreparedItemData.from(StatisticsData data) {
    return PreparedItemData(
      type: data.type,
      collapsedDisplayValue: _formatDisplayValue(data),
    );
  }

  static String _formatDisplayValue(StatisticsData data) {
    if (data.type == StatsItemType.steps) {
      final value = int.tryParse(data.todayValue) ?? 0;
      if (value > 10000) return '${(value / 1000).toStringAsFixed(1)}k';
      return NumberFormat('#,###').format(value);
    }
    if (data.type == StatsItemType.activity) {
      final value = double.tryParse(data.todayValue) ?? 0.0;
      if (value > 60) return '${(value / 60).toStringAsFixed(1)} hrs';
      return '${value.toStringAsFixed(0)} mins';
    }
    if (data.type == StatsItemType.mileage) {
      final value = double.tryParse(data.todayValue) ?? 0.0;
      return '${value.toStringAsFixed(1)} km';
    }
    return data.todayValue;
  }
}

enum ViewType {
  phone(400, 500),
  tablet(300, 900),
  desktop(300, 900);

  final double height;
  final double maxWidth;
  const ViewType(this.height, this.maxWidth);
  static ViewType fromWidth(double width) {
    if (width < 500) return ViewType.phone;
    if (width < 900) return ViewType.tablet;
    return ViewType.desktop;
  }
}

/// Pure display widget — receives data, doesn't access providers.
class StatisticsWidget extends StatelessWidget {
  final List<StatisticsData> data;
  final VoidCallback? onRefresh;
  final bool isSyncing;

  const StatisticsWidget({
    super.key,
    required this.data,
    this.onRefresh,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        ViewType viewType = ViewType.fromWidth(constraints.maxWidth);
        return SizedBox(
          width: math.min(constraints.maxWidth, viewType.maxWidth),
          height: viewType.height,
          child: StatisticsContainer(
            widgetWidth: math.min(constraints.maxWidth, viewType.maxWidth),
            widgetHeight: viewType.height,
            viewType: viewType,
            data: data,
            onRefresh: onRefresh,
            isSyncing: isSyncing,
          ),
        );
      },
    );
  }
}

// ============ SIZE ANIMATION HELPERS ============

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

// ============ CONTAINER (animation + layout) ============

class StatisticsContainer extends StatefulWidget {
  final double widgetWidth;
  final double widgetHeight;
  final ViewType viewType;
  final List<StatisticsData> data;
  final VoidCallback? onRefresh;
  final bool isSyncing;

  final double expandedBarWidth;
  final double expandedBarHeight;
  final double shrinkedBarWidth;
  final double shrinkedBarHeight;
  static const double padding = 10;

  final Offset expandedBarPosition = const Offset(0, 0);
  late final Offset shrinkedFirstBarPosition;
  late final Offset shrinkedSecondBarPosition;

  StatisticsContainer({
    super.key,
    required this.widgetWidth,
    required this.widgetHeight,
    required this.viewType,
    required this.data,
    this.onRefresh,
    this.isSyncing = false,
  }) : expandedBarWidth = (viewType == ViewType.phone)
           ? widgetWidth
           : (widgetWidth - padding) * 0.7,
       expandedBarHeight = (viewType == ViewType.phone)
           ? (widgetHeight - padding) * 0.7
           : widgetHeight,
       shrinkedBarWidth = (viewType == ViewType.phone)
           ? (widgetWidth - padding) / 2
           : (widgetWidth - padding) * 0.3,
       shrinkedBarHeight = (viewType == ViewType.phone)
           ? (widgetHeight - padding) * 0.3
           : (widgetHeight - padding) / 2 {
    shrinkedFirstBarPosition = (viewType == ViewType.phone)
        ? Offset(0, expandedBarHeight + padding)
        : Offset(expandedBarWidth + padding, 0);
    shrinkedSecondBarPosition = (viewType == ViewType.phone)
        ? Offset(shrinkedBarWidth + padding, expandedBarHeight + padding)
        : Offset(expandedBarWidth + padding, shrinkedBarHeight + padding);
  }

  @override
  State<StatisticsContainer> createState() => _StatisticsContainerState();
}

class _StatisticsContainerState extends State<StatisticsContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late CurvedAnimation _animationCurve;

  late String expanded;
  late String shrinkedFirst;
  late String shrinkedSecond;

  late Animation<_SizeData> expandShrinkedAnim;
  late Animation<_SizeData> shrinkExpandedAnim;
  late Animation<Offset> moveExpandingAnimFromFirst;
  late Animation<Offset> moveExpandingAnimFromSecond;
  late Animation<Offset> moveShrinkingAnimFirst;
  late Animation<Offset> moveShrinkingAnimSecond;
  late Animation<Offset> moveShrinkedAnimFirst;
  late Animation<Offset> moveShrinkedAnimSecond;
  late Animation<_SizeData> unchangedSize;

  late Animation<_SizeData> aSize;
  late Animation<Offset> aMove;
  late Animation<_SizeData> bSize;
  late Animation<Offset> bMove;
  late Animation<_SizeData> cSize;
  late Animation<Offset> cMove;

  @override
  void initState() {
    super.initState();
    expanded = 'a';
    shrinkedFirst = 'b';
    shrinkedSecond = 'c';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationCurve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _initializeAnimations();
    setupAnimations(
      expandingLabel: shrinkedSecond,
      prevExpandedLabel: expanded,
      positionFrom: "second",
    );
  }

  @override
  void didUpdateWidget(covariant StatisticsContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeAnimations();
    setupAnimations(
      expandingLabel: shrinkedSecond,
      prevExpandedLabel: expanded,
      positionFrom: "second",
    );
    _animationController.value = 0.0;
  }

  void _initializeAnimations() {
    expandShrinkedAnim = _SizeDataTween(
      begin: _SizeData(widget.shrinkedBarWidth, widget.shrinkedBarHeight),
      end: _SizeData(widget.expandedBarWidth, widget.expandedBarHeight),
    ).animate(_animationCurve);

    shrinkExpandedAnim = _SizeDataTween(
      begin: _SizeData(widget.expandedBarWidth, widget.expandedBarHeight),
      end: _SizeData(widget.shrinkedBarWidth, widget.shrinkedBarHeight),
    ).animate(_animationCurve);

    moveExpandingAnimFromFirst = Tween<Offset>(
      begin: widget.shrinkedFirstBarPosition,
      end: widget.expandedBarPosition,
    ).animate(_animationCurve);

    moveExpandingAnimFromSecond = Tween<Offset>(
      begin: widget.shrinkedSecondBarPosition,
      end: widget.expandedBarPosition,
    ).animate(_animationCurve);

    moveShrinkingAnimFirst = Tween<Offset>(
      begin: widget.expandedBarPosition,
      end: widget.shrinkedFirstBarPosition,
    ).animate(_animationCurve);

    moveShrinkingAnimSecond = Tween<Offset>(
      begin: widget.expandedBarPosition,
      end: widget.shrinkedSecondBarPosition,
    ).animate(_animationCurve);

    moveShrinkedAnimFirst = Tween<Offset>(
      begin: widget.shrinkedSecondBarPosition,
      end: widget.shrinkedFirstBarPosition,
    ).animate(_animationCurve);

    moveShrinkedAnimSecond = Tween<Offset>(
      begin: widget.shrinkedFirstBarPosition,
      end: widget.shrinkedSecondBarPosition,
    ).animate(_animationCurve);

    unchangedSize = _SizeDataTween(
      begin: _SizeData(widget.shrinkedBarWidth, widget.shrinkedBarHeight),
      end: _SizeData(widget.shrinkedBarWidth, widget.shrinkedBarHeight),
    ).animate(_animationCurve);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _animationCurve.dispose();
    super.dispose();
  }

  void setupAnimations({
    required String expandingLabel,
    required String prevExpandedLabel,
    required String positionFrom,
  }) {
    if (expandingLabel == 'a') {
      aSize = expandShrinkedAnim;
      aMove = positionFrom == 'first' ? moveExpandingAnimFromFirst : moveExpandingAnimFromSecond;
    } else if (expandingLabel == 'b') {
      bSize = expandShrinkedAnim;
      bMove = positionFrom == 'first' ? moveExpandingAnimFromFirst : moveExpandingAnimFromSecond;
    } else if (expandingLabel == 'c') {
      cSize = expandShrinkedAnim;
      cMove = positionFrom == 'first' ? moveExpandingAnimFromFirst : moveExpandingAnimFromSecond;
    }

    switch (prevExpandedLabel) {
      case 'a':
        aSize = shrinkExpandedAnim;
        aMove = positionFrom == 'first' ? moveShrinkingAnimSecond : moveShrinkingAnimFirst;
        break;
      case 'b':
        bSize = shrinkExpandedAnim;
        bMove = positionFrom == 'first' ? moveShrinkingAnimSecond : moveShrinkingAnimFirst;
        break;
      case 'c':
        cSize = shrinkExpandedAnim;
        cMove = positionFrom == 'first' ? moveShrinkingAnimSecond : moveShrinkingAnimFirst;
        break;
    }

    if (expandingLabel != 'a' && prevExpandedLabel != 'a') {
      aSize = unchangedSize;
      aMove = positionFrom == 'first' ? moveShrinkedAnimFirst : moveShrinkedAnimSecond;
    }
    if (expandingLabel != 'b' && prevExpandedLabel != 'b') {
      bSize = unchangedSize;
      bMove = positionFrom == 'first' ? moveShrinkedAnimFirst : moveShrinkedAnimSecond;
    }
    if (expandingLabel != 'c' && prevExpandedLabel != 'c') {
      cSize = unchangedSize;
      cMove = positionFrom == 'first' ? moveShrinkedAnimFirst : moveShrinkedAnimSecond;
    }
  }

  void expandShrinked(String label) {
    if (expanded == label) return;
    final position = shrinkedFirst == label ? "first" : "second";
    setupAnimations(expandingLabel: label, prevExpandedLabel: expanded, positionFrom: position);
    if (position == "first") {
      shrinkedFirst = shrinkedSecond;
      shrinkedSecond = expanded;
    } else {
      shrinkedSecond = shrinkedFirst;
      shrinkedFirst = expanded;
    }
    expanded = label;
    _animationController.forward(from: 0.0);
  }

  List<PreparedItemData> get _preparedData =>
      widget.data.map((d) => PreparedItemData.from(d)).toList();

  @override
  Widget build(BuildContext context) {
    final prepared = _preparedData;
    if (prepared.length < 3) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (_, _) {
        return SizedBox(
          width: widget.widgetWidth,
          height: widget.widgetHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: aMove.value.dy, left: aMove.value.dx,
                width: aSize.value.width, height: aSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('a'),
                  child: StatsItem(
                    data: prepared[0],
                    weeklyData: widget.data[0].weeklyData,
                    dayLabels: widget.data[0].dayLabels,
                    goal: widget.data[0].goal,
                    isExpanded: expanded == 'a',
                    onRefresh: widget.onRefresh,
                    isSyncing: widget.isSyncing,
                  ),
                ),
              ),
              Positioned(
                top: bMove.value.dy, left: bMove.value.dx,
                width: bSize.value.width, height: bSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('b'),
                  child: StatsItem(
                    data: prepared[1],
                    weeklyData: widget.data[1].weeklyData,
                    dayLabels: widget.data[1].dayLabels,
                    goal: widget.data[1].goal,
                    isExpanded: expanded == 'b',
                  ),
                ),
              ),
              Positioned(
                top: cMove.value.dy, left: cMove.value.dx,
                width: cSize.value.width, height: cSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('c'),
                  child: StatsItem(
                    data: prepared[2],
                    weeklyData: widget.data[2].weeklyData,
                    dayLabels: widget.data[2].dayLabels,
                    goal: widget.data[2].goal,
                    isExpanded: expanded == 'c',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


// ============ INDIVIDUAL BAR (gradient-styled) ============

class StatsItem extends StatelessWidget {
  final PreparedItemData data;
  final List<double> weeklyData;
  final List<String> dayLabels;
  final int? goal;
  final bool isExpanded;
  final VoidCallback? onRefresh;
  final bool isSyncing;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B5FFF), Color(0xFF8B7FFF)],
  );

  const StatsItem({
    super.key,
    required this.data,
    required this.weeklyData,
    required this.dayLabels,
    required this.isExpanded,
    this.goal,
    this.onRefresh,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5FFF).withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isExpanded
          ? _buildExpandedView(context)
          : _buildCollapsedView(context),
    );
  }

  // ─── EXPANDED: gradient bg + white bar chart ───

  Widget _buildExpandedView(BuildContext context) {
    final maxY = weeklyData.isEmpty
        ? 1.0
        : weeklyData.reduce((a, b) => a > b ? a : b);
    final goalY = (goal != null && goal! > 0) ? goal!.toDouble() : null;
    final chartMaxY = math.max(maxY, goalY ?? 0) * 1.15;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.type.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                    Text(
                      data.collapsedDisplayValue,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                GestureDetector(
                  onTap: isSyncing ? null : onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.refresh,
                            color: Colors.white.withAlpha(180), size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxY > 0 ? chartMaxY : 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.white.withAlpha(20), strokeWidth: 1),
                ),
                extraLinesData: goalY != null
                    ? ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: goalY,
                          color: Colors.white.withAlpha(60),
                          strokeWidth: 1,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withAlpha(140),
                              fontWeight: FontWeight.w600,
                            ),
                            labelResolver: (_) =>
                                '${(goalY / 1000).toStringAsFixed(0)}k',
                          ),
                        ),
                      ])
                    : const ExtraLinesData(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 19,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dayLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            dayLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withAlpha(150),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(weeklyData.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weeklyData[i],
                        color: Colors.white.withAlpha(200),
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBorder: BorderSide.none,
                    getTooltipColor: (_) => Colors.white.withAlpha(220),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.toInt().toString(),
                        const TextStyle(
                          color: Color(0xFF6B5FFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── COLLAPSED: gradient bg, ring for steps, icon+number for others ───

  Widget _buildCollapsedView(BuildContext context) {
    final isSteps = data.type == StatsItemType.steps;

    if (isSteps && goal != null && goal! > 0) {
      return _buildStepsCollapsed();
    }
    return _buildGenericCollapsed();
  }

  Widget _buildStepsCollapsed() {
    final todayValue = int.tryParse(data.collapsedDisplayValue.replaceAll(',', '').replaceAll('k', '000')) ?? 0;
    final progress = goal! > 0 ? (todayValue / goal!).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _MiniRingPainter(
                    progress: progress,
                    strokeWidth: 6,
                    trackColor: Colors.white.withAlpha(35),
                    progressColor: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      data.collapsedDisplayValue,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.type.label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericCollapsed() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.type.icon, color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(
            data.collapsedDisplayValue,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.type.label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ MINI RING PAINTER ============

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  _MiniRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter old) =>
      old.progress != progress;
}
