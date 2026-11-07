import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_outreach/features/messaging/screens/private_conversation_screen.dart';
import 'package:village_outreach/features/messaging/services/message_service.dart';

void main() {
  late MockMessageRepository repository;

  setUp(() {
    repository = MockMessageRepository()
      ..configureConversation(
        requestId: 'request-1',
        requesterId: 'owner-1',
        acceptedHelperId: 'helper-1',
      );
  });

  Widget screen({
    String userId = 'owner-1',
    bool isClosed = false,
    int pageSize = 20,
  }) {
    return MaterialApp(
      home: PrivateConversationScreen(
        requestId: 'request-1',
        currentUserId: userId,
        repository: repository,
        isClosed: isClosed,
        pageSize: pageSize,
      ),
    );
  }

  testWidgets('owner can send a message', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('message-input')),
      'Hello helper',
    );
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pumpAndSettle();
    expect(find.text('Hello helper'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    final page = await repository.getMessages(
      requestId: 'request-1',
      currentUserId: 'owner-1',
    );
    expect(page.messages.length, 1);
  });

  testWidgets('unauthorized helper cannot read or send', (tester) async {
    await tester.pumpWidget(screen(userId: 'stranger-1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-denied')), findsOneWidget);
    expect(find.byKey(const Key('message-input')), findsNothing);
  });

  testWidgets('closed conversation displays history without composer', (
    tester,
  ) async {
    await repository.sendMessage(
      requestId: 'request-1',
      senderId: 'owner-1',
      clientMessageId: 'c1',
      body: 'Previous message',
    );
    repository.setClosed('request-1', true);
    await tester.pumpWidget(screen(isClosed: true));
    await tester.pumpAndSettle();
    expect(find.text('Previous message'), findsOneWidget);
    expect(find.byKey(const Key('closed-banner')), findsOneWidget);
    expect(find.byKey(const Key('message-input')), findsNothing);
  });

  testWidgets('older messages load with pagination', (tester) async {
    for (var i = 0; i < 3; i++) {
      await repository.sendMessage(
        requestId: 'request-1',
        senderId: 'owner-1',
        clientMessageId: 'c$i',
        body: 'Message $i',
      );
    }
    await tester.pumpWidget(screen(pageSize: 2));
    await tester.pumpAndSettle();
    expect(find.text('Message 0'), findsNothing);
    await tester.tap(find.byKey(const Key('load-older')));
    await tester.pumpAndSettle();
    expect(find.text('Message 0'), findsOneWidget);
    expect(find.byKey(const Key('load-older')), findsNothing);
  });
}
