import '../../requests/services/request_service.dart';
import '../models/resource_guide.dart';

abstract class ResourceGuideRepository {
  Future<List<ResourceGuide>> list({
    String? area,
    String? category,
    int limit = 20,
    int offset = 0,
  });
  Future<ResourceGuide> detail(String id);
}

class ResourceGuideService implements ResourceGuideRepository {
  final RequestService _transport;
  final bool _ownsTransport;
  ResourceGuideService({RequestService? transport})
    : _transport = transport ?? RequestService(),
      _ownsTransport = transport == null;

  @override
  Future<List<ResourceGuide>> list({
    String? area,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0 || offset > 10000) {
      throw const RequestApiException('Invalid guide pagination.');
    }
    final data = await _transport.requestJson(
      'GET',
      '/resource-guides',
      operation: 'load published guides',
      query: {
        'limit': '$limit',
        'offset': '$offset',
        if (area != null && area.trim().isNotEmpty) 'area': area.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
      },
    );
    if (data is! List) {
      throw const RequestApiException('Invalid guide list response.');
    }
    try {
      return data
          .map((e) => ResourceGuide.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const RequestApiException('Invalid guide list response.');
    }
  }

  @override
  Future<ResourceGuide> detail(String id) async {
    final data = await _transport.requestJson(
      'GET',
      '/resource-guides/${Uri.encodeComponent(id)}',
      operation: 'load published guide',
    );
    try {
      return ResourceGuide.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      throw const RequestApiException('Invalid guide detail response.');
    }
  }

  void dispose() {
    if (_ownsTransport) _transport.dispose();
  }
}
