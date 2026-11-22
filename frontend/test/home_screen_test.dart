import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/home/home_screen.dart';
import 'package:village_outreach/features/requests/models/help_request.dart';
import 'package:village_outreach/features/requests/services/request_service.dart';

class RequestSearchCall {
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String? category;
  final String? urgency;
  final int limit;
  final int offset;

  const RequestSearchCall({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.category,
    required this.urgency,
    required this.limit,
    required this.offset,
  });
}

typedef SearchHandler = Future<List<HelpRequest>> Function(
  RequestSearchCall call,
);

class FakeRequestRepository implements RequestRepository {
  final List<HelpRequest> requests = [];
  final List<double> searchedLongitudes = [];
  final List<RequestSearchCall> searchCalls = [];

  SearchHandler? searchHandler;

  @override
  Future<List<HelpRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? category,
    String? urgency,
    int limit = 20,
    int offset = 0,
  }) async {
    final call = RequestSearchCall(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      category: category,
      urgency: urgency,
      limit: limit,
      offset: offset,
    );

    searchedLongitudes.add(longitude);
    searchCalls.add(call);

    if (searchHandler != null) {
      return searchHandler!(call);
    }

    final matching = requests.where((request) {
      if (!request.isActive) return false;
      if (request.longitude != longitude) return false;
      if (category != null && request.category != category) {
        return false;
      }
      if (urgency != null && request.urgency != urgency) {
        return false;
      }
      return true;
    }).toList();

    return matching.skip(offset).take(limit).toList();
  }

  @override
  Future<HelpRequest> getRequestDetail(String requestId) async {
    throw UnimplementedError();
  }

  @override
  Future<HelpRequest> createRequest({
    required Map<String, dynamic> data,
    required String idempotencyKey,
  }) async {
    final request = HelpRequest.fromJson({
      ...data,
      'id': 'created-request',
      'requester_id': 'requester',
      'status': 'active',
      'created_at': '2026-11-08T12:00:00Z',
      'updated_at': '2026-11-08T12:00:00Z',
    });

    requests.add(request);
    return request;
  }

  @override
  Future<HelpRequest> updateRequest({
    required String requestId,
    required Map<String, dynamic> changes,
  }) async {
    throw UnimplementedError();
  }
}

HelpRequest makeRequest(
  int index, {
  String category = 'FOOD_ASSISTANCE',
  String urgency = 'standard',
  double longitude = -112.0740,
}) {
  return HelpRequest.fromJson({
    'id': 'request-$index',
    'requester_id': 'requester-$index',
    'title': 'Test Request $index',
    'description': 'A test request for the community.',
    'category': category,
    'urgency': urgency,
    'latitude': 33.4484,
    'longitude': longitude,
    'area': 'Downtown Phoenix',
    'status': 'active',
    'created_at': '2026-11-08T12:00:00Z',
    'updated_at': '2026-11-08T12:00:00Z',
    'distance_km': 2.0,
  });
}

Future<void> loadHomeScreen(
  WidgetTester tester,
  FakeRequestRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(requestRepository: repository)),
  );

  await tester.pumpAndSettle();
}

Finder categoryDropdown() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String?> &&
        widget.decoration.labelText == 'Category filter',
    skipOffstage: false,
  );
}

Finder urgencyDropdown() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String?> &&
        widget.decoration.labelText == 'Urgency filter',
    skipOffstage: false,
  );
}

Finder distanceDropdown() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<double> &&
        widget.decoration.labelText == 'Distance filter',
    skipOffstage: false,
  );
}

Future<void> selectCategory(WidgetTester tester, String category) async {
  final dropdown = categoryDropdown();

  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
}

Future<void> selectUrgency(WidgetTester tester, String urgency) async {
  final dropdown = urgencyDropdown();

  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(find.text(urgency).last);
  await tester.pumpAndSettle();
}

Future<void> selectDistance(WidgetTester tester, String distance) async {
  final dropdown = distanceDropdown();

  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(find.text(distance).last);
  await tester.pumpAndSettle();
}

