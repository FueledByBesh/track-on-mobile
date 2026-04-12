import 'package:flutter/material.dart';

/// Bottom controls: history button, play/pause/resume/stop, my-location button.
class RunControls extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onShowHistory;
  final VoidCallback onMyLocation;

  const RunControls({
    super.key,
    required this.isTracking,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onShowHistory,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SmallButton(icon: Icons.history, onTap: onShowHistory),
            _BigPrimaryButton(
              isTracking: isTracking,
              isPaused: isPaused,
              onStart: onStart,
              onPause: onPause,
              onResume: onResume,
            ),
            _SmallButton(icon: Icons.my_location, onTap: onMyLocation),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              if (!isTracking) {
                onStart();
              } else {
                onStop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isTracking
                  ? Colors.red.shade600
                  : const Color(0xFF6B5FFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isTracking ? 'Finish Run' : 'Start',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _BigPrimaryButton extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const _BigPrimaryButton({
    required this.isTracking,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final VoidCallback onTap;

    if (!isTracking) {
      icon = Icons.play_arrow;
      color = const Color(0xFF6B5FFF);
      onTap = onStart;
    } else if (isPaused) {
      icon = Icons.play_arrow;
      color = Colors.green;
      onTap = onResume;
    } else {
      icon = Icons.pause;
      color = Colors.orange;
      onTap = onPause;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(150),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}
