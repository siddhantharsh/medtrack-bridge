import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/compartment.dart';
import '../models/dose_event.dart';
import '../services/connection_settings.dart';
import 'dose_repository.dart';

/// Talks to the laptop bridge server over HTTP for compartments/history/
/// dispense/collect, and subscribes to its WebSocket for live
/// dispensed/done/collected/missed pushes, so the UI updates in real time
/// without polling.
class RemoteDoseRepository extends DoseRepository {
  RemoteDoseRepository(this.settings) {
    _connectSocket();
  }

  final ConnectionSettings settings;

  final List<Compartment> _compartments = [];
  final List<DoseEvent> _history = [];

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _disposed = false;

  @override
  List<Compartment> get compartments => List.unmodifiable(_compartments);

  @override
  List<DoseEvent> get history => List.unmodifiable(_history.reversed);

  @override
  DoseEvent? latestEventFor(int compartmentId) {
    for (final event in _history.reversed) {
      if (event.compartmentId == compartmentId) return event;
    }
    return null;
  }

  /// Pings GET /api/compartments to confirm the bridge server is reachable.
  /// Used by the "Test connection" button in Settings.
  Future<bool> testConnection() async {
    try {
      final res = await http
          .get(settings.httpBase().replace(path: '/api/compartments'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> loadAll() async {
    final base = settings.httpBase();
    final compartmentsRes =
        await http.get(base.replace(path: '/api/compartments'));
    final historyRes = await http.get(base.replace(path: '/api/history'));

    if (compartmentsRes.statusCode == 200) {
      final list = jsonDecode(compartmentsRes.body) as List;
      _compartments
        ..clear()
        ..addAll(
          list.map((e) => Compartment.fromJson(e as Map<String, dynamic>)),
        );
    }

    if (historyRes.statusCode == 200) {
      final list = jsonDecode(historyRes.body) as List;
      final parsed =
          list.map((e) => DoseEvent.fromJson(e as Map<String, dynamic>));
      _history
        ..clear()
        ..addAll(parsed.toList().reversed);
    }

    notifyListeners();
  }

  @override
  Future<Compartment> upsertCompartment(Compartment compartment) async {
    final res = await http.post(
      settings.httpBase().replace(path: '/api/compartments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(compartment.toJson()),
    );
    if (res.statusCode != 200) {
      throw StateError(_errorMessage(res.body, 'Save failed'));
    }
    final updated =
        Compartment.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    final idx = _compartments.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      _compartments[idx] = updated;
    } else {
      _compartments.add(updated);
    }
    notifyListeners();
    return updated;
  }

  @override
  Future<DoseEvent> dispense(int compartmentId) async {
    final res = await http.post(
      settings.httpBase().replace(path: '/api/dispense'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'compartmentId': compartmentId}),
    );
    if (res.statusCode != 200) {
      throw StateError(_errorMessage(res.body, 'Dispense failed'));
    }
    final event =
        DoseEvent.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    _applyEvent(event);
    return event;
  }

  @override
  Future<DoseEvent> collect(int compartmentId) async {
    final res = await http.post(
      settings.httpBase().replace(path: '/api/collect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'compartmentId': compartmentId}),
    );
    if (res.statusCode != 200) {
      throw StateError(_errorMessage(res.body, 'Collect failed'));
    }
    final event =
        DoseEvent.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    _applyEvent(event);
    return event;
  }

  String _errorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['error'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  void _connectSocket() {
    if (!settings.isConfigured) return;
    try {
      _channel = WebSocketChannel.connect(settings.wsUri());
      _channel!.stream.listen(
        (raw) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          final eventJson = message['event'];
          if (eventJson != null) {
            _applyEvent(DoseEvent.fromJson(eventJson as Map<String, dynamic>));
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectSocket);
  }

  void _applyEvent(DoseEvent event) {
    final idx = _history.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      _history[idx] = event;
    } else {
      _history.add(event);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
