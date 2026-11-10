import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';

enum AccountRole {
  customer('customer', 'Cliente'),
  driver('driver', 'Conductor');

  const AccountRole(this.value, this.label);

  final String value;
  final String label;

  static AccountRole fromValue(Object? value) =>
      value == 'driver' ? AccountRole.driver : AccountRole.customer;
}

class AuthService {
  static const _emailConfirmationUrl =
      'io.supabase.mudanzas://login-callback/';

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
    required AccountRole role,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _emailConfirmationUrl,
      data: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        'account_role': role.value,
      },
    );
  }

  Future<AccountRole> currentRole() async {
    if (!Backend.isConfigured) return AccountRole.customer;
    final user = currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    return AccountRole.fromValue(row['role']);
  }

  Future<AccountRole> chooseRole(AccountRole role) async {
    if (!Backend.isConfigured) return role;
    final value = await _client.rpc(
      'choose_my_role',
      params: {'p_role': role.value},
    );
    return AccountRole.fromValue(value);
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.mudanzas://login-callback/',
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
