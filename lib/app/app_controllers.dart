import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

const _themeModeKey = 'theme_mode';
const _onboardingKey = 'onboarding_v2_complete';

class ThemePreferenceController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(appPreferencesProvider).getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(appPreferencesProvider).setString(_themeModeKey, mode.name);
  }
}

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, ThemeMode>(
      ThemePreferenceController.new,
    );

class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(appPreferencesProvider).getBool(_onboardingKey) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(appPreferencesProvider).setBool(_onboardingKey, true);
  }

  Future<void> replay() async {
    state = false;
    await ref.read(appPreferencesProvider).setBool(_onboardingKey, false);
  }
}

final onboardingCompleteProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);
