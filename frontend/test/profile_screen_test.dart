import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:village_outreach/features/profile/profile_screen.dart';
import 'package:village_outreach/features/profile/profile_service.dart';
import 'package:village_outreach/features/profile/user_profile.dart';

// ============================================================
// CCVO-70: Account Settings Widget Tests
//
// Tests:
// 1. Loads authenticated profile
// 2. Updates display name
// 3. Failed save retains entered display name
// 4. Refresh is disabled while editing
// 5. Cancel restores original display name
// 6. Sign-out requires confirmation
// 7. Canceling sign-out retains session
// 8. Failed sign-out displays inline error
//
// No real API requests are made.
// ============================================================

// ============================================================
// Fake Profile Service
// ============================================================

class FakeAccountProfileService extends ProfileService {
  String displayName = 'Test User';

  bool failSave = false;
  bool failLoad = false;

  int loadCalls = 0;
  int saveCalls = 0;

  FakeAccountProfileService()
    : super(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        ),
        httpClient: http.Client(),
      );

  UserProfile makeProfile() {
    return UserProfile.fromJson({
      'id': '95972aa0-2d05-4590-badf-7833215973ba',
      'email': 'test@example.com',
      'display_name': displayName,
      'role': 'user',
      'status': 'active',
      'created_at': '2026-11-01T12:00:00Z',
      'updated_at': '2026-11-01T12:00:00Z',
    });
  }

  @override
  Future<UserProfile> getProfile() async {
    loadCalls++;

    if (failLoad) {
      throw const ProfileException('Unable to load your profile.', 503);
    }

    return makeProfile();
  }

  @override
  Future<UserProfile> updateDisplayName(String name) async {
    saveCalls++;

    if (failSave) {
      throw const ProfileException(
        'The profile service is temporarily unavailable.',
        503,
      );
    }

    displayName = name;

    return makeProfile();
  }
}

// ============================================================
// Widget Test Helpers
// ============================================================

/// Opens the account settings screen using a fake profile service.
Future<void> openProfile(
  WidgetTester tester,
  FakeAccountProfileService service, {
  Future<void> Function()? signOutAction,
}) async {
  // Use a larger viewport to prevent lazy ListView children
  // from being disposed while interacting with the form.
  await tester.binding.setSurfaceSize(const Size(800, 1400));

  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      home: ProfileScreen(
        profileService: service,
        signOutAction: signOutAction ?? () async {},
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Scrolls to a control and verifies that it can be tapped.
Future<void> tapControl(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));

  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();

  expect(finder.hitTestable(), findsOneWidget);

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Enables profile editing and enters a new display name.
Future<void> editName(WidgetTester tester, String name) async {
  await tapControl(tester, 'edit-profile');

  final field = find.byKey(const Key('profile-display-name'));

  // Scroll back toward the top if the display name field
  // is no longer built after tapping Edit Profile.
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      -150,
      scrollable: find.byType(Scrollable).first,
    );
  }

  await tester.ensureVisible(field);
  await tester.pumpAndSettle();

  expect(field, findsOneWidget);

  expect(tester.widget<TextField>(field).enabled, isTrue);

  await tester.enterText(field, name);

  FocusManager.instance.primaryFocus?.unfocus();

  await tester.pumpAndSettle();
}

