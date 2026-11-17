import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_outreach/features/resources/models/community_resource.dart';
import 'package:village_outreach/features/resources/screens/resource_screen.dart';
import 'package:village_outreach/features/resources/services/location_service.dart';
import 'package:village_outreach/features/resources/services/resource_service.dart';

CommunityResource makeResource() {
  return CommunityResource.fromJson({
    'id': '4b79cf48-a7c2-4b97-9543-f4cef86ffc2f',
    'name': 'Downtown Library',
    'category': 'library',
    'area': 'Oklahoma City Metro',
    'address': '300 Park Avenue',
    'latitude': 35.46879,
    'longitude': -97.518,
    'phone': '405-555-0100',
    'website': 'https://example.com/library',
    'source_url': 'https://example.com/source',
    'last_verified_at': '2026-11-10T00:00:00Z',
  });
}

class FakeResourceRepository implements ResourceRepository {
  List<CommunityResource> resources = [makeResource()];

  bool shouldFail = false;
  int calls = 0;

  String? lastArea;
  double? lastLatitude;
  double? lastLongitude;
  double? lastRadius;
  String? lastDetailId;

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
    calls++;

    lastArea = area;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastRadius = radiusKm;

    if (shouldFail) {
      throw Exception('Resource service unavailable');
    }

    return resources;
  }

  @override
  Future<CommunityResource> getResourceDetail(String resourceId) async {
    lastDetailId = resourceId;
    return resources.firstWhere((resource) => resource.id == resourceId);
  }
}

class FakeLocationRepository implements ResourceLocationRepository {
  ResourceLocationResult result;

  FakeLocationRepository(this.result);

  @override
  Future<ResourceLocationResult> getCurrentLocation() async {
    return result;
  }
}

Future<void> openResources(
  WidgetTester tester, {
  required FakeResourceRepository repository,
  ResourceLocationResult location = const ResourceLocationResult(
    status: ResourceLocationStatus.permissionDenied,
  ),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ResourceScreen(
        repository: repository,
        locationRepository: FakeLocationRepository(location),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

void main() {
  group('CCVO-69 Resource Discovery', () {
    testWidgets('Loads resources for the default area', (tester) async {
      final repository = FakeResourceRepository();

      await openResources(tester, repository: repository);

      expect(repository.lastArea, 'Oklahoma City Metro');

      await scrollTo(tester, find.text('Downtown Library'));

      expect(find.text('Downtown Library'), findsOneWidget);

      expect(find.text('1 resources found'), findsOneWidget);
    });

    testWidgets('Supports manual area searches', (tester) async {
      final repository = FakeResourceRepository();

      await openResources(tester, repository: repository);

      await tester.enterText(find.byType(TextField), 'Phoenix');

      await tester.tap(find.byTooltip('Search area'));

      await tester.pumpAndSettle();

      expect(repository.lastArea, 'Phoenix');
      expect(repository.lastLatitude, isNull);
      expect(repository.lastLongitude, isNull);
      expect(repository.calls, 2);
    });

    testWidgets('Uses GPS coordinates when available', (tester) async {
      final repository = FakeResourceRepository();

      await openResources(
        tester,
        repository: repository,
        location: const ResourceLocationResult(
          status: ResourceLocationStatus.available,
          latitude: 35.4676,
          longitude: -97.5164,
        ),
      );

      await tester.tap(find.text('Use my current location'));

      await tester.pumpAndSettle();

      expect(repository.lastArea, isNull);
      expect(repository.lastLatitude, 35.4676);
      expect(repository.lastLongitude, -97.5164);
      expect(repository.lastRadius, 10);

      expect(find.text('Showing resources within 10 km'), findsOneWidget);
    });

    testWidgets('Denied location preserves manual resource access', (
      tester,
    ) async {
      final repository = FakeResourceRepository();

      await openResources(tester, repository: repository);

      await tester.tap(find.text('Use my current location'));

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Location permission was denied. '
          'You can still search by area.',
        ),
        findsOneWidget,
      );

      expect(repository.calls, 1);

      await scrollTo(tester, find.text('Downtown Library'));

      expect(find.text('Downtown Library'), findsOneWidget);
    });

    testWidgets('Displays empty resource results', (tester) async {
      final repository = FakeResourceRepository()..resources = [];

      await openResources(tester, repository: repository);

      await scrollTo(tester, find.textContaining('No resources found'));

      expect(find.textContaining('No resources found'), findsOneWidget);
    });

    testWidgets('Displays an API failure and allows retry', (tester) async {
      final repository = FakeResourceRepository()..shouldFail = true;

      await openResources(tester, repository: repository);

      await scrollTo(tester, find.text('Retry'));

      expect(
        find.textContaining('Resources could not be loaded'),
        findsOneWidget,
      );

      repository.shouldFail = false;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Downtown Library'));

      expect(find.text('Downtown Library'), findsOneWidget);

      expect(repository.calls, 2);
    });

    testWidgets('Opens the selected resource details', (tester) async {
      final repository = FakeResourceRepository();

      await openResources(tester, repository: repository);

      await scrollTo(tester, find.text('Downtown Library'));

      await tester.tap(find.text('Downtown Library'));

      await tester.pumpAndSettle();

      expect(repository.lastDetailId, makeResource().id);

      expect(find.text('Downtown Library'), findsWidgets);

      expect(find.text('300 Park Avenue'), findsWidgets);
    });
  });
}
