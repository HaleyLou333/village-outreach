import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/requests/models/help_request.dart';
import 'package:village_outreach/features/requests/screens/request_form_screen.dart';

import 'request_detail_screen_test.dart'
    show FakeRequestRepository, ownerId, requestId;

void main() {
  testWidgets('Editing a nonpreset area preserves its location', (
    tester,
  ) async {
    final original = HelpRequest.fromJson({
      'id': requestId,
      'requester_id': ownerId,
      'title': 'Original title',
      'description': 'Need groceries.',
      'category': 'FOOD_ASSISTANCE',
      'urgency': 'standard',
      'latitude': 35.47,
      'longitude': -97.52,
      'area': 'Midtown Oklahoma City',
      'status': 'active',
      'created_at': '2026-11-01T12:00:00Z',
      'updated_at': '2026-11-01T12:00:00Z',
    });

    final repository = FakeRequestRepository(original);

    await tester.pumpWidget(
      MaterialApp(
        home: RequestFormScreen(
          existingRequest: original,
          requestRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Update the request title.
    final titleField = find.byType(TextFormField).first;

    await tester.enterText(titleField, 'Updated title');
    await tester.pumpAndSettle();

    // Locate the save button.
    final saveButton = find.text('Save Changes');

    // Scroll until the button is visible in the test viewport.
    await tester.scrollUntilVisible(
      saveButton,
      150,
      scrollable: find.byType(Scrollable).first,
    );

    // Ensure the button is fully visible before tapping.
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    // Save the updated request.
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify that the repository was updated exactly once.
    expect(repository.updateCalls, 1);

    // Verify that only the title was changed.
    expect(repository.lastChanges, {'title': 'Updated title'});

    // Verify that the original location was preserved.
    expect(repository.request.area, original.area);
    expect(repository.request.latitude, original.latitude);
    expect(repository.request.longitude, original.longitude);
  });
}
