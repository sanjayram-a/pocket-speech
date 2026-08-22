import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/app/app_controllers.dart';
import 'package:pocket_speech/app/pocket_speech_app.dart';
import 'package:pocket_speech/app/preferences.dart';
import 'package:pocket_speech/core/api/usage_repository.dart';
import 'package:pocket_speech/features/auth/auth.dart';

void main() {
  testWidgets('onboarding presents two pages and mandatory Google sign-in', (
    tester,
  ) async {
    await _pumpApp(tester, preferences: FakePreferences());

    expect(find.text('Your voice, kept close.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Private by design'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('There is no guest mode'), findsNothing);
  });

  testWidgets('missing auth configuration reports a clear failure', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v1_complete'] = true;
    const message = 'Google sign-in is not configured for this build.';

    await _pumpApp(
      tester,
      preferences: preferences,
      authRepository: const UnavailableAuthRepository(
        AuthConfigurationFailure(message),
      ),
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('skipping Pro preview enters the main shell', (tester) async {
    final preferences = FakePreferences()
      ..values['onboarding_v1_complete'] = true;
    final user = const AuthUser(id: 'user-1', email: 'person@example.com');

    await _pumpApp(
      tester,
      preferences: preferences,
      authRepository: FakeAuthRepository(user: user),
    );

    expect(find.text('Pocket Speech Pro'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Generate'), findsWidgets);
    expect(find.text('No Voice Profile yet'), findsOneWidget);
    expect(preferences.values['pro_preview_complete'], isTrue);
  });

  testWidgets('generation composer enforces the server character limit', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v1_complete'] = true
      ..values['pro_preview_complete'] = true;
    final user = const AuthUser(id: 'user-1', email: 'person@example.com');

    await _pumpApp(
      tester,
      preferences: preferences,
      authRepository: FakeAuthRepository(user: user),
      usageRepository: FakeUsageRepository(
        overview: _usageOverview(characterLimit: 875),
      ),
    );
    final field = find.byKey(const Key('generation_text_field'));
    await tester.enterText(field, List.filled(876, 'a').join());
    await tester.pump();

    final textField = tester.widget<TextField>(field);
    expect(textField.controller!.text.length, 875);
    expect(find.text('875 / 875'), findsOneWidget);
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

  testWidgets('settings renders limits supplied by the server policy', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v1_complete'] = true
      ..values['pro_preview_complete'] = true;
    const user = AuthUser(id: 'user-1', email: 'person@example.com');

    await _pumpApp(
      tester,
      preferences: preferences,
      authRepository: FakeAuthRepository(user: user),
      usageRepository: FakeUsageRepository(
        overview: _usageOverview(characterLimit: 875),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('of 900 sec', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('of 3', findRichText: true), findsNWidgets(2));
    expect(
      find.textContaining('2026-09-01', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('settings retries a retryable Usage failure', (tester) async {
    final preferences = FakePreferences()
      ..values['onboarding_v1_complete'] = true
      ..values['pro_preview_complete'] = true;
    const user = AuthUser(id: 'user-1', email: 'person@example.com');
    final repository = RetryUsageRepository(_usageOverview());

    await _pumpApp(
      tester,
      preferences: preferences,
      authRepository: FakeAuthRepository(user: user),
      usageRepository: repository,
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Usage could not be refreshed. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Free plan usage'), findsOneWidget);
    expect(
      find.textContaining('of 900 sec', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('settings shows a loading state while Usage is pending', (
    tester,
  ) async {
    final preferences = FakePreferences()
      ..values['onboarding_v1_complete'] = true
      ..values['pro_preview_complete'] = true;
    const user = AuthUser(id: 'user-1', email: 'person@example.com');

    await _pumpApp(
      tester,
      preferences: preferences,
      authRepository: FakeAuthRepository(user: user),
      usageRepository: PendingUsageRepository(),
    );
    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(find.bySemanticsLabel('Loading plan usage'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakePreferences preferences,
  AuthRepository? authRepository,
  UsageRepository? usageRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? FakeAuthRepository(),
        ),
        usageRepositoryProvider.overrideWithValue(
          usageRepository ?? FakeUsageRepository(overview: _usageOverview()),
        ),
      ],
      child: const PocketSpeechApp(),
    ),
  );
  await tester.pump();
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

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  AuthUser? user;

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(user);

  @override
  Future<AuthUser> signInWithGoogle() async {
    user ??= const AuthUser(id: 'user-1', email: 'person@example.com');
    return user!;
  }

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async => 'test-token';

  @override
  Future<void> signOut() async => user = null;
}

class FakeUsageRepository implements UsageRepository {
  const FakeUsageRepository({required this.overview});

  final UsageOverview overview;

  @override
  Future<UsageOverview> fetchUsage() async => overview;
}

class RetryUsageRepository implements UsageRepository {
  RetryUsageRepository(this.overview);

  final UsageOverview overview;
  int calls = 0;

  @override
  Future<UsageOverview> fetchUsage() async {
    calls += 1;
    if (calls == 1) throw const UsageNetworkFailure();
    return overview;
  }
}

class PendingUsageRepository implements UsageRepository {
  final Completer<UsageOverview> _completer = Completer<UsageOverview>();

  @override
  Future<UsageOverview> fetchUsage() => _completer.future;
}

UsageOverview _usageOverview({int characterLimit = 1000}) => UsageOverview(
  planKey: 'free',
  policy: PlanPolicy(
    planKey: 'free',
    policyVersion: 1,
    activeVoiceLimit: 3,
    monthlyCloneLimit: 3,
    monthlyGenerationLimitMs: 900000,
    generationCharacterLimit: characterLimit,
    generationConcurrencyLimit: 1,
  ),
  usage: UsageSnapshot(
    periodStart: DateTime.utc(2026, 8),
    periodEnd: DateTime.utc(2026, 9),
    generatedMs: 0,
    successfulClones: 0,
    activeVoices: 0,
    activeGenerations: 0,
  ),
);
