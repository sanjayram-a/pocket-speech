import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/pocket_speech_app.dart';
import 'app/preferences.dart';
import 'features/auth/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final preferences = SharedPreferencesStore(
      await SharedPreferences.getInstance(),
    );
    final config = FirebaseRuntimeConfig.fromEnvironment();
    final authRepository = await _createAuthRepository(config);

    runApp(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
        child: const PocketSpeechApp(),
      ),
    );
  } on Object {
    runApp(const BootstrapFailureApp());
  }
}

Future<AuthRepository> _createAuthRepository(
  FirebaseRuntimeConfig config,
) async {
  if (!config.isComplete) {
    return const UnavailableAuthRepository(
      AuthConfigurationFailure(
        'Google sign-in is not configured for this build. Add the required '
        'Firebase dart-defines and GOOGLE_SERVER_CLIENT_ID.',
      ),
    );
  }

  try {
    await Firebase.initializeApp(options: config.firebaseOptions);
    return FirebaseGoogleAuthRepository.create(
      serverClientId: config.googleServerClientId,
    );
  } on Object {
    return const UnavailableAuthRepository(
      AuthConfigurationFailure(
        'Firebase could not be initialized. Check this build\'s Firebase '
        'configuration and try again.',
      ),
    );
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
                    'Pocket Speech could not open local preferences.',
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
