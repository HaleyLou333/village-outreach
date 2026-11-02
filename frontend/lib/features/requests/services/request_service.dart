
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/help_request.dart';

/// Structured API exception for form and owner-action handling.
class RequestApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;
  final List<dynamic> fields;

  const RequestApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.fields = const [],
  });

  @override
  String toString() => message;
}

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

  Future<HelpRequest> createRequest({
    required Map<String, dynamic> data,
    required String idempotencyKey,
  });

  Future<HelpRequest> updateRequest({
    required String requestId,
    required Map<String, dynamic> changes,
  });
}

/// Handles communication with the Village Outreach FastAPI backend.
class RequestService implements RequestRepository {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');

  final SupabaseClient _supabase;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  RequestService({
    SupabaseClient? supabase,
    http.Client? httpClient,
  }) : _supabase = supabase ?? Supabase.instance.client,
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

    final response = await _authorizedRequest(
      'GET',
      uri,
      operation: 'view requests',
    );

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw const FormatException('Expected a list of requests.');
      }

      final requests = decoded
          .map(
            (item) => HelpRequest.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      debugPrint('Requests returned: ${requests.length}');
      debugPrint('=====================================');

      return requests;
    } catch (error) {
      debugPrint('Failed to parse nearby requests: $error');

      throw const RequestApiException(
        'The server returned an unexpected requests response.',
      );
    }
  }

  /// Retrieves the full details of a single request.
  @override
  Future<HelpRequest> getRequestDetail(String requestId) async {
    final uri = _buildUri(
      '/requests/${Uri.encodeComponent(requestId)}',
    );

    debugPrint('========== REQUEST DETAILS ==========');
    debugPrint('Request ID: $requestId');

    final response = await _authorizedRequest(
      'GET',
      uri,
      operation: 'view requests',
    );

    final request = _decodeRequest(response);

    debugPrint('Request details loaded successfully.');
    debugPrint('=====================================');

    return request;
  }

  /// Creates a request using a caller-provided idempotency key.
  ///
  /// IMPORTANT:
  /// The caller must reuse the same key AND unchanged payload when
  /// retrying an uncertain submission. A new request needs a new key.
  @override
  Future<HelpRequest> createRequest({
    required Map<String, dynamic> data,
    required String idempotencyKey,
  }) async {
    final uri = _buildUri('/requests');

    if (!RegExp(
      r'^[A-Za-z0-9._:-]{8,128}$',
    ).hasMatch(idempotencyKey)) {
      throw const RequestApiException(
        'Invalid request submission key.',
      );
    }

    debugPrint('========== CREATE REQUEST ==========');

    final response = await _authorizedRequest(
      'POST',
      uri,
      operation: 'create requests',
      body: data,
      additionalHeaders: {
        'Idempotency-Key': idempotencyKey,
      },
    );

    final request = _decodeRequest(response);

    debugPrint('Request created or retrieved successfully.');
    debugPrint('HTTP status: ${response.statusCode}');
    debugPrint('====================================');

    return request;
  }

  /// Updates an existing request.
  ///
  /// The backend enforces ownership and rejects changes to
  /// completed or canceled requests.
  @override
  Future<HelpRequest> updateRequest({
    required String requestId,
    required Map<String, dynamic> changes,
  }) async {
    if (changes.isEmpty) {
      throw const RequestApiException(
        'At least one field must be updated.',
      );
    }

    final uri = _buildUri(
      '/requests/${Uri.encodeComponent(requestId)}',
    );

    debugPrint('========== UPDATE REQUEST ==========');
    debugPrint('Request ID: $requestId');

    final response = await _authorizedRequest(
      'PATCH',
      uri,
      operation: 'update requests',
      body: changes,
    );

    final request = _decodeRequest(response);

    debugPrint('Request updated successfully.');
    debugPrint('====================================');

    return request;
  }

  /// Builds API URLs and validates configuration.
  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    if (_baseUrl.trim().isEmpty) {
      debugPrint('CONFIGURATION ERROR: API_BASE_URL is missing.');

      throw const RequestApiException(
        'API configuration is missing. '
        'Check frontend/config/dev.json.',
      );
    }

    final baseUri = Uri.tryParse(_baseUrl);

    if (baseUri == null ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
        baseUri.host.isEmpty) {
      throw const RequestApiException(
        'API_BASE_URL must be a valid HTTP or HTTPS URL.',
      );
    }

    final normalizedBase = _baseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );

    return Uri.parse('$normalizedBase$path').replace(
      queryParameters: queryParameters,
    );
  }

  /// Performs authenticated GET, POST, and PATCH operations.
  ///
  /// A 401 response triggers one Supabase token refresh.
  /// The original request is retried with the refreshed token.
  Future<http.Response> _authorizedRequest(
    String method,
    Uri uri, {
    required String operation,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    debugPrint('-------------------------------------');
    debugPrint('API Request: $method $uri');

    var token = _supabase.auth.currentSession?.accessToken;

    if (token == null || token.isEmpty) {
      debugPrint('AUTH ERROR: No active Supabase session.');

      throw const RequestApiException(
        'You must be signed in to continue.',
        statusCode: 401,
      );
    }

    debugPrint('Supabase session: Available');

    Future<http.Response> send(String accessToken) async {
      final headers = <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        ...?additionalHeaders,
      };

      final encodedBody = body == null ? null : jsonEncode(body);

      switch (method) {
        case 'GET':
          return _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));

        case 'POST':
          return _httpClient
              .post(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(const Duration(seconds: 15));

        case 'PATCH':
          return _httpClient
              .patch(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(const Duration(seconds: 15));

        default:
          throw const RequestApiException(
            'Unsupported HTTP operation.',
          );
      }
    }

    http.Response response;

    try {
      response = await send(token);
    } catch (error) {
      debugPrint('NETWORK ERROR during $operation: $error');

      throw const RequestApiException(
        'Unable to connect to the request service. '
        'Check your connection and try again.',
      );
    }

    debugPrint('Initial HTTP status: ${response.statusCode}');

    if (response.statusCode == 401) {
      debugPrint('HTTP 401: Attempting token refresh.');

      try {
        final refreshed = await _supabase.auth.refreshSession();

        token = refreshed.session?.accessToken;

        if (token == null || token.isEmpty) {
          throw const RequestApiException(
            'No refreshed access token.',
          );
        }
      } catch (error) {
        debugPrint('TOKEN REFRESH ERROR: $error');

        throw const RequestApiException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }

      try {
        response = await send(token);
        debugPrint(
          'HTTP status after refresh: ${response.statusCode}',
        );
      } catch (error) {
        debugPrint('NETWORK ERROR after token refresh: $error');

        throw const RequestApiException(
          'Unable to connect to the request service. '
          'Please try again.',
        );
      }
    }

    debugPrint('Final HTTP status: ${response.statusCode}');
    debugPrint(
      'Response content type: '
      '${response.headers['content-type'] ?? 'unknown'}',
    );

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      debugPrint('API request completed successfully.');
      return response;
    }

    throw _parseApiError(response, operation);
  }

  /// Converts backend error responses into user-friendly errors.
  RequestApiException _parseApiError(
    http.Response response,
    String operation,
  ) {
    String? detail;
    String? code;
    List<dynamic> fields = const [];

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final rawDetail = decoded['detail'];

        if (rawDetail is String) {
          detail = rawDetail;
        }

        if (decoded['code'] is String) {
          code = decoded['code'] as String;
        }

        if (decoded['fields'] is List) {
          fields = decoded['fields'] as List<dynamic>;
        }
      }
    } catch (_) {
      // Keep a generic error if the response is not JSON.
    }

    debugPrint(
      'API ERROR: $operation failed with HTTP '
      '${response.statusCode}',
    );

    switch (response.statusCode) {
      case 400:
        return RequestApiException(
          detail ?? 'The request could not be processed.',
          statusCode: 400,
          code: code,
          fields: fields,
        );

      case 401:
        return const RequestApiException(
          'Your session is unauthorized. Please sign in again.',
          statusCode: 401,
        );

      case 403:
        return const RequestApiException(
          'You do not have permission to modify this request.',
          statusCode: 403,
        );

      case 404:
        return const RequestApiException(
          'This request could not be found.',
          statusCode: 404,
        );

      case 409:
        return RequestApiException(
          detail ?? 'This request conflicts with an existing operation.',
          statusCode: 409,
          code: code,
          fields: fields,
        );

      case 422:
        return RequestApiException(
          detail ?? 'Please review the information entered.',
          statusCode: 422,
          code: code,
          fields: fields,
        );

      case 503:
        return const RequestApiException(
          'The request service is temporarily unavailable. '
          'Please retry.',
          statusCode: 503,
        );

      default:
        if (response.statusCode >= 500) {
          return RequestApiException(
            'The request service is temporarily unavailable. '
            'Please retry.',
            statusCode: response.statusCode,
          );
        }

        return RequestApiException(
          detail ?? 'Unable to complete the request.',
          statusCode: response.statusCode,
          code: code,
          fields: fields,
        );
    }
  }

  /// Parses a successful single-request response.
  HelpRequest _decodeRequest(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Expected a request object.',
        );
      }

      return HelpRequest.fromJson(decoded);
    } catch (error) {
      debugPrint('Failed to parse request response: $error');

      throw const RequestApiException(
        'The server returned an unexpected request response.',
      );
    }
  }

  /// Releases the HTTP client owned by this service.
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
