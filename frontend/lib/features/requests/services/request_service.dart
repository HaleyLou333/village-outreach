import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/help_request.dart';

/// Repository interface for dependency injection and testing.
abstract class RequestRepository {
  Future<List<HelpRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
    int offset = 0,
  });

  Future<HelpRequest> getRequestDetail(String requestId);
}

/// Handles communication with the Village Outreach FastAPI backend.
class RequestService implements RequestRepository {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');

  final SupabaseClient _supabase;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  RequestService({SupabaseClient? supabase, http.Client? httpClient})
    : _supabase = supabase ?? Supabase.instance.client,
      _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  /// Retrieves active requests near the supplied coordinates.
  @override
  Future<List<HelpRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = _buildUri(
      '/requests',
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    debugPrint('========== NEARBY REQUESTS ==========');
    debugPrint('Latitude: $latitude');
    debugPrint('Longitude: $longitude');
    debugPrint('Radius: $radiusKm km');
    debugPrint('Limit: $limit');
    debugPrint('Offset: $offset');

    final response = await _authorizedGet(uri);

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw const FormatException('Expected a list of requests.');
      }

      final requests = decoded
          .map((item) => HelpRequest.fromJson(item as Map<String, dynamic>))
          .toList();

      debugPrint('Requests returned: ${requests.length}');

      if (requests.isEmpty) {
        debugPrint(
          'API returned an empty list. '
          'No matching nearby requests were found.',
        );
      }

      debugPrint('=====================================');

      return requests;
    } catch (error) {
      debugPrint('Failed to parse nearby requests: $error');

      throw Exception('The server returned an unexpected requests response.');
    }
  }

  /// Retrieves the full details of a single request.
  @override
  Future<HelpRequest> getRequestDetail(String requestId) async {
    final uri = _buildUri('/requests/${Uri.encodeComponent(requestId)}');

    debugPrint('========== REQUEST DETAILS ==========');
    debugPrint('Request ID: $requestId');

    final response = await _authorizedGet(uri);

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a request object.');
      }

      final request = HelpRequest.fromJson(decoded);

      debugPrint('Request details loaded successfully.');
      debugPrint('=====================================');

      return request;
    } catch (error) {
      debugPrint('Failed to parse request details: $error');

      throw Exception(
        'The server returned an unexpected request detail response.',
      );
    }
  }

  /// Builds API URLs and validates configuration.
  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    if (_baseUrl.trim().isEmpty) {
      debugPrint('CONFIGURATION ERROR: API_BASE_URL is missing.');

      throw Exception(
        'API configuration is missing. '
        'Check frontend/config/dev.json.',
      );
    }

    final baseUri = Uri.tryParse(_baseUrl);

    if (baseUri == null ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
        baseUri.host.isEmpty) {
      throw Exception('API_BASE_URL must be a valid HTTP or HTTPS URL.');
    }

    final normalizedBase = _baseUrl.replaceAll(RegExp(r'/$'), '');

    return Uri.parse('$normalizedBase$path')
        .replace(queryParameters: queryParameters);
  }

  /// Performs an authenticated GET request.
  Future<http.Response> _authorizedGet(Uri uri) async {
    debugPrint('-------------------------------------');
    debugPrint('API Request: GET $uri');

    var token = _supabase.auth.currentSession?.accessToken;

    if (token == null || token.isEmpty) {
      debugPrint('AUTH ERROR: No active Supabase session.');

      throw Exception('You must be signed in to view requests.');
    }

    debugPrint('Supabase session: Available');

    http.Response response;

    try {
      response = await _httpClient
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      debugPrint('NETWORK ERROR: $error');

      throw Exception(
        'Unable to connect to the request service. '
        'Check that FastAPI is running and reachable.',
      );
    }

    debugPrint('Initial HTTP status: ${response.statusCode}');

    /// Attempt to refresh the session after an unauthorized response.
    if (response.statusCode == 401) {
      debugPrint('HTTP 401: Attempting token refresh.');

      try {
        final refreshed = await _supabase.auth.refreshSession();

        token = refreshed.session?.accessToken;

        if (token == null || token.isEmpty) {
          throw Exception('No refreshed access token.');
        }

        response = await _httpClient
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 15));

        debugPrint('HTTP status after refresh: ${response.statusCode}');
      } catch (error) {
        debugPrint('TOKEN REFRESH ERROR: $error');

        throw Exception('Your session has expired. Please sign in again.');
      }
    }

    debugPrint('Final HTTP status: ${response.statusCode}');
    debugPrint(
      'Response content type: '
      '${response.headers['content-type'] ?? 'unknown'}',
    );

    // Only log a short response preview for server errors.
    // Avoid printing request data, tokens, or personal information.
    if (response.statusCode == 503) {
      debugPrint('Backend returned HTTP 503.');

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          debugPrint('Backend error detail: ${decoded['detail']}');
        }
      } catch (_) {
        debugPrint('Backend returned a non-JSON error response.');
      }
    }
    if (response.statusCode >= 500) {
      debugPrint('SERVER ERROR: HTTP ${response.statusCode}');

      final contentType = response.headers['content-type'] ?? '';

      if (contentType.contains('text/plain')) {
        final preview = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;

        debugPrint('Server error preview: $preview');
      }

      debugPrint('Check the FastAPI terminal for the server traceback.');
    }

    if (response.statusCode == 200) {
      debugPrint('API request completed successfully.');
      return response;
    }

    if (response.statusCode == 401) {
      throw Exception('Your session is unauthorized. Please sign in again.');
    }

    if (response.statusCode == 403) {
      throw Exception('Your account cannot access requests.');
    }

    if (response.statusCode == 404) {
      throw Exception('This request could not be found.');
    }

    if (response.statusCode >= 500) {
      throw Exception(
        'The request service is temporarily unavailable. '
        'Please retry.',
      );
    }

    throw Exception('Unable to load requests (${response.statusCode}).');
  }

  /// Releases the HTTP client owned by this service.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
