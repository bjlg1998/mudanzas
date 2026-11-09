import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';

class AuthService {
  SupabaseClient get _client => Backend.client;

  Session? get currentSession =>
      Backend.isConfigured ? _client.auth.currentSession : null;

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

  Future<void> signOut() => _client.auth.signOut();
}
