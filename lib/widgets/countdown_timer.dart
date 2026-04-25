import 'package:flutter/material.dart';
import 'dart:async';

class CountdownTimer extends StatefulWidget {
  final DateTime expiryTime;
  final VoidCallback onExpired;

  const CountdownTimer({
    super.key,
    required this.expiryTime,
    required this.onExpired,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    if (!_remainingTime.isNegative && _remainingTime != Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _calculateRemainingTime();
      });
    }
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _remainingTime = widget.expiryTime.difference(now);
    });

    if (_remainingTime.isNegative || _remainingTime == Duration.zero) {
      _timer?.cancel();
      widget.onExpired();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "Expired";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isUrgent = _remainingTime.inHours < 1;

    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 14,
          color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
        ),
        const SizedBox(width: 4),
        Text(
          "Expiry in: ${_formatDuration(_remainingTime)}",
          style: TextStyle(
            color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
