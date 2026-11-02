
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/home/home_screen.dart';
import 'package:village_outreach/features/requests/models/help_request.dart';
import 'package:village_outreach/features/requests/services/request_service.dart';

class FakeRequestRepository implements RequestRepository {
  @override
  Future<List<HelpRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
    int offset = 0,
  }) async {
    return [];
  }

  @override
  Future<HelpRequest> getRequestDetail(String requestId) async {
    throw UnimplementedError();
  }
}

void main() {
  Future<void> loadHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          requestRepository: FakeRequestRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Home screen displays Village Outreach branding', (
    tester,
  ) async {
    await loadHomeScreen(tester);

    expect(find.text('Village Outreach'), findsOneWidget);
    expect(find.text('Neighbors helping neighbors'), findsOneWidget);
    expect(find.text('Request Help'), findsOneWidget);
    expect(find.text('Offer Help'), findsOneWidget);
  });

  testWidgets('Home screen displays nearby requests section', (
    tester,
  ) async {
    await loadHomeScreen(tester);

    expect(find.text('Nearby Requests'), findsOneWidget);
    expect(
      find.text('Live requests from your community'),
      findsOneWidget,
    );
  });

  testWidgets('Home screen handles an empty request feed', (
    tester,
  ) async {
    await loadHomeScreen(tester);

    expect(
      find.textContaining('No active requests found nearby'),
      findsOneWidget,
    );
  });

  testWidgets('Home screen displays request filters', (
    tester,
  ) async {
    await loadHomeScreen(tester);

    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Within 10 km'), findsOneWidget);
  });

  testWidgets('Home screen displays bottom navigation', (
    tester,
  ) async {
    await loadHomeScreen(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Community'), findsWidgets);
    expect(find.text('Help'), findsWidgets);
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });
}
