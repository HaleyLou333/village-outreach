class HelpRequest {
  final String id;
  final String requesterId;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final double latitude;
  final double longitude;
  final String area;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? distanceKm;

  const HelpRequest({
    required this.id,
    required this.requesterId,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.distanceKm,
  });

  factory HelpRequest.fromJson(Map<String, dynamic> json) {
    return HelpRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      urgency: json['urgency'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      area: json['area'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  bool get isActive => status == 'active';

  bool get isClosed => status == 'completed' || status == 'canceled';

  String get categoryLabel => switch (category) {
    'FOOD_ASSISTANCE' => 'Food Assistance',
    'TRANSPORTATION' => 'Transportation',
    'CHILDCARE' => 'Childcare',
    'DONATED_ITEMS' => 'Donated Items',
    'DELIVERY_HELP' => 'Delivery Help',
    'LOCAL_SERVICES' => 'Local Services',
    _ => category,
  };

  String get urgencyLabel =>
      urgency == 'time_sensitive' ? 'Time-sensitive' : 'Standard';

  String get statusLabel => switch (status) {
    'active' => 'Active',
    'completed' => 'Completed',
    'canceled' => 'Canceled',
    _ => status,
  };

  String get distanceLabel {
    if (distanceKm == null) return 'Distance unavailable';

    final miles = distanceKm! * 0.621371;
    return '${miles.toStringAsFixed(1)} mi away';
  }
}
