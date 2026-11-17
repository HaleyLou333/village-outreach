class CommunityResource {
  final String id;
  final String name;
  final String category;
  final String area;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? website;
  final String sourceUrl;
  final DateTime lastVerifiedAt;

  const CommunityResource({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.website,
    required this.sourceUrl,
    required this.lastVerifiedAt,
  });

  factory CommunityResource.fromJson(Map<String, dynamic> json) {
    return CommunityResource(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      area: json['area'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      sourceUrl: json['source_url'] as String,
      lastVerifiedAt: DateTime.parse(json['last_verified_at'] as String),
    );
  }

  String get categoryLabel {
    return category
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String get verificationDate {
    final date = lastVerifiedAt.toUtc();

    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
