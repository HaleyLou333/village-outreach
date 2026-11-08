import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth emails return to the installed app; SDK-owned PKCE handles the exchange.
class AuthService {
  static const callbackUrl = 'io.villageoutreach://auth-callback/';
  AuthService({SupabaseClient? supabase})
    : _client = supabase ?? Supabase.instance.client;
  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 15);

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _client.auth
        .signInWithPassword(email: email.trim(), password: password)
        .timeout(_timeout);
  }

  Future<AuthResponse> signUp(String name, String email, String password) {
    return _client.auth
        .signUp(
          email: email.trim(),
          password: password,
          data: {'display_name': name.trim()},
          emailRedirectTo: callbackUrl,
        )
        .timeout(_timeout);
  }

  Future<void> requestPasswordReset(String email) {
    return _client.auth
        .resetPasswordForEmail(email.trim(), redirectTo: callbackUrl)
        .timeout(_timeout);
  }

  Future<void> resendConfirmation(String email) async {
    await _client.auth
        .resend(
          type: OtpType.signup,
          email: email.trim(),
          emailRedirectTo: callbackUrl,
        )
        .timeout(_timeout);
  }

  Future<void> updatePassword(String password) async {
    await _client.auth
        .updateUser(UserAttributes(password: password))
        .timeout(_timeout);
  }
}

bool isAppAuthCallback(Uri uri) {
  final expected = Uri.parse(AuthService.callbackUrl);
  if (uri.scheme != expected.scheme ||
      uri.host != expected.host ||
      uri.path != expected.path) {
    return false;
  }
  final fragment = Uri.tryParse('?${uri.fragment}');
  final parameters = {
    ...uri.queryParameters.keys,
    ...?fragment?.queryParameters.keys,
  };
  // PKCE callbacks must prove possession of the locally stored verifier.
  // The SDK also supports implicit callbacks, so reject those before it sees them.
  if (parameters.contains('access_token') ||
      parameters.contains('refresh_token')) {
    return false;
  }
  return [
    'code',
    'error',
    'error_code',
    'error_description',
  ].any((key) => parameters.contains(key));
}