Future<void> tapClearAll(WidgetTester tester) async {
  final button = find.byKey(
    const Key('clear-request-filters'),
    skipOffstage: false,
  );

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Finds the refresh control even when the Home Screen has
/// been scrolled down to the filter controls.
Future<void> tapRefresh(WidgetTester tester) async {
  final refreshButton = find.byTooltip(
    'Refresh nearby requests',
    skipOffstage: false,
  );

  final scrollable = find.byType(Scrollable).first;

  await tester.scrollUntilVisible(refreshButton, -200, scrollable: scrollable);

  await tester.pumpAndSettle();
  await tester.tap(refreshButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Posting in Mesa switches Nearby to Mesa and refresh removes a closed request',
    (tester) async {
      tester.view.physicalSize = const Size(414, 1000);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeRequestRepository();

      await loadHomeScreen(tester, repository);

      expect(repository.searchedLongitudes.single, -112.0740);

      await tester.tap(find.text('Request Help'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Mesa grocery pickup',
      );

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Please pick up groceries.',
      );

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Food Assistance').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Area'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Downtown Mesa').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Request'));
      await tester.pumpAndSettle();

      expect(repository.searchedLongitudes.last, -111.8315);

      await tester.scrollUntilVisible(
        find.text('Mesa grocery pickup'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Mesa grocery pickup'), findsOneWidget);

      repository.requests.clear();

      await tapRefresh(tester);

      expect(repository.searchedLongitudes.last, -111.8315);
      expect(find.text('Mesa grocery pickup'), findsNothing);
    },
  );

  testWidgets('Home screen displays Village Outreach branding', (tester) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    expect(find.text('Village Outreach'), findsOneWidget);
    expect(find.text('Neighbors helping neighbors'), findsOneWidget);
    expect(find.text('Request Help'), findsOneWidget);
    expect(find.text('Offer Help'), findsOneWidget);
  });

  testWidgets('Home never exposes an access-token copy control', (
    tester,
  ) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    expect(find.byTooltip('Copy JWT for API testing'), findsNothing);
    expect(find.byIcon(Icons.key_outlined), findsNothing);
  });

  testWidgets('Home screen displays nearby requests section', (tester) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    expect(find.text('Nearby Requests'), findsOneWidget);
    expect(find.text('Live requests from your community'), findsOneWidget);
  });

  testWidgets('Home screen handles an empty request feed', (tester) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    await tester.scrollUntilVisible(
      find.textContaining('No active requests found nearby'),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('No active requests found nearby'),
      findsOneWidget,
    );
  });

  testWidgets('Home screen displays request filters', (tester) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    expect(find.text('All categories'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Within 10 km'),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(find.text('Within 10 km'), findsOneWidget);
  });

  testWidgets('Home screen displays bottom navigation', (tester) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Resources'), findsWidgets);
    expect(find.text('Help'), findsWidgets);
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('Request Help opens the request creation form', (tester) async {
    await loadHomeScreen(tester, FakeRequestRepository());

    await tester.tap(find.text('Request Help'));
    await tester.pumpAndSettle();

    expect(find.text('Request title'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    expect(find.text('Submit Request', skipOffstage: false), findsOneWidget);
  });

  group('CCVO-76 Combined Request Filters', () {
    testWidgets('Category, urgency, and distance are sent together', (
      tester,
    ) async {
      final repository = FakeRequestRepository();

      await loadHomeScreen(tester, repository);

      await selectCategory(tester, 'Food Assistance');
      await selectUrgency(tester, 'Time-sensitive');
      await selectDistance(tester, 'Within 25 km');

      final call = repository.searchCalls.last;

      expect(call.category, 'FOOD_ASSISTANCE');
      expect(call.urgency, 'time_sensitive');
      expect(call.radiusKm, 25);
      expect(call.limit, 20);
      expect(call.offset, 0);
    });

    testWidgets('Selections persist after refreshing', (tester) async {
      final repository = FakeRequestRepository();

      await loadHomeScreen(tester, repository);

      await selectCategory(tester, 'Transportation');
      await selectUrgency(tester, 'Standard');
      await selectDistance(tester, 'Within 50 km');

      await tapRefresh(tester);

      final call = repository.searchCalls.last;

      expect(call.category, 'TRANSPORTATION');
      expect(call.urgency, 'standard');
      expect(call.radiusKm, 50);

      expect(find.text('Transportation', skipOffstage: false), findsWidgets);
      expect(find.text('Standard', skipOffstage: false), findsWidgets);
      expect(find.text('Within 50 km', skipOffstage: false), findsWidgets);
    });

    testWidgets('Clear All restores default filters and reloads', (
      tester,
    ) async {
      final repository = FakeRequestRepository();

      await loadHomeScreen(tester, repository);

      await selectCategory(tester, 'Childcare');
      await selectUrgency(tester, 'Time-sensitive');
      await selectDistance(tester, 'Within 100 km');

      final callsBeforeReset = repository.searchCalls.length;

      await tapClearAll(tester);

      expect(repository.searchCalls.length, callsBeforeReset + 1);

      final call = repository.searchCalls.last;

      expect(call.category, isNull);
      expect(call.urgency, isNull);
      expect(call.radiusKm, 10);
      expect(call.longitude, -112.0740);
      expect(call.offset, 0);

      expect(find.byKey(const Key('clear-request-filters')), findsNothing);
    });

    testWidgets('No-match state offers recovery through Clear All', (
      tester,
    ) async {
      final repository = FakeRequestRepository();

      repository.requests.add(makeRequest(1));

      await loadHomeScreen(tester, repository);

      await selectCategory(tester, 'Transportation');

      await tester.scrollUntilVisible(
        find.textContaining('No requests match your filters'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.textContaining('No requests match your filters'),
        findsOneWidget,
      );

      final clearButton = find.byKey(const Key('empty-clear-filters'));

      await tester.ensureVisible(clearButton);
      await tester.pumpAndSettle();

      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(repository.searchCalls.last.category, isNull);

      await tester.scrollUntilVisible(
        find.text('Test Request 1'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Test Request 1'), findsOneWidget);
    });

    testWidgets('Load More preserves filters and uses correct offset', (
      tester,
    ) async {
      final repository = FakeRequestRepository();

      repository.searchHandler = (call) async {
        if (call.offset == 0) {
          return List.generate(
            20,
            (index) => makeRequest(
              index,
              category: 'FOOD_ASSISTANCE',
              urgency: 'time_sensitive',
            ),
          );
        }

        if (call.offset == 20) {
          return [
            makeRequest(
              20,
              category: 'FOOD_ASSISTANCE',
              urgency: 'time_sensitive',
            ),
          ];
        }

        return [];
      };

      await loadHomeScreen(tester, repository);

      await selectCategory(tester, 'Food Assistance');
      await selectUrgency(tester, 'Time-sensitive');
      await selectDistance(tester, 'Within 25 km');

      final loadMore = find.text('Load More');

      await tester.scrollUntilVisible(
        loadMore,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      final call = repository.searchCalls.last;

      expect(call.offset, 20);
      expect(call.limit, 20);
      expect(call.category, 'FOOD_ASSISTANCE');
      expect(call.urgency, 'time_sensitive');
      expect(call.radiusKm, 25);

      expect(find.text('Test Request 20', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Older API responses cannot overwrite newer filters', (
      tester,
    ) async {
      final repository = FakeRequestRepository();

      final oldResponse = Completer<List<HelpRequest>>();
      final newResponse = Completer<List<HelpRequest>>();

      repository.searchHandler = (call) {
        if (call.category == 'FOOD_ASSISTANCE') {
          return oldResponse.future;
        }

        if (call.category == 'TRANSPORTATION') {
          return newResponse.future;
        }

        return Future.value([]);
      };

      await loadHomeScreen(tester, repository);

      // Open the category dropdown and select Food Assistance.
      final firstDropdown = categoryDropdown();

      await tester.ensureVisible(firstDropdown);
      await tester.pumpAndSettle();

      await tester.tap(firstDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Food Assistance').last);

      // Do not pumpAndSettle while the fake API request is
      // deliberately unresolved.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.searchCalls.last.category, 'FOOD_ASSISTANCE');

      // The dropdown may have been rebuilt with a new key.
      // Find its current instance rather than reusing the old finder.
      final updatedDropdown = categoryDropdown();

      await tester.ensureVisible(updatedDropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(updatedDropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Transportation').last);
      await tester.pump();

      expect(repository.searchCalls.last.category, 'TRANSPORTATION');

      // The newer request finishes first.
      newResponse.complete([makeRequest(2, category: 'TRANSPORTATION')]);

      // Allow the newer response to update the Home Screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The older response arrives afterward.
      oldResponse.complete([makeRequest(1, category: 'FOOD_ASSISTANCE')]);

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Test Request 2'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Test Request 2'), findsOneWidget);

      expect(find.text('Test Request 1', skipOffstage: false), findsNothing);

      expect(repository.searchCalls.last.category, 'TRANSPORTATION');
    });
  });
}
