import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/home/home_screen.dart';
import 'package:village_outreach/features/requests/models/help_request.dart';
import 'package:village_outreach/features/requests/services/request_service.dart';

/// Fake repository used to isolate HomeScreen widget tests
/// from the real FastAPI backend and Supabase authentication.
class FakeRequestRepository implements RequestRepository {
  final List<HelpRequest> requests = [];
  final List<double> searchedLongitudes = [];

  @override
  Future<List<HelpRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
    int offset = 0,
  }) async {
    searchedLongitudes.add(longitude);
    return requests
        .where((request) => request.longitude == longitude && request.isActive)
        .toList();
  }

  @override
  Future<HelpRequest> getRequestDetail(String requestId) async {
    throw UnimplementedError(
      'Request detail retrieval is not used in these tests.',
    );
  }

  /// CCVO-66: Required by the updated RequestRepository interface.
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

  /// CCVO-66: Required by the updated RequestRepository interface.
  @override
  Future<HelpRequest> updateRequest({
    required String requestId,
    required Map<String, dynamic> changes,
  }) async {
    throw UnimplementedError(
      'Request updates are not exercised by these tests.',
    );
  }
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
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(requestRepository: repository)),
      );
      await tester.pumpAndSettle();
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
      expect(find.text('Mesa grocery pickup'), findsOneWidget);

      // The next server response no longer includes a request closed elsewhere.
      repository.requests.clear();
      await tester.tap(find.byTooltip('Refresh nearby requests'));
      await tester.pumpAndSettle();
      expect(repository.searchedLongitudes.last, -111.8315);
      expect(find.text('Mesa grocery pickup'), findsNothing);
    },
  );

  Future<void> loadHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(requestRepository: FakeRequestRepository())),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Home screen displays Village Outreach branding', (tester) async {
    await loadHomeScreen(tester);

    expect(find.text('Village Outreach'), findsOneWidget);
    expect(find.text('Neighbors helping neighbors'), findsOneWidget);
    expect(find.text('Request Help'), findsOneWidget);
    expect(find.text('Offer Help'), findsOneWidget);
  });

  testWidgets('Home never exposes an access-token copy control', (
    tester,
  ) async {
    await loadHomeScreen(tester);
    expect(find.byTooltip('Copy JWT for API testing'), findsNothing);
    expect(find.byIcon(Icons.key_outlined), findsNothing);
  });

  testWidgets('Home screen displays nearby requests section', (tester) async {
    await loadHomeScreen(tester);

    expect(find.text('Nearby Requests'), findsOneWidget);
    expect(find.text('Live requests from your community'), findsOneWidget);
  });

  testWidgets('Home screen handles an empty request feed', (tester) async {
    await loadHomeScreen(tester);

    expect(
      find.textContaining('No active requests found nearby'),
      findsOneWidget,
    );
  });

  testWidgets('Home screen displays request filters', (tester) async {
    await loadHomeScreen(tester);

    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Within 10 km'), findsOneWidget);
  });

  testWidgets('Home screen displays bottom navigation', (tester) async {
    await loadHomeScreen(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Community'), findsWidgets);
    expect(find.text('Help'), findsWidgets);
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  // CCVO-66: Verify Request Help opens the creation form.
  testWidgets('Request Help opens the request creation form', (tester) async {
    await loadHomeScreen(tester);

    await tester.tap(find.text('Request Help'));
    await tester.pumpAndSettle();

    // The creation screen should display its form fields.
    expect(find.text('Request title'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    // Verify the submit button exists.
    // The form may require scrolling to reveal it.
    expect(find.text('Submit Request', skipOffstage: false), findsOneWidget);
  });
}
