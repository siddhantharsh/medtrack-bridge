import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compartment.dart';
import '../models/dose_event.dart';
import '../repository/dose_repository.dart';
import '../widgets/status_pill.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  double _sevenDayAdherence(List<DoseEvent> history) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = history.where((e) {
      final date = DateTime.tryParse(e.date);
      return date != null && date.isAfter(cutoff);
    }).toList();

    if (recent.isEmpty) return 0;
    final collected =
        recent.where((e) => e.status == DoseStatus.collected).length;
    return collected / recent.length;
  }

  String _labelFor(List<Compartment> compartments, int compartmentId) {
    for (final c in compartments) {
      if (c.id == compartmentId) return c.label;
    }
    return 'Compartment $compartmentId';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DoseRepository>();
    final adherence = _sevenDayAdherence(repo.history);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('7-day adherence'),
                  Text(
                    '${(adherence * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final event in repo.history)
            Card(
              child: ListTile(
                title: Text(_labelFor(repo.compartments, event.compartmentId)),
                subtitle: Text(
                  '${event.date} · updated ${event.updatedAt.toLocal().hour.toString().padLeft(2, '0')}:${event.updatedAt.toLocal().minute.toString().padLeft(2, '0')}',
                ),
                trailing: StatusPill(status: event.status),
              ),
            ),
          if (repo.history.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No events yet.')),
            ),
        ],
      ),
    );
  }
}
