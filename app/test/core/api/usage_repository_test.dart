import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_speech/core/api/usage_repository.dart';
import 'package:pocket_speech/features/auth/auth.dart';

void main() {
  test('parses the server Usage contract without client-owned limits', () {
    final overview = UsageOverview.fromJson(_usageJson(characterLimit: 875));

    expect(overview.planKey, 'free');
    expect(overview.policy.generationCharacterLimit, 875);
    expect(overview.policy.monthlyGenerationLimitMs, 900000);
    expect(overview.usage.generatedMs, 125000);
    expect(overview.usage.periodStart, DateTime.utc(2026, 8));
    expect(overview.usage.periodEnd, DateTime.utc(2026, 9));
  });

  test('rejects inconsistent top-level and policy plan keys', () {
    final json = _usageJson();
    (json['policy']! as Map<String, Object?>)['plan_key'] = 'pro';

    expect(() => UsageOverview.fromJson(json), throwsFormatException);
  });

  test(
    'refreshes the Firebase token once after an unauthorized response',
    () async {
      final requests = <String?>[];
      final server = await _serve((request) async {
        requests.add(request.headers.value(HttpHeaders.authorizationHeader));
        if (requests.length == 1) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write(jsonEncode(_errorJson(retryable: false)));
        } else {
          request.response.write(jsonEncode(_usageJson(characterLimit: 875)));
        }
      });
      addTearDown(() => server.close(force: true));
      final auth = RecordingAuthRepository();
      final repository = RemoteUsageRepository(_baseUri(server), auth);
      addTearDown(repository.close);

      final overview = await repository.fetchUsage();

      expect(overview.policy.generationCharacterLimit, 875);
      expect(auth.forceRefreshCalls, [false, true]);
      expect(requests, ['Bearer cached-token', 'Bearer refreshed-token']);
    },
  );

  test('maps the API retryable error contract into a typed failure', () async {
    final server = await _serve((request) async {
      request.response.statusCode = HttpStatus.tooManyRequests;
      request.response.write(
        jsonEncode(
          _errorJson(
            message: 'Generation quota is temporarily unavailable.',
            retryable: true,
          ),
        ),
      );
    });
    addTearDown(() => server.close(force: true));
    final repository = RemoteUsageRepository(
      _baseUri(server),
      RecordingAuthRepository(),
    );
    addTearDown(repository.close);

    await expectLater(
      repository.fetchUsage(),
      throwsA(
        isA<UsageResponseFailure>()
            .having((failure) => failure.retryable, 'retryable', isTrue)
            .having(
              (failure) => failure.message,
              'message',
              'Generation quota is temporarily unavailable.',
            ),
      ),
    );
  });

  test('maps token acquisition failures to authentication failure', () async {
    final repository = RemoteUsageRepository(
      Uri.parse('http://localhost'),
      const UnavailableAuthRepository(
        AuthProviderFailure('Token refresh failed.'),
      ),
    );
    addTearDown(repository.close);

    await expectLater(
      repository.fetchUsage(),
      throwsA(isA<UsageAuthenticationFailure>()),
    );
  });
}

class RecordingAuthRepository implements AuthRepository {
  final List<bool> forceRefreshCalls = [];

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  AuthUser? get currentUser => null;

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    forceRefreshCalls.add(forceRefresh);
    return forceRefresh ? 'refreshed-token' : 'cached-token';
  }

  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

Future<HttpServer> _serve(
  FutureOr<void> Function(HttpRequest request) respond,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    await respond(request);
    await request.response.close();
  });
  return server;
}

Uri _baseUri(HttpServer server) =>
    Uri.parse('http://${server.address.address}:${server.port}');

Map<String, Object?> _usageJson({int characterLimit = 1000}) => {
  'plan_key': 'free',
  'policy': <String, Object?>{
    'plan_key': 'free',
    'policy_version': 7,
    'active_voice_limit': 3,
    'monthly_clone_limit': 3,
    'monthly_generation_limit_ms': 900000,
    'generation_character_limit': characterLimit,
    'generation_concurrency_limit': 1,
    'reference_audio_max_bytes': 10485760,
    'reference_audio_min_ms': 10000,
    'reference_audio_max_ms': 30000,
    'effective_at': '2026-01-01T00:00:00Z',
    'retired_at': null,
  },
  'usage': <String, Object?>{
    'period_start': '2026-08-01T00:00:00Z',
    'period_end': '2026-09-01T00:00:00Z',
    'generated_ms': 125000,
    'successful_clones': 1,
    'active_voices': 2,
    'active_generations': 0,
  },
};

Map<String, Object?> _errorJson({
  String message = 'Valid authentication is required.',
  required bool retryable,
}) => {
  'code': 'request_failed',
  'message': message,
  'retryable': retryable,
  'request_id': '3df83bd0-5428-4538-bc34-f0092733d175',
};
