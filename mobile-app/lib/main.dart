import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repository/dose_repository.dart';
import 'repository/local_dose_repository.dart';
import 'repository/remote_dose_repository.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'services/connection_settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await ConnectionSettings.load();
  final DoseRepository initialRepository = settings.isConfigured
      ? RemoteDoseRepository(settings)
      : LocalDoseRepository();
  runApp(MedTrackApp(initialRepository: initialRepository));
}

class MedTrackApp extends StatefulWidget {
  const MedTrackApp({super.key, required this.initialRepository});

  final DoseRepository initialRepository;

  @override
  State<MedTrackApp> createState() => _MedTrackAppState();
}

class _MedTrackAppState extends State<MedTrackApp> {
  late DoseRepository _repository = widget.initialRepository;

  void _swapRepository(DoseRepository repository) {
    final old = _repository;
    setState(() => _repository = repository);
    old.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DoseRepository>.value(
      value: _repository,
      child: MaterialApp(
        title: 'MedTrack',
        debugShowCheckedModeBanner: false,
        theme: buildMedTrackTheme(),
        home: _RootShell(onRepositoryChanged: _swapRepository),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell({required this.onRepositoryChanged});

  final ValueChanged<DoseRepository> onRepositoryChanged;

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const ScheduleScreen(),
      const HistoryScreen(),
      SettingsScreen(onRepositoryChanged: widget.onRepositoryChanged),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
