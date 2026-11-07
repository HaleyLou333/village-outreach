import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:village_outreach/features/profile/profile_service.dart';
import 'package:village_outreach/features/profile/user_profile.dart';
import 'package:village_outreach/features/requests/models/help_request.dart';
import 'package:village_outreach/features/requests/screens/request_detail_screen.dart';
import 'package:village_outreach/features/requests/services/request_service.dart';

// ============================================================
// CCVO-66: Request Management Widget Tests
//
// Tests:
// 1. Owner sees management controls
// 2. Nonowner cannot see management controls
// 3. Completed requests cannot be managed
// 4. Canceled requests cannot be managed
// 5. Owner can mark a request completed
// 6. Owner can cancel a request
// 7. Dismissing confirmation does not update a request
//
// No real API requests are made.
// ============================================================

// Test identifiers.
const String ownerId = '95972aa0-2d05-4590-badf-7833215973ba';

const String otherUserId = 'f634df12-d11d-4ffb-9ebf-270f94ef4929';

const String requestId = '4b79cf48-a7c2-4b97-9543-f4cef86ffc2f';

// ============================================================
// Test Request Factory
// ============================================================

HelpRequest makeRequest({
  String requesterId = ownerId,
  String status = 'active',
  String title = 'Need grocery assistance',
}) {
  return HelpRequest.fromJson({
    'id': requestId,
    'requester_id': requesterId,
    'title': title,
    'description': 'Looking for help with groceries.',
    'category': 'FOOD_ASSISTANCE',
    'urgency': 'standard',
    'latitude': 33.45,
    'longitude': -112.07,
    'area': 'Central Phoenix',
    'status': status,
    'created_at': '2026-11-01T12:00:00Z',
    'updated_at': '2026-11-01T12:00:00Z',
  });
}

// ============================================================
// Fake Request Repository
// ============================================================

class FakeRequestRepository implements RequestRepository {
  HelpRequest request;

  int updateCalls = 0;
  Map<String, dynamic>? lastChanges;

  FakeRequestRepository(this.request);

  @override
  Future<HelpRequest> getRequestDetail(String id) async {
    return request;
  }

  @override
  Future<List<HelpRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
    int offset = 0,
  }) async {
    return [request];
  }

  @override
  Future<HelpRequest> createRequest({
    required Map<String, dynamic> data,
    required String idempotencyKey,
  }) async {
    throw UnimplementedError('Create request is not used in these tests.');
  }

  @override
  Future<HelpRequest> updateRequest({
    required String requestId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;
    lastChanges = Map<String, dynamic>.from(changes);

    final updatedJson = {
      'id': request.id,
      'requester_id': request.requesterId,
      'title': changes['title'] ?? request.title,
      'description': changes['description'] ?? request.description,
      'category': changes['category'] ?? request.category,
      'urgency': changes['urgency'] ?? request.urgency,
      'latitude': changes['latitude'] ?? request.latitude,
      'longitude': changes['longitude'] ?? request.longitude,
      'area': changes['area'] ?? request.area,
      'status': changes['status'] ?? request.status,
      'created_at': request.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    request = HelpRequest.fromJson(updatedJson);

    return request;
  }
}

// ============================================================
// Fake Profile Service
// ============================================================

class FakeProfileService extends ProfileService {
  final String applicationUserId;

  FakeProfileService(this.applicationUserId)
    : super(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        ),
        httpClient: http.Client(),
      );

  @override
  Future<UserProfile> getProfile() async {
    return UserProfile.fromJson({
      'id': applicationUserId,
      'email': 'test@example.com',
      'display_name': 'Test User',
      'role': 'user',
      'status': 'active',
      'created_at': '2026-11-01T12:00:00Z',
      'updated_at': '2026-11-01T12:00:00Z',
    });
  }
}

// ============================================================
// Widget Test Helpers
// ============================================================

