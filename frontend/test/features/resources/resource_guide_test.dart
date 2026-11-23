import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/resources/models/resource_guide.dart';
import 'package:village_outreach/features/resources/screens/resource_guide_screen.dart';
import 'package:village_outreach/features/resources/services/resource_guide_service.dart';

class FakeGuides implements ResourceGuideRepository {
  final List<ResourceGuide> guides;
  FakeGuides(this.guides);
  @override
  Future<List<ResourceGuide>> list({
    String? area,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async => guides
      .where(
        (g) =>
            (area == null ||
                area.isEmpty ||
                g.area.toLowerCase() == area.toLowerCase()) &&
            (category == null || category.isEmpty || g.category == category),
      )
      .skip(offset)
      .take(limit)
      .toList();
  @override
  Future<ResourceGuide> detail(String id) async =>
      guides.firstWhere((g) => g.id == id);
}

void main() {
  test('guide parses the published API shape', () {
    final guide = ResourceGuide.fromJson({
      'id': 'guide-1',
      'title': 'Food support',
      'category': 'food_assistance',
      'area': 'Phoenix',
      'source_url': 'https://example.org',
      'reviewed_at': '2026-11-01T12:00:00Z',
      'body': 'Ask for help',
    });
    expect(guide.body, 'Ask for help');
    expect(guide.reviewedAt.isUtc, isTrue);
  });

  testWidgets('empty published list offers return to resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ResourceGuideScreen(repository: FakeGuides([]))),
    );
    await tester.pumpAndSettle();
    expect(find.text('No published guides match your search.'), findsOneWidget);
    expect(find.text('Return to resource search'), findsOneWidget);
  });

  testWidgets('opens a published guide and shows source metadata', (
    tester,
  ) async {
    final guide = ResourceGuide(
      id: '1',
      title: 'Food support',
      category: 'food_assistance',
      area: 'Phoenix',
      sourceUrl: 'https://example.org',
      reviewedAt: DateTime.utc(2026, 11, 1),
      body: 'Find food nearby.',
    );
    await tester.pumpWidget(
      MaterialApp(home: ResourceGuideScreen(repository: FakeGuides([guide]))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food support'));
    await tester.pumpAndSettle();
    expect(find.text('Find food nearby.'), findsOneWidget);
    expect(find.text('Source reviewed: 2026-11-01'), findsOneWidget);
  });
}
