import 'package:supabase_flutter/supabase_flutter.dart';

class Backend {
  Backend._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static SupabaseClient get client {
    if (!isConfigured) {
      throw StateError(
        'Supabase no está configurado. Inicia Flutter con SUPABASE_URL y '
        'SUPABASE_ANON_KEY usando --dart-define.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
}
