class ResourceGuide {
  final String id;
  final String title;
  final String category;
  final String area;
  final String sourceUrl;
  final DateTime reviewedAt;
  final String? body;

  const ResourceGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.area,
    required this.sourceUrl,
    required this.reviewedAt,
    this.body,
  });

  factory ResourceGuide.fromJson(Map<String, dynamic> json) => ResourceGuide(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    area: json['area'] as String,
    sourceUrl: json['source_url'] as String,
    reviewedAt: DateTime.parse(json['reviewed_at'] as String),
    body: json['body'] as String?,
  );
}
