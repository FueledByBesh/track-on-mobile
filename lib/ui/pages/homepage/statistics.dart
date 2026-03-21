import 'package:flutter/material.dart';

class Statistics extends StatefulWidget {
  const Statistics({super.key});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  var calories = "0";
  var dist = "0";
  var time = "0";

  _StatisticsState() {
    _init();
  }

  // gets stats data from cache and not stateful
  void _init() {
    calories = "350";
    dist = "5.5";
    time = "50";
  }

  // gets statistics data from backend and updates the state
  Future<void> refresh() async {
    // Simulate a network call to fetch statistics
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      calories = "600";
      dist = "5.5";
      time = "50";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StatisticsItem(
            icon: Icons.local_fire_department,
            iconColor: Color(0xFFFF6B6B),
            value: calories,
            unit: "kcal",
            label: "Calories",
          ),
          StatisticsItem(
            icon: Icons.directions_run,
            iconColor: Color(0xFF4ECDC4),
            value: dist,
            unit: "km",
            label: "Mileage",
          ),
          StatisticsItem(
            icon: Icons.access_time,
            iconColor: Color(0xFF95E1D3),
            value: time,
            unit: "min",
            label: "Activity",
          ),
        ],
      ),
    );
  }
}

class StatisticsItem extends StatelessWidget {
  const StatisticsItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C2A3A),
                    ),
                  ),
                  TextSpan(
                    text: " $unit",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
