import 'package:intl/intl.dart';

import '../models/compartment.dart';
import '../models/dose_event.dart';
import 'dose_repository.dart';

/// In-memory/local-only implementation. Used until the phone is paired with
/// a laptop bridge server in Settings; simulates dispenses instantly rather
/// than driving real hardware.
class LocalDoseRepository extends DoseRepository {
  final List<Compartment> _compartments = [
    const Compartment(
      id: 1,
      label: 'Compartment 1',
      medicineName: 'Medicine A',
      time: '08:00',
    ),
    const Compartment(
      id: 2,
      label: 'Compartment 2',
      medicineName: 'Medicine B',
      time: '20:00',
    ),
  ];
  final List<DoseEvent> _history = [];
  int _nextEventId = 1;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  List<Compartment> get compartments => List.unmodifiable(_compartments);

  @override
  List<DoseEvent> get history => List.unmodifiable(_history.reversed);

  @override
  DoseEvent? latestEventFor(int compartmentId) {
    for (final event in _history.reversed) {
      if (event.compartmentId == compartmentId && event.date == _today) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<void> loadAll() async {}

  @override
  Future<Compartment> upsertCompartment(Compartment compartment) async {
    final idx = _compartments.indexWhere((c) => c.id == compartment.id);
    if (idx >= 0) {
      _compartments[idx] = compartment;
    } else {
      _compartments.add(compartment);
    }
    notifyListeners();
    return compartment;
  }

  @override
  Future<DoseEvent> dispense(int compartmentId) async {
    final event = DoseEvent(
      id: _nextEventId++,
      compartmentId: compartmentId,
      date: _today,
      status: DoseStatus.dispensed,
      updatedAt: DateTime.now(),
    );
    _history.add(event);
    notifyListeners();
    return event;
  }

  @override
  Future<DoseEvent> collect(int compartmentId) async {
    final idx = _history.lastIndexWhere(
      (e) =>
          e.compartmentId == compartmentId &&
          e.date == _today &&
          e.status == DoseStatus.dispensed,
    );
    if (idx < 0) {
      throw StateError(
        'No pending dose to collect for this compartment today',
      );
    }
    final updated = _history[idx].copyWith(
      status: DoseStatus.collected,
      updatedAt: DateTime.now(),
    );
    _history[idx] = updated;
    notifyListeners();
    return updated;
  }
}
