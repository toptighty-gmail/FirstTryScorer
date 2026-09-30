import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client {
    if (!isInitialized) {
      throw StateError('Supabase has not been initialized.');
    }
    return Supabase.instance.client;
  }

  static User? get currentUser {
    if (!isInitialized) return null;
    return client.auth.currentUser;
  }

  static Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      throw Exception('Email and password are required.');
    }

    final response = await client.auth.signInWithPassword(
      email: trimmedEmail,
      password: trimmedPassword,
    );

    if (response.user == null) {
      throw Exception('Sign in failed.');
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;

    final row = await client
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();

    return row?['is_admin'] == true;
  }
}
