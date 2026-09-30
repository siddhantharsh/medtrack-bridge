import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compartment.dart';
import '../repository/dose_repository.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  Future<void> _editCompartment(
    BuildContext context, {
    Compartment? existing,
  }) async {
    final repo = context.read<DoseRepository>();
    final labelController = TextEditingController(text: existing?.label ?? '');
    final medicineController =
        TextEditingController(text: existing?.medicineName ?? '');
    TimeOfDay time = existing != null
        ? TimeOfDay(
            hour: int.parse(existing.time.split(':')[0]),
            minute: int.parse(existing.time.split(':')[1]),
          )
        : TimeOfDay.now();

    final nextId = existing?.id ??
        (repo.compartments.fold<int>(0, (max, c) => c.id > max ? c.id : max) +
            1);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(existing == null ? 'Add compartment' : 'Edit compartment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              TextField(
                controller: medicineController,
                decoration: const InputDecoration(labelText: 'Medicine name'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Time: ${time.format(dialogContext)}'),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: time,
                      );
                      if (picked != null) setState(() => time = picked);
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final hh = time.hour.toString().padLeft(2, '0');
                final mm = time.minute.toString().padLeft(2, '0');
                await repo.upsertCompartment(
                  Compartment(
                    id: nextId,
                    label: labelController.text.trim(),
                    medicineName: medicineController.text.trim(),
                    time: '$hh:$mm',
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DoseRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editCompartment(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final compartment in repo.compartments)
            Card(
              child: ListTile(
                title: Text(compartment.label),
                subtitle:
                    Text('${compartment.medicineName} · ${compartment.time}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      _editCompartment(context, existing: compartment),
                ),
              ),
            ),
          if (repo.compartments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('No compartments yet — tap + to add one.'),
              ),
            ),
        ],
      ),
    );
  }
}
