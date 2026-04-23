import 'package:flutter/material.dart';

class PlannerWidget extends StatelessWidget {
  const PlannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.blueGrey[50],
      child: const Center(
        child: Text(
          'Planner Widget Placeholder',
          style: TextStyle(fontSize: 18, color: Colors.blueGrey),
        ),
      ),
    );
  }
}
