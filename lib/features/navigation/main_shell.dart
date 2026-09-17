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
      extendBody: true,
      body: IndexedStack(index: destination.index, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            context.spacing.md,
            0,
            context.spacing.md,
            context.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant, width: 1),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: scheme.brightness == Brightness.light ? 0.10 : 0.28,
                ),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: scheme.brightness == Brightness.light ? 0.06 : 0.16,
                ),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: destination.index,
              onDestinationSelected: ref
                  .read(mainDestinationProvider.notifier)
                  .select,
              backgroundColor: Colors.transparent,
              height: 72,
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
        ),
      ),
    );
  }
}
