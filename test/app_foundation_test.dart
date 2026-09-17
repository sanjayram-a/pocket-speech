import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/app/app_controllers.dart';
import 'package:pocket_speech/app/pocket_speech_app.dart';
import 'package:pocket_speech/app/preferences.dart';
import 'package:pocket_speech/core/model/pocket_tts_model.dart';
import 'package:pocket_speech/features/history/generation_history_repository.dart';
import 'package:pocket_speech/features/voices/builtin_voice_repository.dart';
import 'package:pocket_speech/features/voices/voice_profile_repository.dart';

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'pocket-speech-widget-test-',
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  testWidgets('onboarding completes without an account', (tester) async {
    final preferences = FakePreferences();
    await _pumpApp(
      tester,
      preferences: preferences,
      supportDirectory: supportDirectory,
    );

    expect(find.text('Your voice, kept close.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Private by design'), findsOneWidget);
    expect(find.text('Start using Pocket Speech'), findsOneWidget);
    await tester.tap(find.text('Start using Pocket Speech'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Generate'), findsWidgets);
    expect(preferences.values['onboarding_v2_complete'], isTrue);
  });

  testWidgets('generate screen offers optional model installation', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v2_complete'] = true;
    await _pumpApp(
      tester,
      preferences: preferences,
      supportDirectory: supportDirectory,
    );
    await tester.pump();

    expect(find.text('Offline Voice Engine'), findsOneWidget);
    expect(find.byKey(const Key('install_model_button')), findsOneWidget);
    expect(find.textContaining('generate completely offline'), findsOneWidget);
  });

  testWidgets('failed model installation exposes retry', (tester) async {
    final preferences = FakePreferences()
      ..values['onboarding_v2_complete'] = true;
    await _pumpApp(
      tester,
      preferences: preferences,
      supportDirectory: supportDirectory,
      modelControllerBuilder: FailingModelInstallController.new,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('install_model_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Installation did not complete.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('model_install_progress')), findsNothing);
  });

  testWidgets('generation composer enforces the local character limit', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v2_complete'] = true;
    await _pumpApp(
      tester,
      preferences: preferences,
      supportDirectory: supportDirectory,
    );
    await tester.pump();

    final field = find.byKey(const Key('generation_text_field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, List.filled(1001, 'a').join());
    await tester.pump();

    expect(tester.widget<TextField>(field).controller!.text.length, 1000);
    final counter = find.byKey(const Key('generation_character_counter'));
    await tester.ensureVisible(counter);
    expect(find.text('1,000 / 1,000'), findsOneWidget);
  });

  testWidgets('settings shows local model and privacy controls', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v2_complete'] = true;
    await _pumpApp(
      tester,
      preferences: preferences,
      supportDirectory: supportDirectory,
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Local-only preferences and storage'), findsOneWidget);
    expect(find.text('Offline Voice Engine'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Privacy summary'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('remain on this device'), findsOneWidget);
  });

  test('theme preference persists controller changes', () async {
    final preferences = FakePreferences();
    final container = ProviderContainer(
      overrides: [appPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(themePreferenceProvider), ThemeMode.system);
    await container
        .read(themePreferenceProvider.notifier)
        .setMode(ThemeMode.dark);

    expect(container.read(themePreferenceProvider), ThemeMode.dark);
    expect(preferences.values['theme_mode'], 'dark');
  });

  test('generation quality preferences persist and clamp', () async {
    final preferences = FakePreferences();
    final container = ProviderContainer(
      overrides: [appPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(generationTemperatureProvider),
      defaultGenerationTemperature,
    );
    expect(
      container.read(sentenceChunkCharsProvider),
      defaultSentenceChunkChars,
    );

    await container
        .read(generationTemperatureProvider.notifier)
        .setTemperature(0.45);
    await container.read(sentenceChunkCharsProvider.notifier).setChars(80);

    expect(container.read(generationTemperatureProvider), 0.45);
    expect(container.read(sentenceChunkCharsProvider), 80);
    expect(preferences.values['generation_temperature'], '0.45');
    expect(preferences.values['generation_sentence_chars'], '80');

    await container
        .read(generationTemperatureProvider.notifier)
        .setTemperature(9.0);
    await container.read(sentenceChunkCharsProvider.notifier).setChars(-5);

    expect(
      container.read(generationTemperatureProvider),
      maxGenerationTemperature,
    );
    expect(container.read(sentenceChunkCharsProvider), minSentenceChunkChars);

    final restored = FakePreferences()
      ..values['generation_temperature'] = '0.45'
      ..values['generation_sentence_chars'] = '80';
    final secondContainer = ProviderContainer(
      overrides: [appPreferencesProvider.overrideWithValue(restored)],
    );
    addTearDown(secondContainer.dispose);

    expect(secondContainer.read(generationTemperatureProvider), 0.45);
    expect(secondContainer.read(sentenceChunkCharsProvider), 80);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakePreferences preferences,
  required Directory supportDirectory,
  PocketTtsModelRepository? modelRepository,
  GenerationHistoryRepository? historyRepository,
  ModelInstallController Function()? modelControllerBuilder,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        pocketTtsModelRepositoryProvider.overrideWithValue(
          modelRepository ??
              PocketTtsModelRepository(supportDirectory: supportDirectory),
        ),
        generationHistoryRepositoryProvider.overrideWithValue(
          historyRepository ??
              GenerationHistoryRepository(supportDirectory: supportDirectory),
        ),
        voiceProfileRepositoryProvider.overrideWithValue(
          VoiceProfileRepository(supportDirectory: supportDirectory),
        ),
        builtinVoiceRepositoryProvider.overrideWithValue(
          BuiltinVoiceRepository(supportDirectory: supportDirectory),
        ),
        modelInstallControllerProvider.overrideWith(
          modelControllerBuilder ?? TestModelInstallController.new,
        ),
      ],
      child: const PocketSpeechApp(),
    ),
  );
  await tester.pump();
}

class TestModelInstallController extends ModelInstallController {
  @override
  Future<ModelInstallState> build() async =>
      const ModelInstallState(phase: ModelInstallPhase.absent);
}

class FailingModelInstallController extends ModelInstallController {
  @override
  Future<ModelInstallState> build() async =>
      const ModelInstallState(phase: ModelInstallPhase.absent);

  @override
  Future<void> install() async {
    state = const AsyncData(
      ModelInstallState(phase: ModelInstallPhase.verifying),
    );
    final error = AsyncError<ModelInstallState>(
      const ModelInstallException('Download failed for testing.'),
      StackTrace.current,
    );
    // Construct the retained-value state produced by a failed async mutation.
    // ignore: invalid_use_of_internal_member
    state = error.copyWithPrevious(state);
  }
}

class FakePreferences implements AppPreferences {
  final Map<String, Object> values = {};

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> setBool(String key, bool value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}
