import '../../requests/services/request_service.dart';

class OrganizationMembership {
  final String organizationId;
  final String name;
  final String role;
  final String status;
  final bool isActive;
  const OrganizationMembership({
    required this.organizationId,
    required this.name,
    required this.role,
    required this.status,
    required this.isActive,
  });
  bool get canManage => isActive && status == 'approved';
  factory OrganizationMembership.fromJson(Map<String, dynamic> json) =>
      OrganizationMembership(
        organizationId: json['organization_id'] as String,
        name: json['organization_name'] as String,
        role: json['role'] as String,
        status: json['approval_status'] as String,
        isActive: json['organization_is_active'] as bool,
      );
}

class ManagedResource {
  final String id;
  final String organizationId;
  final bool isActive;
  final Map<String, dynamic> fields;
  const ManagedResource({
    required this.id,
    required this.organizationId,
    required this.isActive,
    required this.fields,
  });
  factory ManagedResource.fromJson(Map<String, dynamic> json) =>
      ManagedResource(
        id: json['id'] as String,
        organizationId: json['organization_id'] as String,
        isActive: json['is_active'] as bool,
        fields: Map<String, dynamic>.from(json),
      );
  String get name => fields['name'] as String;
}

abstract class OrganizationResourceRepository {
  Future<List<OrganizationMembership>> memberships();
  Future<List<ManagedResource>> resources(String organizationId);
  Future<void> create(String organizationId, Map<String, dynamic> fields);
  Future<void> update(String resourceId, Map<String, dynamic> fields);
  Future<void> disable(String resourceId);
}

class OrganizationResourceService implements OrganizationResourceRepository {
  final RequestService _transport;
  final bool _ownsTransport;
  OrganizationResourceService({RequestService? transport})
    : _transport = transport ?? RequestService(),
      _ownsTransport = transport == null;

  @override
  Future<List<OrganizationMembership>> memberships() async {
    final json = await _transport.requestJson(
      'GET',
      '/organizations/mine',
      operation: 'load memberships',
    );
    if (json is! List) {
      throw const RequestApiException('Unexpected membership response.');
    }
    return json
        .map(
          (item) =>
              OrganizationMembership.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<List<ManagedResource>> resources(String organizationId) async {
    final json = await _transport.requestJson(
      'GET',
      '/organizations/${Uri.encodeComponent(organizationId)}/resources',
      operation: 'load managed resources',
    );
    if (json is! List) {
      throw const RequestApiException(
        'Unexpected organization resource response.',
      );
    }
    return json
        .map((item) => ManagedResource.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create(
    String organizationId,
    Map<String, dynamic> fields,
  ) async {
    await _transport.requestJson(
      'POST',
      '/resources',
      operation: 'create resource',
      body: {...fields, 'organization_id': organizationId},
    );
  }

  @override
  Future<void> update(String resourceId, Map<String, dynamic> fields) async {
    await _transport.requestJson(
      'PATCH',
      '/resources/${Uri.encodeComponent(resourceId)}',
      operation: 'update resource',
      body: fields,
    );
  }

  @override
  Future<void> disable(String resourceId) async {
    await _transport.requestJson(
      'DELETE',
      '/resources/${Uri.encodeComponent(resourceId)}',
      operation: 'disable resource',
    );
  }

  void dispose() {
    if (_ownsTransport) {
      _transport.dispose();
    }
  }
}
