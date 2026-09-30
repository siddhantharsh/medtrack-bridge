import 'package:flutter/material.dart';

import '../models/dose_event.dart';
import '../theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      DoseStatus.pending => (
          const Color(0xFFFDF0DC),
          const Color(0xFF9A6A1A),
          'Pending',
        ),
      DoseStatus.dispensed => (
          const Color(0xFFE2F2FF),
          const Color(0xFF1B6FA8),
          'Dispensed',
        ),
      DoseStatus.collected => (
          const Color(0xFFD9F5EC),
          const Color(0xFF027A5F),
          'Collected',
        ),
      DoseStatus.missed => (const Color(0xFFFBE4E4), missedRed, 'Missed'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
