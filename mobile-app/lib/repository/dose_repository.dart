import 'package:flutter/foundation.dart';

import '../models/compartment.dart';
import '../models/dose_event.dart';

/// Separates the UI from where dose data actually lives — in-memory locally
/// via [LocalDoseRepository], or on the laptop bridge server via
/// [RemoteDoseRepository]. Screens depend only on this interface.
abstract class DoseRepository extends ChangeNotifier {
  List<Compartment> get compartments;

  /// All past dose events, newest first.
  List<DoseEvent> get history;

  /// Today's most recent event for [compartmentId], if any.
  DoseEvent? latestEventFor(int compartmentId);

  Future<void> loadAll();

  Future<Compartment> upsertCompartment(Compartment compartment);

  /// Triggers a dispense for [compartmentId] ("Simulate dispense" on Home).
  Future<DoseEvent> dispense(int compartmentId);

  /// Manually marks the most recent dispensed dose for [compartmentId] as
  /// collected — stands in for the IR sensor, which isn't built yet.
  Future<DoseEvent> collect(int compartmentId);
}
