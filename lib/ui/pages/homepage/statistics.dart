import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

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
  final List<double> weeklyData; // 7 days of data

  const StatisticsData({
    required this.type,
    required this.todayValue,
    required this.weeklyData,
  });
}

class PreparedItemData {
  // final String expandedDisplayValue;
  final StatsItemType type;
  final String collapsedDisplayValue;

  const PreparedItemData({
    // required this.progressText,
    // required this.expandedDisplayValue,
    required this.type,
    required this.collapsedDisplayValue,
  });

  factory PreparedItemData.from(StatisticsData data) {
    final String collapsedValue = _formatDisplayValue(data);

    return PreparedItemData(
      type: data.type,
      collapsedDisplayValue: collapsedValue,
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
      if (value > 60) {
        return '${(value / 60).toStringAsFixed(1)} hrs';
      }
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

class StatisticsWidget extends StatelessWidget {
  const StatisticsWidget({super.key});
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
          ),
        );
      },
    );
  }
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

class StatisticsContainer extends StatefulWidget {
  final double widgetWidth;
  final double widgetHeight;
  final ViewType viewType;
  final double expandedBarWidth;
  final double expandedBarHeight;
  final double shrinkedBarWidth;
  final double shrinkedBarHeight;
  static const double padding = 10;

  //bars positions;
  final Offset expandedBarPosition = const Offset(0, 0);
  late final Offset shrinkedFirstBarPosition;
  late final Offset shrinkedSecondBarPosition;

  StatisticsContainer({
    super.key,
    required this.widgetWidth,
    required this.widgetHeight,
    required this.viewType,
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
  State<StatisticsContainer> createState() => _StatisticsContainer();
}

class _StatisticsContainer extends State<StatisticsContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late CurvedAnimation _animationCurve;

  late String expanded;
  late String shrinkedFirst;
  late String shrinkedSecond;

  late Animation<_SizeData> expandShrinkedAnim;
  late Animation<Offset> moveExpandingAnimFromFirst;
  late Animation<Offset> moveExpandingAnimFromSecond;
  late Animation<_SizeData> shrinkExpandedAnim;
  late Animation<Offset> moveShrinkingAnimFirst;
  late Animation<Offset> moveShrinkingAnimSecond;
  late Animation<Offset> moveShrinkedAnimFirst;
  late Animation<Offset> moveShrinkedAnimSecond;
  late Animation<_SizeData> unchangedSize;

  late List<StatisticsData> _statsData;
  late List<PreparedItemData> _preparedData;
  @override
  void initState() {
    super.initState();
    initData();
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
    // setupPositionsAndSizes();
  }

  void initData() {
    _statsData = [
      StatisticsData(
        type: StatsItemType.steps,
        todayValue: '11539',
        weeklyData: [6200, 7500, 8200, 8432, 7100, 6800, 7900],
      ),
      StatisticsData(
        type: StatsItemType.activity,
        todayValue: '45',
        weeklyData: [30, 35, 50, 45, 40, 55, 48],
      ),
      StatisticsData(
        type: StatsItemType.mileage,
        todayValue: '5.5',
        weeklyData: [3.2, 4.5, 5.0, 5.5, 4.8, 3.9, 5.2],
      ),
    ];

    _preparedData = _statsData
        .map((data) => PreparedItemData.from(data))
        .toList();
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

  late Animation<_SizeData> aSize;
  late Animation<Offset> aMove;

  late Animation<_SizeData> bSize;
  late Animation<Offset> bMove;

  late Animation<_SizeData> cSize;
  late Animation<Offset> cMove;

  void refreshData() {
    setState(() {
      // Trigger rebuild to reflect any data changes
    });
  }

  void setupAnimations({
    required String expandingLabel,
    required String prevExpandedLabel,
    required String positionFrom,
  }) {
    if (expandingLabel == 'a') {
      aSize = expandShrinkedAnim;
      aMove = positionFrom == 'first'
          ? moveExpandingAnimFromFirst
          : moveExpandingAnimFromSecond;
    } else if (expandingLabel == 'b') {
      bSize = expandShrinkedAnim;
      bMove = positionFrom == 'first'
          ? moveExpandingAnimFromFirst
          : moveExpandingAnimFromSecond;
    } else if (expandingLabel == 'c') {
      cSize = expandShrinkedAnim;
      cMove = positionFrom == 'first'
          ? moveExpandingAnimFromFirst
          : moveExpandingAnimFromSecond;
    }

    switch (prevExpandedLabel) {
      case 'a':
        aSize = shrinkExpandedAnim;
        aMove = positionFrom == 'first'
            ? moveShrinkingAnimSecond
            : moveShrinkingAnimFirst;
        break;
      case 'b':
        bSize = shrinkExpandedAnim;
        bMove = positionFrom == 'first'
            ? moveShrinkingAnimSecond
            : moveShrinkingAnimFirst;
        break;
      case 'c':
        cSize = shrinkExpandedAnim;
        cMove = positionFrom == 'first'
            ? moveShrinkingAnimSecond
            : moveShrinkingAnimFirst;
        break;
    }

    if (expandingLabel != 'a' && prevExpandedLabel != 'a') {
      aSize = unchangedSize;
      aMove = positionFrom == 'first'
          ? moveShrinkedAnimFirst
          : moveShrinkedAnimSecond;
    }
    if (expandingLabel != 'b' && prevExpandedLabel != 'b') {
      bSize = unchangedSize;
      bMove = positionFrom == 'first'
          ? moveShrinkedAnimFirst
          : moveShrinkedAnimSecond;
    }
    if (expandingLabel != 'c' && prevExpandedLabel != 'c') {
      cSize = unchangedSize;
      cMove = positionFrom == 'first'
          ? moveShrinkedAnimFirst
          : moveShrinkedAnimSecond;
    }
  }

  void expandShrinked(String label) {
    if (expanded == label) return; // Already expanded
    final position = shrinkedFirst == label ? "first" : "second";
    setupAnimations(
      expandingLabel: label,
      prevExpandedLabel: expanded,
      positionFrom: position,
    );
    if (position == "first") {
      shrinkedFirst = shrinkedSecond;
      shrinkedSecond = expanded;
    } else {
      shrinkedSecond = shrinkedFirst;
      shrinkedFirst = expanded;
    }
    expanded = label;
    _animate();
  }

  void _animate() {
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
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
                top: aMove.value.dy,
                left: aMove.value.dx,
                width: aSize.value.width,
                height: aSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('a'),
                  child: StatsItem(
                    data: _preparedData[0],
                    isExpanded: expanded == 'a',
                  ),
                ),
              ),
              Positioned(
                top: bMove.value.dy,
                left: bMove.value.dx,
                width: bSize.value.width,
                height: bSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('b'),
                  child: StatsItem(
                    data: _preparedData[1],
                    isExpanded: expanded == 'b',
                  ),
                ),
              ),
              Positioned(
                top: cMove.value.dy,
                left: cMove.value.dx,
                width: cSize.value.width,
                height: cSize.value.height,
                child: GestureDetector(
                  onTap: () => expandShrinked('c'),
                  child: StatsItem(
                    data: _preparedData[2],
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

class StatsItem extends StatelessWidget {
  final PreparedItemData data;
  final bool isExpanded;

  const StatsItem({super.key, required this.data, required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0),
          width: 1.5,
        ),

        borderRadius: BorderRadius.circular(12),
      ),
      child: isExpanded
          ? _buildExpandedView(context)
          : _buildCollapsedView(context),
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    return Column(children: [Text("Not Implemented")]);
  }

  Widget _buildCollapsedView(BuildContext context) {
    Color color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            child: Icon(data.type.icon, color: color, size: 28),
          ),
          Text(
            data.collapsedDisplayValue,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          Text(
            data.type.label,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 83, 83, 83),
            ),
          ),
        ],
      ),
    );
  }
}

