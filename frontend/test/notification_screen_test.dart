import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_outreach/features/notifications/models/app_notification.dart';
import 'package:village_outreach/features/notifications/screens/notification_screen.dart';
import 'package:village_outreach/features/notifications/services/notification_service.dart';
import 'package:village_outreach/features/requests/services/request_service.dart';

const notificationId = '11111111-1111-4111-8111-111111111111';
const requestId = '22222222-2222-4222-8222-222222222222';

const userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

AppNotification makeNotification({
  String id = notificationId,
  AppNotificationType type = AppNotificationType.offerReceived,
  bool isRead = false,
}) {
  return AppNotification(
    id: id,
    requestId: requestId,
    type: type,
    createdAt: DateTime.utc(2026, 11, 22, 12),
    readAt: isRead ? DateTime.utc(2026, 11, 22, 13) : null,
  );
}

class FakeNotificationRepository implements NotificationRepository {
  List<AppNotification> notifications = [];

  bool failLoad = false;
  bool failMarkRead = false;

  int loadCalls = 0;
  int readCalls = 0;

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    loadCalls++;

    if (failLoad) {
      throw Exception('Notifications unavailable');
    }

    if (offset >= notifications.length) {
      return [];
    }

    final end = (offset + limit < notifications.length)
        ? offset + limit
        : notifications.length;

    return notifications.sublist(offset, end);
  }

  @override
  Future<AppNotification> markAsRead(String id) async {
    readCalls++;

    if (failMarkRead) {
      throw Exception('Unable to mark notification read');
    }

    final index = notifications.indexWhere(
      (notification) => notification.id == id,
    );

    if (index == -1) {
      throw Exception('Notification not found');
    }

    final current = notifications[index];

    final updated = AppNotification(
      id: current.id,
      requestId: current.requestId,
      type: current.type,
      createdAt: current.createdAt,
      readAt: current.readAt ?? DateTime.utc(2026, 11, 22, 14),
    );

    notifications[index] = updated;

    return updated;
  }
}

/// Allows tests to control when individual notification
/// API responses complete.
class DeferredNotificationRepository implements NotificationRepository {
  final List<Completer<List<AppNotification>>> pendingLoads = [];

  int loadCalls = 0;

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) {
    loadCalls++;

    final completer = Completer<List<AppNotification>>();
    pendingLoads.add(completer);

    return completer.future;
  }

  @override
  Future<AppNotification> markAsRead(String id) {
    throw UnimplementedError('Mark-as-read is not used by this test.');
  }
}

