import 'package:shared_preferences/shared_preferences.dart';

/// Stores the laptop bridge server's IP + port that the phone connects to.
/// Backs the "Connect to laptop" field in Settings, replacing the old
/// greyed-out "Bluetooth / cloud sync — coming soon" placeholder.
class ConnectionSettings {
  const ConnectionSettings({required this.host, required this.port});

  static const _hostKey = 'bridge_host';
  static const _portKey = 'bridge_port';

  final String host;
  final int port;

  bool get isConfigured => host.isNotEmpty;

  Uri httpBase() => Uri(scheme: 'http', host: host, port: port);
  Uri wsUri() => Uri(scheme: 'ws', host: host, port: port);

  static Future<ConnectionSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ConnectionSettings(
      host: prefs.getString(_hostKey) ?? '',
      port: prefs.getInt(_portKey) ?? 3000,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
  }
}
