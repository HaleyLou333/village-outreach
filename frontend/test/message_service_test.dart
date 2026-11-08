import 'package:flutter_test/flutter_test.dart';
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

  test('requester and accepted helper can read messages', () async {
    await repository.sendMessage(
      requestId: 'request-1',
      senderId: 'owner-1',
      clientMessageId: 'client-1',
      body: 'Hello',
    );
    for (final user in ['owner-1', 'helper-1']) {
      final page = await repository.getMessages(
        requestId: 'request-1',
        currentUserId: user,
      );
      expect(page.messages.single.body, 'Hello');
    }
  });

  test('another helper cannot read or send', () async {
    expect(
      () => repository.getMessages(
        requestId: 'request-1',
        currentUserId: 'helper-2',
      ),
      throwsA(isA<MessageException>()),
    );
    expect(
      () => repository.sendMessage(
        requestId: 'request-1',
        senderId: 'helper-2',
        clientMessageId: 'bad-1',
        body: 'No access',
      ),
      throwsA(isA<MessageException>()),
    );
  });

  test('same client message ID is idempotent', () async {
    final first = await repository.sendMessage(
      requestId: 'request-1',
      senderId: 'helper-1',
      clientMessageId: 'stable-id',
      body: 'Can help',
    );
    final retried = await repository.sendMessage(
      requestId: 'request-1',
      senderId: 'helper-1',
      clientMessageId: 'stable-id',
      body: 'Can help',
    );
    expect(retried.id, first.id);
    final page = await repository.getMessages(
      requestId: 'request-1',
      currentUserId: 'owner-1',
    );
    expect(page.messages, hasLength(1));
  });

  test('failed send can retry with the same ID', () async {
    repository.failNextSend('retry-id');
    await expectLater(
      repository.sendMessage(
        requestId: 'request-1',
        senderId: 'helper-1',
        clientMessageId: 'retry-id',
        body: 'Trying',
      ),
      throwsA(isA<MessageException>()),
    );
    final result = await repository.sendMessage(
      requestId: 'request-1',
      senderId: 'helper-1',
      clientMessageId: 'retry-id',
      body: 'Trying',
    );
    expect(result.body, 'Trying');
  });

  test('pagination loads older messages without overlap', () async {
    for (var i = 0; i < 5; i++) {
      await repository.sendMessage(
        requestId: 'request-1',
        senderId: 'owner-1',
        clientMessageId: 'id-$i',
        body: 'Message $i',
      );
    }
    final latest = await repository.getMessages(
      requestId: 'request-1',
      currentUserId: 'owner-1',
      limit: 2,
    );
    final older = await repository.getMessages(
      requestId: 'request-1',
      currentUserId: 'owner-1',
      cursor: latest.nextCursor,
      limit: 2,
    );
    expect(latest.messages.map((m) => m.body), ['Message 3', 'Message 4']);
    expect(older.messages.map((m) => m.body), ['Message 1', 'Message 2']);
  });

  test('closed requests retain history but reject new sends', () async {
    await repository.sendMessage(
      requestId: 'request-1',
      senderId: 'owner-1',
      clientMessageId: 'old-id',
      body: 'Existing history',
    );
    repository.setClosed('request-1', true);
    final page = await repository.getMessages(
      requestId: 'request-1',
      currentUserId: 'helper-1',
    );
    expect(page.messages.single.body, 'Existing history');
    await expectLater(
      repository.sendMessage(
        requestId: 'request-1',
        senderId: 'helper-1',
        clientMessageId: 'new-id',
        body: 'Not allowed',
      ),
      throwsA(isA<MessageException>()),
    );
  });
}
