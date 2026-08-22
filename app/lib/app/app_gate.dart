import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/navigation/main_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/subscription/pro_preview_screen.dart';
import 'app_controllers.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final auth = ref.watch(authControllerProvider);
    final proPreviewComplete = ref.watch(proPreviewCompleteProvider);

    if (!onboardingComplete) return const OnboardingScreen();
    if (auth.user == null) return const SignInScreen();
    if (!proPreviewComplete) return const ProPreviewScreen();
    return const MainShell();
  }
}