Future<void> pumpNotificationScreen(
  WidgetTester tester,
  FakeNotificationRepository repository, {
  Future<void> Function(BuildContext, String)? onOpenRequest,
  Future<void> Function(String)? checkRequestAccess,
  String? initialUserId,
  Stream<String?>? authUserChanges,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationScreen(
        repository: repository,
        onOpenRequest: onOpenRequest,
        checkRequestAccess: checkRequestAccess,
        initialUserId: initialUserId,
        authUserChanges: authUserChanges,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('CCVO-74 Notification Inbox', () {
    testWidgets('displays an empty state', (tester) async {
      final repository = FakeNotificationRepository();

      await pumpNotificationScreen(tester, repository);

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(repository.loadCalls, 1);
    });

    testWidgets('loads additional notifications without duplicates', (
      tester,
    ) async {
      final repository = FakeNotificationRepository()
        ..notifications = List.generate(
          25,
          (index) => AppNotification(
            id: '11111111-1111-4111-8111-${(index + 1).toString().padLeft(12, '0')}',
            requestId: requestId,
            type: AppNotificationType.offerReceived,
            createdAt: DateTime.utc(2026, 11, 22, 12),
          ),
        );

      await pumpNotificationScreen(tester, repository);

      expect(repository.loadCalls, 1);

      const firstId = '11111111-1111-4111-8111-000000000001';
      const lastId = '11111111-1111-4111-8111-000000000025';

      expect(find.byKey(const Key('notification-$firstId')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Load More'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();

      expect(repository.loadCalls, 2);

      await tester.scrollUntilVisible(
        find.byKey(const Key('notification-$lastId')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('notification-$lastId')), findsOneWidget);

      expect(find.text('Load More'), findsNothing);
    });

    testWidgets('displays unread notifications', (tester) async {
      final repository = FakeNotificationRepository()
        ..notifications = [makeNotification()];

      await pumpNotificationScreen(tester, repository);

      expect(find.text('New Offer Received'), findsOneWidget);

      expect(
        find.text('Someone has offered to help with your request.'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('unread-$notificationId')), findsOneWidget);
    });

    testWidgets('displays different notification types', (tester) async {
      final repository = FakeNotificationRepository()
        ..notifications = [
          makeNotification(
            id: '33333333-3333-4333-8333-333333333333',
            type: AppNotificationType.offerAccepted,
          ),
          makeNotification(
            id: '44444444-4444-4444-8444-444444444444',
            type: AppNotificationType.messageReceived,
          ),
        ];

      await pumpNotificationScreen(tester, repository);

      expect(find.text('Your Offer Was Accepted'), findsOneWidget);

      expect(find.text('New Message'), findsOneWidget);
    });

    testWidgets('retries after a loading failure', (tester) async {
      final repository = FakeNotificationRepository()..failLoad = true;

      await pumpNotificationScreen(tester, repository);

      expect(
        find.text('Unable to load notifications. Please try again.'),
        findsOneWidget,
      );

      repository.failLoad = false;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);

      expect(repository.loadCalls, 2);
    });

    testWidgets('marks unread notification read and opens request', (
      tester,
    ) async {
      final repository = FakeNotificationRepository()
        ..notifications = [makeNotification()];

      String? openedRequestId;

      await pumpNotificationScreen(
        tester,
        repository,
        onOpenRequest: (_, id) async {
          openedRequestId = id;
        },
      );

      await tester.tap(find.text('New Offer Received'));
      await tester.pumpAndSettle();

      expect(repository.readCalls, 1);
      expect(openedRequestId, requestId);

      expect(find.byKey(const Key('unread-$notificationId')), findsNothing);
    });

    testWidgets('does not navigate when marking read fails', (tester) async {
      final repository = FakeNotificationRepository()
        ..notifications = [makeNotification()]
        ..failMarkRead = true;

      String? openedRequestId;

      await pumpNotificationScreen(
        tester,
        repository,
        onOpenRequest: (_, id) async {
          openedRequestId = id;
        },
      );

      await tester.tap(find.text('New Offer Received'));
      await tester.pumpAndSettle();

      expect(repository.readCalls, 1);
      expect(openedRequestId, isNull);

      expect(
        find.textContaining('Unable to open this notification'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('unread-$notificationId')), findsOneWidget);
    });

    testWidgets('unavailable request stays unread and does not navigate', (
      tester,
    ) async {
      final repository = FakeNotificationRepository()
        ..notifications = [makeNotification()];

      String? openedRequestId;
      String? checkedRequestId;

      await pumpNotificationScreen(
        tester,
        repository,
        checkRequestAccess: (id) async {
          checkedRequestId = id;

          throw const RequestApiException(
            'Request not found.',
            statusCode: 404,
          );
        },
        onOpenRequest: (_, id) async {
          openedRequestId = id;
        },
      );

      expect(find.byKey(const Key('unread-$notificationId')), findsOneWidget);

      await tester.tap(find.text('New Offer Received'));
      await tester.pumpAndSettle();

      expect(checkedRequestId, requestId);
      expect(openedRequestId, isNull);
      expect(repository.readCalls, 0);

      expect(find.byKey(const Key('unread-$notificationId')), findsOneWidget);

      expect(
        find.textContaining('This request is no longer available'),
        findsOneWidget,
      );
    });

    testWidgets('sign-out immediately clears loaded notifications', (
      tester,
    ) async {
      final authController = StreamController<String?>.broadcast();

      addTearDown(authController.close);

      final repository = FakeNotificationRepository()
        ..notifications = [makeNotification()];

      await pumpNotificationScreen(
        tester,
        repository,
        initialUserId: userA,
        authUserChanges: authController.stream,
      );

      expect(
        find.byKey(const Key('notification-$notificationId')),
        findsOneWidget,
      );

      // Simulate Supabase sign-out.
      authController.add(null);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification-$notificationId')),
        findsNothing,
      );

      expect(find.text('Sign in to view your notifications.'), findsOneWidget);

      // Signing out must not trigger another API request.
      expect(repository.loadCalls, 1);
    });

    testWidgets('account switch discards previous user API response', (
      tester,
    ) async {
      final authController = StreamController<String?>.broadcast();

      addTearDown(authController.close);

      final repository = DeferredNotificationRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationScreen(
            repository: repository,
            initialUserId: userA,
            authUserChanges: authController.stream,
          ),
        ),
      );

      await tester.pump();

      // User A has an unfinished notification request.
      expect(repository.loadCalls, 1);
      expect(repository.pendingLoads.length, 1);

      // Switch accounts before User A's response completes.
      authController.add(userB);
      await tester.pump();

      // User B starts a separate request.
      expect(repository.loadCalls, 2);
      expect(repository.pendingLoads.length, 2);

      const userANotificationId = 'aaaaaaaa-1111-4111-8111-111111111111';

      const userBNotificationId = 'bbbbbbbb-2222-4222-8222-222222222222';

      final userANotification = makeNotification(id: userANotificationId);

      final userBNotification = makeNotification(id: userBNotificationId);

      // Complete User B's request first.
      repository.pendingLoads[1].complete([userBNotification]);

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification-$userBNotificationId')),
        findsOneWidget,
      );

      // User A's outdated request finishes afterward.
      repository.pendingLoads[0].complete([userANotification]);

      await tester.pumpAndSettle();

      // User A's notification must never appear.
      expect(
        find.byKey(const Key('notification-$userANotificationId')),
        findsNothing,
      );

      // User B's notification remains visible.
      expect(
        find.byKey(const Key('notification-$userBNotificationId')),
        findsOneWidget,
      );

      expect(repository.loadCalls, 2);
    });
  });
}
