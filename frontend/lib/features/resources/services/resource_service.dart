import '../../requests/services/request_service.dart';
import '../models/community_resource.dart';

abstract class ResourceRepository {
  Future<List<CommunityResource>> getResources({
    String? area,
    String? category,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int limit = 100,
    int offset = 0,
  });

  Future<CommunityResource> getResourceDetail(String resourceId);
}

class ResourceService implements ResourceRepository {
  final RequestService _transport;
  final bool _ownsTransport;

  ResourceService({RequestService? transport})
    : _transport = transport ?? RequestService(),
      _ownsTransport = transport == null;

  @override
  Future<List<CommunityResource>> getResources({
    String? area,
    String? category,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int limit = 100,
    int offset = 0,
  }) async {
    if ((latitude == null) != (longitude == null)) {
      throw const RequestApiException(
        'Latitude and longitude must be provided together.',
      );
    }

    if (radiusKm != null && latitude == null) {
      throw const RequestApiException('A search radius requires coordinates.');
    }

    if (latitude != null &&
        (!latitude.isFinite || latitude < -90 || latitude > 90)) {
      throw const RequestApiException('Invalid latitude.');
    }

    if (longitude != null &&
        (!longitude.isFinite || longitude < -180 || longitude > 180)) {
      throw const RequestApiException('Invalid longitude.');
    }

    if (radiusKm != null &&
        (!radiusKm.isFinite || radiusKm <= 0 || radiusKm > 100)) {
      throw const RequestApiException(
        'Search radius must be between 0 and 100 km.',
      );
    }

    if (limit < 1 || limit > 100 || offset < 0 || offset > 10000) {
      throw const RequestApiException('Invalid resource pagination.');
    }

    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (area != null && area.trim().isNotEmpty) 'area': area.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (radiusKm != null) 'radius_km': radiusKm.toString(),
    };

    final result = await _transport.requestJson(
      'GET',
      '/resources',
      operation: 'load resources',
      query: query,
    );

    try {
      if (result is! List) {
        throw const FormatException('Expected a resource list.');
      }

      return result
          .map(
            (item) => CommunityResource.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      throw const RequestApiException(
        'The server returned an unexpected resource response.',
      );
    }
  }

  @override
  Future<CommunityResource> getResourceDetail(String resourceId) async {
    final result = await _transport.requestJson(
      'GET',
      '/resources/${Uri.encodeComponent(resourceId)}',
      operation: 'load resource details',
    );

    try {
      return CommunityResource.fromJson(result as Map<String, dynamic>);
    } catch (_) {
      throw const RequestApiException(
        'The server returned unexpected resource details.',
      );
    }
  }

  void dispose() {
    if (_ownsTransport) {
      _transport.dispose();
    }
  }
}
