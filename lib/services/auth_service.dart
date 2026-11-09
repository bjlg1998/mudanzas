import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';

class AuthService {
  SupabaseClient get _client => Backend.client;

  User? get currentUser =>
      Backend.isConfigured ? _client.auth.currentUser : null;

  Session? get currentSession =>
      Backend.isConfigured ? _client.auth.currentSession : null;

  String? get displayName {
    final metadata = currentUser?.userMetadata;
    return _firstText(metadata?['full_name'], metadata?['name']);
  }

  String? get avatarUrl {
    final metadata = currentUser?.userMetadata;
    return _firstText(metadata?['avatar_url'], metadata?['picture']);
  }

  String? _firstText(Object? first, Object? second) {
    for (final value in [first, second]) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      },
    );
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.mudanzas://login-callback/',
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
