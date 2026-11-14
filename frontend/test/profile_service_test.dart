import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:village_outreach/features/profile/profile_service.dart';

void main() {
  for (final method in ['GET', 'PATCH']) {
    test('$method profile timeout permits retry', () async {
      final expiry =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      String segment(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${segment({'alg': 'HS256'})}.${segment({'exp': expiry})}.test';
      final authHttp = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
            'user': {
              'id': '00000000-0000-0000-0000-000000000001',
              'aud': 'authenticated',
              'email': 'test@example.invalid',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-01T12:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: authHttp,
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
      await supabase.auth.signInWithPassword(
        email: 'test@example.invalid',
        password: 'test-only',
      );
      var calls = 0;
      final pending = Completer<http.Response>();
      final apiHttp = MockClient((request) {
        calls++;
        if (calls == 1) return pending.future;
        return Future.value(
          http.Response(
            jsonEncode({
              'id': '00000000-0000-0000-0000-000000000001',
              'email': 'test@example.invalid',
              'display_name': 'Neighbor',
              'role': 'neighbor',
              'status': 'active',
              'created_at': '2026-11-01T12:00:00Z',
              'updated_at': '2026-11-01T12:00:00Z',
            }),
            200,
          ),
        );
      });
      final service = ProfileService(
        supabase: supabase,
        httpClient: apiHttp,
        baseUrl: 'https://api.example.invalid',
        requestTimeout: const Duration(milliseconds: 20),
      );
      Future<Object> load() => method == 'GET'
          ? service.getProfile()
          : service.updateDisplayName('Neighbor');
      var settled = false;
      Object? failure;
      final first = load().then<void>(
        (_) {
          settled = true;
        },
        onError: (Object e) {
          settled = true;
          failure = e;
        },
      );
      await first;
      expect(
        settled,
        isTrue,
        reason: 'Profile calls must stop waiting at the configured timeout.',
      );
      expect(failure, isA<ProfileException>());
      await load();
      expect(calls, 2);
      pending.complete(http.Response('{}', 200));
      service.dispose();
      await supabase.dispose();
    });
  }
}
