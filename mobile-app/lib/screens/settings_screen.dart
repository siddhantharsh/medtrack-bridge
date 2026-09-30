import 'package:flutter/material.dart';

import '../repository/dose_repository.dart';
import '../repository/remote_dose_repository.dart';
import '../services/connection_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onRepositoryChanged});

  final ValueChanged<DoseRepository> onRepositoryChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3000');
  bool _testing = false;
  String? _resultMessage;
  bool? _resultOk;

  @override
  void initState() {
    super.initState();
    ConnectionSettings.load().then((settings) {
      if (!mounted) return;
      _hostController.text = settings.host;
      _portController.text = settings.port.toString();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  ConnectionSettings get _draftSettings => ConnectionSettings(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 3000,
      );

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _resultMessage = null;
    });

    final settings = _draftSettings;
    final probe = RemoteDoseRepository(settings);
    final ok = await probe.testConnection();
    probe.dispose();

    if (!mounted) return;
    setState(() {
      _testing = false;
      _resultOk = ok;
      _resultMessage = ok
          ? 'Connected to the bridge server.'
          : 'Could not reach the bridge server at ${settings.host}:${settings.port}.';
    });
  }

  Future<void> _save() async {
    final settings = _draftSettings;
    await settings.save();
    widget.onRepositoryChanged(RemoteDoseRepository(settings));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connected to laptop bridge server.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Connect to laptop',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the IP address shown by the bridge server on your laptop '
            '(phone and laptop must be on the same WiFi network).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Laptop IP address',
              hintText: '192.168.1.42',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test connection'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save & connect'),
                ),
              ),
            ],
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _resultMessage!,
              style: TextStyle(
                color: _resultOk == true
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