Future<void> openDetails(
  WidgetTester tester, {
  required FakeRequestRepository repository,
  required String applicationUserId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RequestDetailScreen(
        requestId: requestId,
        requestRepository: repository,
        profileService: FakeProfileService(applicationUserId),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Scrolls the request details ListView until the
/// specified text is built and visible.
Future<void> scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    150,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

/// Opens the completion confirmation dialog.
Future<void> openCompleteDialog(WidgetTester tester) async {
  await scrollToText(tester, 'Mark Completed');

  await tester.tap(find.text('Mark Completed'));

  await tester.pumpAndSettle();
}

/// Opens the cancellation confirmation dialog.
Future<void> openCancelDialog(WidgetTester tester) async {
  await scrollToText(tester, 'Cancel Request');

  await tester.tap(find.text('Cancel Request'));

  await tester.pumpAndSettle();
}

// ============================================================
// Tests
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CCVO-66 Request Ownership', () {
    testWidgets('Owner sees management controls on an active request', (
      tester,
    ) async {
      final repository = FakeRequestRepository(makeRequest());

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      // Verify the owner can access all management controls.
      await scrollToText(tester, 'Manage Your Request');

      expect(find.text('Manage Your Request'), findsOneWidget);

      await scrollToText(tester, 'Edit Request');

      expect(find.text('Edit Request'), findsOneWidget);

      await scrollToText(tester, 'Mark Completed');

      expect(find.text('Mark Completed'), findsOneWidget);

      await scrollToText(tester, 'Cancel Request');

      expect(find.text('Cancel Request'), findsOneWidget);
    });

    testWidgets('Nonowner cannot see management controls', (tester) async {
      final repository = FakeRequestRepository(makeRequest());

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: otherUserId,
      );

      expect(find.text('Need grocery assistance'), findsOneWidget);

      expect(find.text('Manage Your Request'), findsNothing);

      expect(find.text('Edit Request'), findsNothing);

      expect(find.text('Mark Completed'), findsNothing);

      expect(find.text('Cancel Request'), findsNothing);

      expect(repository.updateCalls, 0);
    });

    testWidgets('Completed requests cannot be managed', (tester) async {
      final repository = FakeRequestRepository(
        makeRequest(status: 'completed'),
      );

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      expect(find.text('Manage Your Request'), findsNothing);

      expect(find.text('Edit Request'), findsNothing);

      expect(find.text('Mark Completed'), findsNothing);

      expect(find.text('Cancel Request'), findsNothing);

      expect(repository.updateCalls, 0);
    });

    testWidgets('Canceled requests cannot be managed', (tester) async {
      final repository = FakeRequestRepository(makeRequest(status: 'canceled'));

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      expect(find.text('Manage Your Request'), findsNothing);

      expect(find.text('Edit Request'), findsNothing);

      expect(find.text('Mark Completed'), findsNothing);

      expect(find.text('Cancel Request'), findsNothing);

      expect(repository.updateCalls, 0);
    });
  });

  group('CCVO-66 Request Status Updates', () {
    testWidgets('Owner can mark a request completed', (tester) async {
      final repository = FakeRequestRepository(makeRequest());

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      // Open the confirmation dialog.
      await openCompleteDialog(tester);

      expect(find.text('Mark Request Completed?'), findsOneWidget);

      // Confirm completion using the dialog button.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Mark Completed'),
        ),
      );

      await tester.pumpAndSettle();

      // Verify PATCH behavior.
      expect(repository.updateCalls, 1);

      expect(repository.lastChanges, {'status': 'completed'});

      expect(repository.request.status, 'completed');

      // A completed request cannot be managed again.
      expect(find.text('Edit Request'), findsNothing);

      expect(find.text('Cancel Request'), findsNothing);
    });

    testWidgets('Owner can cancel a request', (tester) async {
      final repository = FakeRequestRepository(makeRequest());

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      // Open the confirmation dialog.
      await openCancelDialog(tester);

      expect(find.text('Cancel Request?'), findsOneWidget);

      // Confirm cancellation.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel Request'),
        ),
      );

      await tester.pumpAndSettle();

      // Verify PATCH behavior.
      expect(repository.updateCalls, 1);

      expect(repository.lastChanges, {'status': 'canceled'});

      expect(repository.request.status, 'canceled');

      // A canceled request cannot be managed again.
      expect(find.text('Edit Request'), findsNothing);

      expect(find.text('Mark Completed'), findsNothing);
    });

    testWidgets('Dismissing confirmation does not update request', (
      tester,
    ) async {
      final repository = FakeRequestRepository(makeRequest());

      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      // Open the completion confirmation.
      await openCompleteDialog(tester);

      expect(find.text('Mark Request Completed?'), findsOneWidget);

      // Dismiss instead of confirming.
      await tester.tap(find.text('Go Back'));

      await tester.pumpAndSettle();

      // No PATCH request should have occurred.
      expect(repository.updateCalls, 0);

      expect(repository.request.status, 'active');
    });
  });

  group('CCVO-61 Offer Navigation (Debug Demo)', () {
    testWidgets('Owner can open Review Offers demo', (tester) async {
      final repository = FakeRequestRepository(makeRequest());
      await openDetails(
        tester,
        repository: repository,
        applicationUserId: ownerId,
      );

      await scrollToText(tester, 'Review Offers (Demo)');
      expect(find.text('Review Offers (Demo)'), findsOneWidget);
      expect(find.text('Offer to Help (Demo)'), findsNothing);

      await tester.tap(find.text('Review Offers (Demo)'));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Offers'), findsWidgets);
      expect(find.text('Submit Offer'), findsNothing);
      expect(repository.updateCalls, 0);
    });

    testWidgets('Nonowner can open Offer to Help demo', (tester) async {
      final repository = FakeRequestRepository(makeRequest());
      await openDetails(
        tester,
        repository: repository,
        applicationUserId: otherUserId,
      );

      await scrollToText(tester, 'Offer to Help (Demo)');
      expect(find.text('Offer to Help (Demo)'), findsOneWidget);
      expect(find.text('Review Offers (Demo)'), findsNothing);

      await tester.tap(find.text('Offer to Help (Demo)'));
      await tester.pumpAndSettle();

      expect(find.text('Submit Offer'), findsOneWidget);
      expect(find.text('Accept Offer'), findsNothing);
      expect(repository.updateCalls, 0);
    });

    testWidgets('Closed requests hide offer navigation', (tester) async {
      for (final status in ['completed', 'canceled']) {
        final repository = FakeRequestRepository(makeRequest(status: status));
        await openDetails(
          tester,
          repository: repository,
          applicationUserId: ownerId,
        );

        expect(find.byKey(const Key('open-offers-demo')), findsNothing);
        expect(find.text('Review Offers (Demo)'), findsNothing);
        expect(find.text('Offer to Help (Demo)'), findsNothing);
        expect(repository.updateCalls, 0);
      }
    });
  });
}
