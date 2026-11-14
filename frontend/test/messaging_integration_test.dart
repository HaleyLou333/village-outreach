import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/messaging/screens/private_conversation_screen.dart';
import 'package:village_outreach/features/messaging/services/message_service.dart';

void main() {
  const requestId = 'request-integration-1';
  const ownerId = 'application-owner-1';
  const helperId = 'application-helper-1';
  const outsiderId = 'application-outsider-1';

  late MockMessageRepository repository;

  setUp(() {
    repository = MockMessageRepository()
      ..configureConversation(
        requestId: requestId,
        requesterId: ownerId,
        acceptedHelperId: helperId,
      );
  });

  Future<void> openConversation(
    WidgetTester tester, {
    required String userId,
    bool isClosed = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivateConversationScreen(
          requestId: requestId,
          currentUserId: userId,
          repository: repository,
          isClosed: isClosed,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CCVO-68 private messaging integration', () {
    testWidgets('requester sends and accepted helper sees the message', (
      tester,
    ) async {
      await openConversation(tester, userId: ownerId);
      await tester.enterText(
        find.byKey(const Key('message-input')),
        'I can meet tomorrow afternoon.',
      );
      await tester.tap(find.byKey(const Key('send-message')));
      await tester.pumpAndSettle();
      expect(find.text('I can meet tomorrow afternoon.'), findsOneWidget);

      await openConversation(tester, userId: helperId);
      expect(find.text('I can meet tomorrow afternoon.'), findsOneWidget);
      expect(find.byKey(const Key('message-input')), findsOneWidget);
    });

    testWidgets('accepted helper replies and requester sees the reply', (
      tester,
    ) async {
      await openConversation(tester, userId: helperId);
      await tester.enterText(
        find.byKey(const Key('message-input')),
        'That works for me.',
      );
      await tester.tap(find.byKey(const Key('send-message')));
      await tester.pumpAndSettle();

      await openConversation(tester, userId: ownerId);
      expect(find.text('That works for me.'), findsOneWidget);
    });

    testWidgets('unaccepted helper cannot read the conversation', (
      tester,
    ) async {
      await repository.sendMessage(
        requestId: requestId,
        senderId: ownerId,
        clientMessageId: 'private-message-1',
        body: 'Confidential conversation text',
      );

      await openConversation(tester, userId: outsiderId);
      expect(find.byKey(const Key('access-denied')), findsOneWidget);
      expect(find.text('Confidential conversation text'), findsNothing);
      expect(find.byKey(const Key('message-input')), findsNothing);
    });

    testWidgets('closed request retains history but hides composer', (
      tester,
    ) async {
      await repository.sendMessage(
        requestId: requestId,
        senderId: ownerId,
        clientMessageId: 'before-close-1',
        body: 'Saved before the request closed',
      );
      repository.setClosed(requestId, true);

      await openConversation(tester, userId: helperId, isClosed: true);
      expect(find.text('Saved before the request closed'), findsOneWidget);
      expect(find.byKey(const Key('closed-banner')), findsOneWidget);
      expect(find.byKey(const Key('message-input')), findsNothing);
      expect(find.byKey(const Key('send-message')), findsNothing);
    });

    test('repository rejects new messages after closure', () async {
      repository.setClosed(requestId, true);

      await expectLater(
        repository.sendMessage(
          requestId: requestId,
          senderId: helperId,
          clientMessageId: 'after-close-1',
          body: 'This should not be sent',
        ),
        throwsA(isA<MessageException>()),
      );
      final history = await repository.getMessages(
        requestId: requestId,
        currentUserId: ownerId,
      );
      expect(history.messages, isEmpty);
    });

    test('reopening the same mock conversation preserves history', () async {
      await repository.sendMessage(
        requestId: requestId,
        senderId: helperId,
        clientMessageId: 'persistent-within-session-1',
        body: 'Still here after reopening',
      );

      repository.configureConversation(
        requestId: requestId,
        requesterId: ownerId,
        acceptedHelperId: helperId,
      );

      final history = await repository.getMessages(
        requestId: requestId,
        currentUserId: ownerId,
      );
      expect(history.messages, hasLength(1));
      expect(history.messages.single.body, 'Still here after reopening');
    });

    test('idempotent resend does not duplicate a message', () async {
      for (var attempt = 0; attempt < 2; attempt++) {
        await repository.sendMessage(
          requestId: requestId,
          senderId: ownerId,
          clientMessageId: 'same-client-id',
          body: 'Only one copy',
        );
      }
      final history = await repository.getMessages(
        requestId: requestId,
        currentUserId: helperId,
      );
      expect(history.messages, hasLength(1));
    });
  });
}
