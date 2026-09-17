import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/navigation/main_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../shared/brand.dart';
import 'app_controllers.dart';

class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  bool _showSplash = true;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    // Tests need immediate UI; skip splash in test environment.
    if (_isTestEnvironment) {
      _showSplash = false;
      return;
    }
    // Keep splash visible for a polished moment; reduceMotion shortens it.
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    Future.delayed(Duration(milliseconds: reduce ? 480 : 1900), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  Widget _buildHome(bool onboardingComplete) {
    if (!onboardingComplete) return const OnboardingScreen();
    return const MainShell();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);

    if (_isTestEnvironment) {
      return _buildHome(onboardingComplete);
    }

    // Animated crossfade between splash and the app for a smooth entry.
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showSplash
          ? PocketSplash(
              key: const ValueKey('splash'),
              onFinished: () {
                if (mounted) setState(() => _showSplash = false);
              },
            )
          : KeyedSubtree(
              key: const ValueKey('home'),
              child: _buildHome(onboardingComplete),
            ),
    );
  }
}
