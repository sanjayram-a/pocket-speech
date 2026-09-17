import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

const _themeModeKey = 'theme_mode';
const _onboardingKey = 'onboarding_v2_complete';
const _generationSpeedKey = 'generation_speed';
const _generationStepsKey = 'generation_steps';
const _generationTemperatureKey = 'generation_temperature';
const _generationSentenceCharsKey = 'generation_sentence_chars';

/// Allowed speech-rate factor range for Pocket TTS (1.0 = model natural).
const minGenerationSpeed = 0.5;
const maxGenerationSpeed = 2.0;
const defaultGenerationSpeed = 1.0;

/// Diffusion steps for Pocket TTS: fewer = faster/rougher, more = richer.
const minGenerationSteps = 1;
const maxGenerationSteps = 10;
const defaultGenerationSteps = 5;

/// Sampling temperature passed to the Pocket TTS language model. Lower values
/// reduce hallucinations and pacing wobble at the cost of flatter prosody.
const minGenerationTemperature = 0.3;
const maxGenerationTemperature = 1.0;
const defaultGenerationTemperature = 0.7;

/// Long sentences are re-chunked by the engine after this many characters.
/// Shorter chunks keep long-text pacing steady but add more chunk joins.
const minSentenceChunkChars = 60;
const maxSentenceChunkChars = 200;
const defaultSentenceChunkChars = 200;

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

double _readSpeed(AppPreferences preferences) {
  final stored = preferences.getString(_generationSpeedKey);
  final parsed = stored == null ? null : double.tryParse(stored);
  if (parsed == null) return defaultGenerationSpeed;
  return parsed.clamp(minGenerationSpeed, maxGenerationSpeed).toDouble();
}

int _readSteps(AppPreferences preferences) {
  final stored = preferences.getString(_generationStepsKey);
  final parsed = stored == null ? null : int.tryParse(stored);
  if (parsed == null) return defaultGenerationSteps;
  return parsed.clamp(minGenerationSteps, maxGenerationSteps);
}

class GenerationSpeedController extends Notifier<double> {
  @override
  double build() => _readSpeed(ref.watch(appPreferencesProvider));

  Future<void> setSpeed(double speed) async {
    final clamped = speed
        .clamp(minGenerationSpeed, maxGenerationSpeed)
        .toDouble();
    state = clamped;
    await ref
        .read(appPreferencesProvider)
        .setString(_generationSpeedKey, clamped.toString());
  }
}

final generationSpeedProvider =
    NotifierProvider<GenerationSpeedController, double>(
      GenerationSpeedController.new,
    );

class GenerationStepsController extends Notifier<int> {
  @override
  int build() => _readSteps(ref.watch(appPreferencesProvider));

  Future<void> setSteps(int steps) async {
    final clamped = steps.clamp(minGenerationSteps, maxGenerationSteps);
    state = clamped;
    await ref
        .read(appPreferencesProvider)
        .setString(_generationStepsKey, '$clamped');
  }
}

final generationStepsProvider =
    NotifierProvider<GenerationStepsController, int>(
      GenerationStepsController.new,
    );

class GenerationTemperatureController extends Notifier<double> {
  @override
  double build() =>
      _readClampedDouble(
        ref.watch(appPreferencesProvider),
        _generationTemperatureKey,
        defaultGenerationTemperature,
        minGenerationTemperature,
        maxGenerationTemperature,
      ) ??
      defaultGenerationTemperature;

  Future<void> setTemperature(double temperature) async {
    final clamped = temperature
        .clamp(minGenerationTemperature, maxGenerationTemperature)
        .toDouble();
    state = clamped;
    await ref
        .read(appPreferencesProvider)
        .setString(_generationTemperatureKey, clamped.toString());
  }
}

final generationTemperatureProvider =
    NotifierProvider<GenerationTemperatureController, double>(
      GenerationTemperatureController.new,
    );

class SentenceChunkCharsController extends Notifier<int> {
  @override
  int build() =>
      (_readClampedDouble(
                ref.watch(appPreferencesProvider),
                _generationSentenceCharsKey,
                defaultSentenceChunkChars.toDouble(),
                minSentenceChunkChars.toDouble(),
                maxSentenceChunkChars.toDouble(),
              ) ??
              defaultSentenceChunkChars)
          .round();

  Future<void> setChars(int chars) async {
    final clamped = chars.clamp(minSentenceChunkChars, maxSentenceChunkChars);
    state = clamped;
    await ref
        .read(appPreferencesProvider)
        .setString(_generationSentenceCharsKey, '$clamped');
  }
}

final sentenceChunkCharsProvider =
    NotifierProvider<SentenceChunkCharsController, int>(
      SentenceChunkCharsController.new,
    );

double? _readClampedDouble(
  AppPreferences preferences,
  String key,
  double fallback,
  double min,
  double max,
) {
  final stored = preferences.getString(key);
  final parsed = stored == null ? null : double.tryParse(stored);
  if (parsed == null) return null;
  return parsed.clamp(min, max).toDouble();
}