// ============================================================
// Tests
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CCVO-70 Account Settings', () {
    // ========================================================
    // Test 1: Load authenticated profile
    // ========================================================

    testWidgets('Loads the authenticated profile', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      await openProfile(tester, service);

      expect(find.text('Account Settings'), findsOneWidget);

      expect(find.text('Test User'), findsOneWidget);

      expect(service.loadCalls, 1);
    });

    // ========================================================
    // Test 2: Update display name
    // ========================================================

    testWidgets('Updates the display name', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      await openProfile(tester, service);

      await editName(tester, 'Updated User');

      await tapControl(tester, 'save-profile');

      expect(service.saveCalls, 1);

      expect(service.displayName, 'Updated User');

      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    // ========================================================
    // Test 3: Failed save retains entered display name
    // ========================================================

    testWidgets('Failed save retains entered display name', (tester) async {
      final service = FakeAccountProfileService()..failSave = true;

      addTearDown(service.dispose);

      await openProfile(tester, service);

      await editName(tester, 'Unsaved Name');

      await tapControl(tester, 'save-profile');

      final field = tester.widget<TextField>(
        find.byKey(const Key('profile-display-name')),
      );

      // The entered name should remain in the form.
      expect(field.controller!.text, 'Unsaved Name');

      // The persisted profile should remain unchanged.
      expect(service.displayName, 'Test User');

      expect(service.saveCalls, 1);

      final errorFinder = find.text(
        'The profile service is temporarily unavailable.',
      );

      await tester.ensureVisible(errorFinder);
      await tester.pumpAndSettle();

      expect(errorFinder, findsOneWidget);
    });

    // ========================================================
    // Test 4: Refresh disabled while editing
    // ========================================================

    testWidgets('Refresh is disabled while editing', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      await openProfile(tester, service);

      await editName(tester, 'Unsaved Name');

      // Locate the IconButton directly.
      //
      // find.byTooltip() can return a RawTooltip widget,
      // which cannot be cast to IconButton.
      final refreshFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Refresh profile',
      );

      expect(refreshFinder, findsOneWidget);

      final refresh = tester.widget<IconButton>(refreshFinder);

      // Refresh must be disabled to prevent overwriting
      // unsaved profile changes.
      expect(refresh.onPressed, isNull);

      // Only the initial profile request should occur.
      expect(service.loadCalls, 1);
    });

    // ========================================================
    // Test 5: Cancel restores original display name
    // ========================================================

    testWidgets('Cancel restores the original display name', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      await openProfile(tester, service);

      await editName(tester, 'Unsaved Name');

      await tapControl(tester, 'cancel-profile-edit');

      final field = tester.widget<TextField>(
        find.byKey(const Key('profile-display-name')),
      );

      expect(field.controller!.text, 'Test User');

      expect(service.saveCalls, 0);

      expect(service.displayName, 'Test User');
    });

    // ========================================================
    // Test 6: Sign-out requires confirmation
    // ========================================================

    testWidgets('Sign-out requires confirmation', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      int signOutCalls = 0;

      await openProfile(
        tester,
        service,
        signOutAction: () async {
          signOutCalls++;
        },
      );

      await tapControl(tester, 'account-sign-out');

      expect(find.text('Sign Out?'), findsOneWidget);

      // Sign-out should not occur until confirmed.
      expect(signOutCalls, 0);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign Out'),
        ),
      );

      await tester.pumpAndSettle();

      expect(signOutCalls, 1);
    });

    // ========================================================
    // Test 7: Canceling sign-out retains session
    // ========================================================

    testWidgets('Canceling sign-out retains the session', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      int signOutCalls = 0;

      await openProfile(
        tester,
        service,
        signOutAction: () async {
          signOutCalls++;
        },
      );

      await tapControl(tester, 'account-sign-out');

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );

      await tester.pumpAndSettle();

      // Canceling must not invoke the sign-out action.
      expect(signOutCalls, 0);

      expect(find.text('Account Settings'), findsOneWidget);

      expect(find.byType(AlertDialog), findsNothing);
    });

    // ========================================================
    // Test 8: Failed sign-out displays inline error
    // ========================================================

    testWidgets('Failed sign-out displays an inline error', (tester) async {
      final service = FakeAccountProfileService();

      addTearDown(service.dispose);

      await openProfile(
        tester,
        service,
        signOutAction: () async {
          throw Exception('Sign-out failed');
        },
      );

      await tapControl(tester, 'account-sign-out');

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign Out'),
        ),
      );

      await tester.pumpAndSettle();

      final errorFinder = find.text('Unable to sign out. Please try again.');

      await tester.ensureVisible(errorFinder);
      await tester.pumpAndSettle();

      expect(errorFinder, findsOneWidget);

      // The user should remain on Account Settings.
      expect(find.text('Account Settings'), findsOneWidget);
    });
  });
}
