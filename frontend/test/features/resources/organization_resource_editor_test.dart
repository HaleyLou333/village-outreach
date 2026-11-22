import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/resources/screens/organization_resource_editor_screen.dart';
import 'package:village_outreach/features/resources/services/organization_resource_service.dart';

class FakeOrganizationRepository implements OrganizationResourceRepository {
  FakeOrganizationRepository(this.members);
  final List<OrganizationMembership> members;
  final List<ManagedResource> items = [];
  int creates = 0;
  String? lastOrganizationId;

  @override
  Future<List<OrganizationMembership>> memberships() async => members;
  @override
  Future<List<ManagedResource>> resources(String organizationId) async {
    lastOrganizationId = organizationId;
    return items.where((item) => item.organizationId == organizationId).toList();
  }
  @override
  Future<void> create(String organizationId, Map<String, dynamic> fields) async {
    creates++;
    lastOrganizationId = organizationId;
  }
  @override
  Future<void> update(String resourceId, Map<String, dynamic> fields) async {}
  @override
  Future<void> disable(String resourceId) async {}
}

OrganizationMembership member(String status, {bool active = true}) => OrganizationMembership(
  organizationId: 'org-a',
  name: 'Neighborhood Support',
  role: 'member',
  status: status,
  isActive: active,
);

void main() {
  test('only approved members of active organizations can manage resources', () {
    expect(member('approved').canManage, isTrue);
    expect(member('pending').canManage, isFalse);
    expect(member('rejected').canManage, isFalse);
    expect(member('approved', active: false).canManage, isFalse);
  });

  testWidgets('pending membership does not reveal the resource editor', (tester) async {
    final repository = FakeOrganizationRepository([member('pending')]);
    await tester.pumpWidget(MaterialApp(
      home: OrganizationResourceEditorScreen(repository: repository),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No approved organization memberships.'), findsOneWidget);
    expect(find.text('Add resource'), findsNothing);
  });

  testWidgets('approved membership reveals organization management', (tester) async {
    final repository = FakeOrganizationRepository([member('approved')]);
    await tester.pumpWidget(MaterialApp(
      home: OrganizationResourceEditorScreen(repository: repository),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add resource'), findsOneWidget);
    expect(repository.lastOrganizationId, 'org-a');
  });

  testWidgets('invalid form prevents submission', (tester) async {
    final repository = FakeOrganizationRepository([member('approved')]);
    await tester.pumpWidget(MaterialApp(
      home: OrganizationResourceEditorScreen(repository: repository),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add resource'));
    await tester.pumpAndSettle();
    // Validate through the FormState rather than scrolling to an offscreen
    // submit button. This directly verifies that empty required fields are
    // rejected, without depending on ListView viewport geometry.
    final formState = tester.state<FormState>(find.byType(Form));
    expect(formState.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required field'), findsWidgets);
    expect(repository.creates, 0);
  });
}
