import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth.dart';

class PlanPolicy {
  const PlanPolicy({
    required this.planKey,
    required this.policyVersion,
    required this.activeVoiceLimit,
    required this.monthlyCloneLimit,
    required this.monthlyGenerationLimitMs,
    required this.generationCharacterLimit,
    required this.generationConcurrencyLimit,
  });

  factory PlanPolicy.fromJson(Map<String, Object?> json) => PlanPolicy(
    planKey: _string(json, 'plan_key'),
    policyVersion: _integer(json, 'policy_version'),
    activeVoiceLimit: _integer(json, 'active_voice_limit'),
    monthlyCloneLimit: _integer(json, 'monthly_clone_limit'),
    monthlyGenerationLimitMs: _integer(json, 'monthly_generation_limit_ms'),
    generationCharacterLimit: _integer(json, 'generation_character_limit'),
    generationConcurrencyLimit: _integer(json, 'generation_concurrency_limit'),
  );

  final String planKey;
  final int policyVersion;
  final int activeVoiceLimit;
  final int monthlyCloneLimit;
  final int monthlyGenerationLimitMs;
  final int generationCharacterLimit;
  final int generationConcurrencyLimit;
}

class UsageSnapshot {
  const UsageSnapshot({
    required this.periodStart,
    required this.periodEnd,
    required this.generatedMs,
    required this.successfulClones,
    required this.activeVoices,
    required this.activeGenerations,
  });

  factory UsageSnapshot.fromJson(Map<String, Object?> json) => UsageSnapshot(
    periodStart: _dateTime(json, 'period_start'),
    periodEnd: _dateTime(json, 'period_end'),
    generatedMs: _integer(json, 'generated_ms'),
    successfulClones: _integer(json, 'successful_clones'),
    activeVoices: _integer(json, 'active_voices'),
    activeGenerations: _integer(json, 'active_generations'),
  );

  final DateTime periodStart;
  final DateTime periodEnd;
  final int generatedMs;
  final int successfulClones;
  final int activeVoices;
  final int activeGenerations;
}

class UsageOverview {
  const UsageOverview({
    required this.planKey,
    required this.policy,
    required this.usage,
  });

  factory UsageOverview.fromJson(Map<String, Object?> json) {
    final planKey = _string(json, 'plan_key');
    final policy = PlanPolicy.fromJson(_map(json, 'policy'));
    if (policy.planKey != planKey) {
      throw const FormatException('Plan keys must match.');
    }
    return UsageOverview(
      planKey: planKey,
      policy: policy,
      usage: UsageSnapshot.fromJson(_map(json, 'usage')),
    );
  }

  final String planKey;
  final PlanPolicy policy;
  final UsageSnapshot usage;
}

sealed class UsageFailure implements Exception {
  const UsageFailure(this.message, {required this.retryable});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

class UsageConfigurationFailure extends UsageFailure {
  const UsageConfigurationFailure(super.message) : super(retryable: false);
}

class UsageAuthenticationFailure extends UsageFailure {
  const UsageAuthenticationFailure()
    : super('Your session expired. Sign in again.', retryable: false);
}

class UsageNetworkFailure extends UsageFailure {
  const UsageNetworkFailure()
    : super(
        'Usage could not be refreshed. Check your connection and try again.',
        retryable: true,
      );
}

class UsageResponseFailure extends UsageFailure {
  const UsageResponseFailure(super.message, {required super.retryable});
}

abstract interface class UsageRepository {
  Future<UsageOverview> fetchUsage();
}

class RemoteUsageRepository implements UsageRepository {
  RemoteUsageRepository(
    this._baseUri,
    this._authRepository, {
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final AuthRepository _authRepository;
  final HttpClient _httpClient;

  @override
  Future<UsageOverview> fetchUsage() async {
    try {
      var result = await _requestUsage();
      if (result.statusCode == HttpStatus.unauthorized) {
        result = await _requestUsage(forceRefresh: true);
      }

      if (result.statusCode == HttpStatus.unauthorized) {
        throw const UsageAuthenticationFailure();
      }
      if (result.statusCode < 200 || result.statusCode >= 300) {
        final error = _parseError(result.body);
        throw UsageResponseFailure(
          error?.message ?? 'Pocket Speech could not load Usage right now.',
          retryable: error?.retryable ?? result.statusCode >= 500,
        );
      }

      final decoded = jsonDecode(result.body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Expected a JSON object.');
      }
      return UsageOverview.fromJson(decoded);
    } on UsageFailure {
      rethrow;
    } on AuthFailure {
      throw const UsageAuthenticationFailure();
    } on IOException {
      throw const UsageNetworkFailure();
    } on TimeoutException {
      throw const UsageNetworkFailure();
    } on FormatException {
      throw const UsageResponseFailure(
        'The server returned an invalid Usage response.',
        retryable: true,
      );
    }
  }

  void close() => _httpClient.close(force: true);

  Future<({int statusCode, String body})> _requestUsage({
    bool forceRefresh = false,
  }) async {
    final token = await _authRepository.getIdToken(forceRefresh: forceRefresh);
    final request = await _httpClient
        .getUrl(_baseUri.resolve('/v1/usage'))
        .timeout(const Duration(seconds: 10));
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decoder.bind(response).join();
    return (statusCode: response.statusCode, body: body);
  }

  ({String message, bool retryable})? _parseError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final message = decoded['message'];
        final retryable = decoded['retryable'];
        if (message is String && retryable is bool) {
          return (message: message, retryable: retryable);
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

class UnavailableUsageRepository implements UsageRepository {
  const UnavailableUsageRepository(this.failure);

  final UsageFailure failure;

  @override
  Future<UsageOverview> fetchUsage() => Future.error(failure);
}

class ApiRuntimeConfig {
  const ApiRuntimeConfig(this.baseUrl);

  factory ApiRuntimeConfig.fromEnvironment() => const ApiRuntimeConfig(
    String.fromEnvironment('POCKET_SPEECH_API_BASE_URL'),
  );

  final String baseUrl;

  Uri? get baseUri {
    final parsed = Uri.tryParse(baseUrl);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      return null;
    }
    final isLocalHttp =
        parsed.scheme == 'http' &&
        (parsed.host == '10.0.2.2' || parsed.host == 'localhost');
    if (parsed.scheme != 'https' && !isLocalHttp) {
      return null;
    }
    return parsed;
  }
}

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  final baseUri = ApiRuntimeConfig.fromEnvironment().baseUri;
  if (baseUri == null) {
    return const UnavailableUsageRepository(
      UsageConfigurationFailure(
        'The Pocket Speech API is not configured for this build.',
      ),
    );
  }
  final repository = RemoteUsageRepository(
    baseUri,
    ref.watch(authRepositoryProvider),
  );
  ref.onDispose(repository.close);
  return repository;
});

final usageOverviewProvider = FutureProvider<UsageOverview>((ref) async {
  final userId = ref.watch(
    authControllerProvider.select((state) => state.user?.id),
  );
  if (userId == null) throw const UsageAuthenticationFailure();
  return ref.watch(usageRepositoryProvider).fetchUsage();
}, retry: (retryCount, error) => null);

Map<String, Object?> _map(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('$key must be an object.');
  }
  return value;
}

int _integer(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

String _string(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

DateTime _dateTime(Map<String, Object?> source, String key) {
  final value = _string(source, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key must be a UTC timestamp.');
  }
  return parsed;
}
