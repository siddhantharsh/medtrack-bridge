import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repository/dose_repository.dart';
import '../widgets/compartment_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<DoseRepository>().loadAll().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _simulateDispense(int compartmentId) async {
    try {
      await context.read<DoseRepository>().dispense(compartmentId);
    } catch (err) {
      _showError(err);
    }
  }

  Future<void> _markCollected(int compartmentId) async {
    try {
      await context.read<DoseRepository>().collect(compartmentId);
    } catch (err) {
      _showError(err);
    }
  }

  void _showError(Object err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$err')));
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DoseRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: repo.loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final compartment in repo.compartments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CompartmentCard(
                        compartment: compartment,
                        event: repo.latestEventFor(compartment.id),
                        onSimulateDispense: () =>
                            _simulateDispense(compartment.id),
                        onMarkCollected: () => _markCollected(compartment.id),
                      ),
                    ),
                  if (repo.compartments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child:
                            Text('No compartments yet — add one in Schedule.'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
