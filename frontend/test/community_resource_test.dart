import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/resources/models/community_resource.dart';

void main() {
  group('CCVO-69 CommunityResource', () {
    final json = <String, dynamic>{
      'id': 'resource-001',
      'name': 'Test Community Food Pantry',
      'category': 'food_assistance',
      'area': 'Phoenix',
      'address': 'Example test address',
      'latitude': 33.4484,
      'longitude': -112.0740,
      'phone': '555-0100',
      'website': 'https://example.com',
      'source_url': 'https://example.com/resources',
      'last_verified_at': '2026-11-14T12:00:00Z',
    };

    test('parses resource API response', () {
      final resource = CommunityResource.fromJson(json);

      expect(resource.id, 'resource-001');
      expect(resource.name, 'Test Community Food Pantry');
      expect(resource.category, 'food_assistance');
      expect(resource.area, 'Phoenix');
      expect(resource.latitude, 33.4484);
      expect(resource.longitude, -112.0740);
      expect(resource.phone, '555-0100');
      expect(resource.website, 'https://example.com');
      expect(resource.sourceUrl, 'https://example.com/resources');
    });

    test('formats category label', () {
      final resource = CommunityResource.fromJson(json);

      expect(resource.categoryLabel, 'Food Assistance');
    });

    test('formats verification date', () {
      final resource = CommunityResource.fromJson(json);

      expect(resource.verificationDate, '11/14/2026');
    });

    test('supports missing optional contact information', () {
      final resource = CommunityResource.fromJson({
        ...json,
        'phone': null,
        'website': null,
      });

      expect(resource.phone, isNull);
      expect(resource.website, isNull);
    });
  });
}
