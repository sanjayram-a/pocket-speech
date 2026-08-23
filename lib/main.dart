import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/pocket_speech_app.dart';
import 'app/preferences.dart';
import 'core/model/pocket_tts_model.dart';
import 'features/history/generation_history_repository.dart';
import 'features/generation/local_tts_service.dart';
import 'features/voices/builtin_voice_repository.dart';
import 'features/voices/voice_profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final preferences = SharedPreferencesStore(
      await SharedPreferences.getInstance(),
    );
    final supportDirectory = await getApplicationSupportDirectory();
    final modelRepository = PocketTtsModelRepository(
      supportDirectory: supportDirectory,
    );
    final historyRepository = GenerationHistoryRepository(
      supportDirectory: supportDirectory,
    );
    final voiceRepository = VoiceProfileRepository(
      supportDirectory: supportDirectory,
    );
    final builtinVoiceRepository = BuiltinVoiceRepository(
      supportDirectory: supportDirectory,
    );

    // Diagnostic hook: --dart-define=POCKET_SPEECH_AUTO_INSTALL=true runs the
    // model installation immediately at startup so failures can be captured
    // without touching the UI, then performs one local generation to exercise
    // the sherpa worker isolate end-to-end.
    const autoInstall = bool.fromEnvironment('POCKET_SPEECH_AUTO_INSTALL');
    if (autoInstall) {
      final paths = await modelRepository.install(onState: (_) {});
      final service = LocalTtsService();
      try {
        final result = await service.generate(
          model: paths,
          text: 'Diagnostic generation after install.',
          referenceAudioPath: paths.demoReference,
          outputPath: await modelRepository.createGenerationOutputPath(),
        );
        debugPrint(
          '[DEBUG-diag] generated ${result.duration} '
          'rtf=${result.realTimeFactor}',
        );
      } finally {
        await service.dispose();
      }
    }

    runApp(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(preferences),
          pocketTtsModelRepositoryProvider.overrideWithValue(modelRepository),
          generationHistoryRepositoryProvider.overrideWithValue(
            historyRepository,
          ),
          voiceProfileRepositoryProvider.overrideWithValue(voiceRepository),
          builtinVoiceRepositoryProvider.overrideWithValue(
            builtinVoiceRepository,
          ),
        ],
        child: const PocketSpeechApp(),
      ),
    );
  } on Object {
    runApp(const BootstrapFailureApp());
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Pocket Speech could not open local storage.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Close and reopen the app. If the problem continues, clear '
                    'the app data and try again.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
