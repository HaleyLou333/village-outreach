import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  bool? get isEmailConfirmed {
    final user = _supabase.auth.currentUser;
    return user == null ? null : user.emailConfirmedAt != null;
  }

  Future<Uint8List?> getPhoto() => _profilePhoto('GET');

  Future<Uint8List?> uploadPhoto(Uint8List bytes) =>
      _profilePhoto('PUT', body: {'photo': base64Encode(bytes)});

  Future<void> removePhoto() async {
    await _profilePhoto('DELETE');
  }

  Future<Uint8List?> _profilePhoto(
    String method, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _sendAuthenticated(
      method,
      '/users/me/shared-photo',
      body: body,
    );
    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) {
      throw ProfileException(
        'Could not access the profile photo.',
        response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final photo = data['photo'] as String?;
    return photo == null ? null : base64Decode(photo);
  }

  Future<VolunteerProgress> getVolunteerProgress() async {
    final response = await _sendAuthenticated(
      'GET',
      '/users/me/volunteer-progress',
    );
    if (response.statusCode != 200) {
      throw ProfileException(
        'Unable to load volunteer progress.',
        response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final next = data['next_badge'] as Map<String, dynamic>?;
    return VolunteerProgress(
      completedHelpCount: data['completed_help_count'] as int,
      badgeLabels: [
        for (final badge in data['earned_badges'] as List<dynamic>)
          (badge as Map<String, dynamic>)['label'] as String,
      ],
      nextLabel: next?['label'] as String?,
      nextTarget: next?['required_completions'] as int?,
    );
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

      final request = switch (method) {
        'PATCH' => _http.patch(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => _http.put(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => _http.get(uri, headers: headers),
      };
      return await request.timeout(requestTimeout);
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

class VolunteerProgress {
  const VolunteerProgress({
    required this.completedHelpCount,
    required this.badgeLabels,
    required this.nextLabel,
    required this.nextTarget,
  });

  final int completedHelpCount;
  final List<String> badgeLabels;
  final String? nextLabel;
  final int? nextTarget;
}