// class ExpandableStatisticsItem extends StatelessWidget {
//   final StatisticsData data;
//   final PreparedItemData prepared;
//   final bool isExpanded;

//   const ExpandableStatisticsItem({
//     super.key,
//     required this.data,
//     required this.prepared,
//     required this.isExpanded,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withAlpha(100),
//             spreadRadius: 1,
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: isExpanded ? _buildExpandedView() : _buildCollapsedView(),
//     );
//   }

//   Widget _buildCollapsedView() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: data.iconColor.withAlpha(30),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(data.icon, color: data.iconColor, size: 24),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       data.label,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Color(0xFF1C2A3A),
//                       ),
//                     ),
//                     Text(
//                       '${prepared.displayValue} ${data.unit}',
//                       style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(4),
//                 child: LinearProgressIndicator(
//                   value: prepared.progressPercent,
//                   minHeight: 6,
//                   backgroundColor: Colors.grey[200],
//                   valueColor: AlwaysStoppedAnimation<Color>(data.iconColor),
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 prepared.progressText,
//                 style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildExpandedView() {
//     return Padding(
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: data.iconColor.withAlpha(30),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(data.icon, color: data.iconColor, size: 24),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       data.label,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFF1C2A3A),
//                       ),
//                     ),
//                     RichText(
//                       text: TextSpan(
//                         children: [
//                           TextSpan(
//                             text: data.todayValue,
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: data.iconColor,
//                             ),
//                           ),
//                           TextSpan(
//                             text: ' ${data.unit}',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: Icon(
//                   Icons.open_in_new,
//                   color: Colors.grey[500],
//                   size: 24,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'Weekly Overview',
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey[700],
//             ),
//           ),
//           const SizedBox(height: 8),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Flexible(
//                 child: Text(
//                   'Avg: ${prepared.avgText}',
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Flexible(
//                 child: Text(
//                   'Max: ${prepared.maxText}',
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
