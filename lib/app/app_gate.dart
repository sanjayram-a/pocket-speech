import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/navigation/main_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'app_controllers.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    if (!onboardingComplete) return const OnboardingScreen();
    return const MainShell();
  }
}
