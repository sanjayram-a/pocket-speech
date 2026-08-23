import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../generation/generate_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../voices/voices_screen.dart';

enum MainDestination { generate, voices, history, settings }

class MainDestinationController extends Notifier<MainDestination> {
  @override
  MainDestination build() => MainDestination.generate;

  void select(int index) => state = MainDestination.values[index];
}

final mainDestinationProvider =
    NotifierProvider<MainDestinationController, MainDestination>(
      MainDestinationController.new,
    );

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    GenerateScreen(),
    VoicesScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(mainDestinationProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: destination.index, children: _screens),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: context.shapes.navBar,
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: destination.index,
          onDestinationSelected: ref
              .read(mainDestinationProvider.notifier)
              .select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.graphic_eq_outlined),
              selectedIcon: Icon(Icons.graphic_eq),
              label: 'Generate',
            ),
            NavigationDestination(
              icon: Icon(Icons.record_voice_over_outlined),
              selectedIcon: Icon(Icons.record_voice_over),
              label: 'Voices',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
