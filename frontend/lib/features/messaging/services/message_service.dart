import '../../requests/services/request_service.dart';
import '../models/private_message.dart';

class MessageException implements Exception {
  const MessageException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class MessagePage {
  const MessagePage({
    required this.messages,
    required this.nextCursor,
    this.refreshCursor,
  });
  final List<PrivateMessage> messages;
  final String? nextCursor;
  // Ascending history can resume here even after reaching the end.
  final String? refreshCursor;
}

abstract class MessageRepository {
  Future<MessagePage> getMessages({
    required String requestId,
    required String currentUserId,
    String? cursor,
    int limit = 20,
  });

  Future<PrivateMessage> sendMessage({
    required String requestId,
    required String senderId,
    required String clientMessageId,
    required String body,
  });
}

class ApiMessageRepository implements MessageRepository {
  ApiMessageRepository(this._api, {required this.receiverId});

  final RequestService _api;
  final String receiverId;

  @override
  Future<MessagePage> getMessages({
    required String requestId,
    required String currentUserId,
    String? cursor,
    int limit = 20,
  }) async {
    final offset = cursor == null ? 0 : int.parse(cursor);
    try {
      final data = await _api.requestJson(
        'GET',
        '/requests/$requestId/messages',
        operation: 'load messages',
        query: {'limit': '$limit', 'offset': '$offset'},
      ) as List<dynamic>;
      final nextOffset = offset + data.length;
      return MessagePage(
        messages: data
            .map(
              (item) => PrivateMessage.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: data.length == limit && nextOffset <= 10000
            ? '$nextOffset'
            : null,
        refreshCursor: '${nextOffset.clamp(0, 10000)}',
      );
    } on RequestApiException catch (error) {
      throw MessageException(error.message, statusCode: error.statusCode);
    }
  }

  @override
  Future<PrivateMessage> sendMessage({
    required String requestId,
    required String senderId,
    required String clientMessageId,
    required String body,
  }) async {
    try {
      final data = await _api.requestJson(
        'POST',
        '/messages',
        operation: 'send your message',
        body: {
          'request_id': requestId,
          'receiver_id': receiverId,
          'body': body,
        },
        idempotencyKey: clientMessageId,
      ) as Map<String, dynamic>;
      return PrivateMessage.fromJson(data, clientMessageId: clientMessageId);
    } on RequestApiException catch (error) {
      throw MessageException(error.message, statusCode: error.statusCode);
    }
  }
}

class MockMessageRepository implements MessageRepository {
  final Map<String, _MockConversation> _conversations = {};
  final Map<String, List<PrivateMessage>> _messages = {};
  final Set<String> _failNextClientIds = {};
  int _nextMessageId = 1;

  /// Demo-only configuration. Production participants and closure must be
  /// determined and enforced by the backend, not caller-supplied IDs.
  void configureConversation({
    required String requestId,
    required String requesterId,
    required String acceptedHelperId,
    bool isClosed = false,
  }) {
    if (requesterId == acceptedHelperId) {
      throw const MessageException(
        'Conversation participants must be different.',
      );
    }
    _conversations[requestId] = _MockConversation(
      requesterId: requesterId,
      acceptedHelperId: acceptedHelperId,
      isClosed: isClosed,
    );
  }

  void setClosed(String requestId, bool isClosed) {
    final existing = _conversations[requestId];
    if (existing == null) {
      throw const MessageException('Conversation unavailable.');
    }
    _conversations[requestId] = _MockConversation(
      requesterId: existing.requesterId,
      acceptedHelperId: existing.acceptedHelperId,
      isClosed: isClosed,
    );
  }

  /// Simulates a network failure before the mock server accepts the message.
  void failNextSend(String clientMessageId) =>
      _failNextClientIds.add(clientMessageId);

  _MockConversation _authorize(String requestId, String userId) {
    final conversation = _conversations[requestId];
    if (conversation == null ||
        (userId != conversation.requesterId &&
            userId != conversation.acceptedHelperId)) {
      throw const MessageException(
        'You cannot access this private conversation.',
      );
    }
    return conversation;
  }

  @override
  Future<MessagePage> getMessages({
    required String requestId,
    required String currentUserId,
    String? cursor,
    int limit = 20,
  }) async {
    _authorize(requestId, currentUserId);
    if (limit < 1 || limit > 100) {
      throw const MessageException('Invalid page size.');
    }
    final all = _messages[requestId] ?? const <PrivateMessage>[];
    // Cursor represents the exclusive end index in chronological storage.
    final end = cursor == null ? all.length : int.tryParse(cursor);
    if (end == null || end < 0 || end > all.length) {
      throw const MessageException('Invalid message cursor.');
    }
    final start = end - limit < 0 ? 0 : end - limit;
    return MessagePage(
      messages: List.unmodifiable(all.sublist(start, end)),
      nextCursor: start == 0 ? null : '$start',
    );
  }

  @override
  Future<PrivateMessage> sendMessage({
    required String requestId,
    required String senderId,
    required String clientMessageId,
    required String body,
  }) async {
    final conversation = _authorize(requestId, senderId);
    if (clientMessageId.trim().isEmpty) {
      throw const MessageException('Message ID is required.');
    }
    final messages = _messages.putIfAbsent(requestId, () => []);
    for (final existing in messages) {
      if (existing.senderId == senderId &&
          existing.clientMessageId == clientMessageId) {
        if (existing.body != body.trim()) {
          throw const MessageException(
            'Message ID was reused with different content.',
          );
        }
        return existing;
      }
    }
    if (conversation.isClosed) {
      throw const MessageException(
        'This request is closed. Messaging is read-only.',
      );
    }
    if (body.trim().isEmpty) {
      throw const MessageException('Please enter a message.');
    }
    if (body.trim().length > 2000) {
      throw const MessageException('Message must be 2000 characters or fewer.');
    }
    if (_failNextClientIds.remove(clientMessageId)) {
      throw const MessageException('Unable to send message. Please retry.');
    }
    final message = PrivateMessage(
      id: 'mock-message-${_nextMessageId++}',
      clientMessageId: clientMessageId,
      requestId: requestId,
      senderId: senderId,
      body: body.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    messages.add(message);
    return message;
  }
}

class _MockConversation {
  const _MockConversation({
    required this.requesterId,
    required this.acceptedHelperId,
    required this.isClosed,
  });
  final String requesterId;
  final String acceptedHelperId;
  final bool isClosed;
}
