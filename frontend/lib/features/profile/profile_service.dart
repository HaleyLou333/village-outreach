import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_profile.dart';

class ProfileException implements Exception {
  final String message;
  final int? statusCode;

  const ProfileException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ProfileService {
  final String baseUrl;
  final Duration requestTimeout;

  final SupabaseClient _supabase;
  final http.Client _http;

  ProfileService({
    SupabaseClient? supabase,
    http.Client? httpClient,
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.requestTimeout = const Duration(seconds: 15),
  }) : _supabase = supabase ?? Supabase.instance.client,
       _http = httpClient ?? http.Client();

  Future<UserProfile> getProfile() async {
    final response = await _sendAuthenticated('GET', '/users/me');

    return _parseProfile(response);
  }

  Future<UserProfile> updateDisplayName(String displayName) async {
    final response = await _sendAuthenticated(
      'PATCH',
      '/users/me',
      body: {'display_name': displayName.trim()},
    );

    return _parseProfile(response);
  }

  Future<http.Response> _sendAuthenticated(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (baseUrl.isEmpty) {
      throw const ProfileException('API_BASE_URL is not configured.');
    }

    var session = _supabase.auth.currentSession;

    if (session == null) {
      throw const ProfileException(
        'You must sign in to access your profile.',
        401,
      );
    }

    // Supabase normally refreshes sessions automatically.
    // Refresh explicitly if the access token is near expiry.
    final expiresAt = session.expiresAt;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (expiresAt != null && expiresAt <= now + 60) {
      try {
        final refreshed = await _supabase.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {
        throw const ProfileException(
          'Your session expired. Please sign in again.',
          401,
        );
      }
    }

    if (session == null) {
      throw const ProfileException(
        'Your session expired. Please sign in again.',
        401,
      );
    }

    var response = await _request(method, path, session.accessToken, body);

    // Retry once after refreshing a rejected access token.
    if (response.statusCode == 401) {
      try {
        final refreshed = await _supabase.auth.refreshSession();
        final newSession = refreshed.session;

        if (newSession == null) {
          throw const ProfileException(
            'Your session expired. Please sign in again.',
            401,
          );
        }

        response = await _request(method, path, newSession.accessToken, body);
      } catch (_) {
        throw const ProfileException(
          'Your session expired. Please sign in again.',
          401,
        );
      }
    }

    return response;
  }

  Future<http.Response> _request(
    String method,
    String path,
    String accessToken,
    Map<String, dynamic>? body,
  ) async {
    try {
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      };

      if (method == 'PATCH') {
        return await _http
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(requestTimeout);
      }

      return await _http.get(uri, headers: headers).timeout(requestTimeout);
    } on TimeoutException {
      throw const ProfileException(
        'The profile request timed out. Please try again.',
      );
    } catch (_) {
      throw const ProfileException(
        'Unable to reach the profile server. Check that FastAPI is running.',
      );
    }
  }

  UserProfile _parseProfile(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return UserProfile.fromJson(json);
      } catch (_) {
        throw const ProfileException(
          'The server returned an unexpected profile response.',
        );
      }
    }

    final message = switch (response.statusCode) {
      401 => 'Your session expired. Please sign in again.',
      403 => 'Your account is not active.',
      404 => 'Your profile could not be found.',
      422 => 'Please enter a valid display name (1–100 characters).',
      503 => 'The profile service is temporarily unavailable.',
      _ => 'Unable to load your profile. Please try again.',
    };

    throw ProfileException(message, response.statusCode);
  }

  void dispose() {
    _http.close();
  }
}
