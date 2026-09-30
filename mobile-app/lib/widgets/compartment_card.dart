import 'package:flutter/material.dart';

import '../models/compartment.dart';
import '../models/dose_event.dart';
import 'status_pill.dart';

class CompartmentCard extends StatelessWidget {
  const CompartmentCard({
    super.key,
    required this.compartment,
    required this.event,
    required this.onSimulateDispense,
    required this.onMarkCollected,
  });

  final Compartment compartment;
  final DoseEvent? event;
  final VoidCallback onSimulateDispense;
  final VoidCallback onMarkCollected;

  @override
  Widget build(BuildContext context) {
    final status = event?.status ?? DoseStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  compartment.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              compartment.medicineName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Scheduled ${compartment.time}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSimulateDispense,
                    child: const Text('Simulate dispense'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        status == DoseStatus.dispensed ? onMarkCollected : null,
                    child: const Text('Mark collected'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
