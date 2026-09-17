import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controllers.dart';
import 'app_gate.dart';
import 'app_theme.dart';

class PocketSpeechApp extends ConsumerWidget {
  const PocketSpeechApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePreferenceProvider);
    return MaterialApp(
      title: 'Pocket Speech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      home: const AppGate(),
    );
  }
}
