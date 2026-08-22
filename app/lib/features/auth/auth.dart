import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthConfigurationFailure extends AuthFailure {
  const AuthConfigurationFailure(super.message);
}

class AuthCancelledFailure extends AuthFailure {
  const AuthCancelledFailure() : super('Google sign-in was cancelled.');
}

class AuthProviderFailure extends AuthFailure {
  const AuthProviderFailure(super.message);
}

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser> signInWithGoogle();

  Future<String> getIdToken({bool forceRefresh = false});

  Future<void> signOut();
}

class FirebaseRuntimeConfig {
  const FirebaseRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.googleServerClientId,
    this.storageBucket,
    this.authDomain,
  });

  factory FirebaseRuntimeConfig.fromEnvironment() =>
      const FirebaseRuntimeConfig(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      );

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String googleServerClientId;
  final String? storageBucket;
  final String? authDomain;

  bool get isComplete =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty &&
      googleServerClientId.isNotEmpty;

  FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket?.isEmpty ?? true ? null : storageBucket,
    authDomain: authDomain?.isEmpty ?? true ? null : authDomain,
  );
}

class FirebaseGoogleAuthRepository implements AuthRepository {
  FirebaseGoogleAuthRepository._(this._auth, this._googleSignIn);

  static Future<FirebaseGoogleAuthRepository> create({
    required String serverClientId,
  }) async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: serverClientId);
    return FirebaseGoogleAuthRepository._(
      firebase_auth.FirebaseAuth.instance,
      googleSignIn,
    );
  }

  final firebase_auth.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthProviderFailure(
          'Google did not return an identity token. Check the OAuth client '
          'configuration.',
        );
      }
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = _mapUser(result.user);
      if (user == null) {
        throw const AuthProviderFailure(
          'Google sign-in completed without a Firebase user.',
        );
      }
      return user;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelledFailure();
      }
      throw const AuthProviderFailure(
        'Google sign-in failed. Check your connection and configuration.',
      );
    } on firebase_auth.FirebaseAuthException {
      throw const AuthProviderFailure(
        'Firebase could not complete Google sign-in. Please try again.',
      );
    }
  }

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthProviderFailure('Authentication is required.');
      }
      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw const AuthProviderFailure('Your session could not be refreshed.');
      }
      return token;
    } on firebase_auth.FirebaseAuthException {
      throw const AuthProviderFailure('Your session could not be refreshed.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } on Object {
      throw const AuthProviderFailure(
        'Sign out could not be completed. Please try again.',
      );
    }
  }

  static AuthUser? _mapUser(firebase_auth.User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository(this.failure);

  final AuthFailure failure;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInWithGoogle() => Future.error(failure);

  @override
  Future<String> getIdToken({bool forceRefresh = false}) =>
      Future.error(failure);

  @override
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw StateError('AuthRepository must be supplied at bootstrap.');
});

enum AuthPhase { signedOut, authenticating, signedIn, failure }

class AuthState {
  const AuthState({required this.phase, this.user, this.failure});

  const AuthState.signedOut() : this(phase: AuthPhase.signedOut);

  const AuthState.authenticating() : this(phase: AuthPhase.authenticating);

  const AuthState.signedIn(AuthUser user)
    : this(phase: AuthPhase.signedIn, user: user);

  const AuthState.failure(AuthFailure failure)
    : this(phase: AuthPhase.failure, failure: failure);

  final AuthPhase phase;
  final AuthUser? user;
  final AuthFailure? failure;
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<AuthUser?>? _subscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    _subscription?.cancel();
    _subscription = repository.authStateChanges.listen((user) {
      state = user == null
          ? const AuthState.signedOut()
          : AuthState.signedIn(user);
    });
    ref.onDispose(() => _subscription?.cancel());
    final user = repository.currentUser;
    return user == null
        ? const AuthState.signedOut()
        : AuthState.signedIn(user);
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthState.authenticating();
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      state = AuthState.signedIn(user);
      return true;
    } on AuthFailure catch (failure) {
      state = AuthState.failure(failure);
      return false;
    } on Object {
      state = const AuthState.failure(
        AuthProviderFailure('Google sign-in failed unexpectedly.'),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AuthState.signedOut();
    } on AuthFailure catch (failure) {
      state = AuthState.failure(failure);
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
