import 'package:flutter/material.dart';

import '../models/private_message.dart';
import '../services/message_service.dart';

class PrivateConversationScreen extends StatefulWidget {
  const PrivateConversationScreen({
    super.key,
    required this.requestId,
    required this.currentUserId,
    required this.repository,
    required this.isClosed,
    this.pageSize = 20,
  });

  final String requestId;
  final String currentUserId;
  final MessageRepository repository;
  final bool isClosed;
  final int pageSize;

  @override
  State<PrivateConversationScreen> createState() =>
      _PrivateConversationScreenState();
}

class _PrivateConversationScreenState extends State<PrivateConversationScreen> {
  final _composer = TextEditingController();
  final List<PrivateMessage> _messages = [];
  bool _loading = true;
  bool _loadingOlder = false;
  String? _cursor;
  String? _error;
  bool _accessDenied = false;
  int _sequence = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final page = await widget.repository.getMessages(
        requestId: widget.requestId,
        currentUserId: widget.currentUserId,
        limit: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _cursor = page.nextCursor;
        _error = null;
        _loading = false;
      });
    } on MessageException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _accessDenied = error.message.contains('cannot access');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load messages. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _cursor == null) return;
    final cursor = _cursor;
    setState(() => _loadingOlder = true);
    try {
      final page = await widget.repository.getMessages(
        requestId: widget.requestId,
        currentUserId: widget.currentUserId,
        cursor: cursor,
        limit: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        final known = _messages.map((m) => m.clientMessageId).toSet();
        _messages.insertAll(
          0,
          page.messages.where((m) => !known.contains(m.clientMessageId)),
        );
        _cursor = page.nextCursor;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load older messages.');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    if (widget.isClosed || _accessDenied) return;
    final body = _composer.text.trim();
    if (body.isEmpty || body.length > 2000) return;
    final clientId = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final draft = PrivateMessage(
      id: 'local-$clientId',
      clientMessageId: clientId,
      requestId: widget.requestId,
      senderId: widget.currentUserId,
      body: body,
      createdAt: DateTime.now().toUtc(),
      deliveryStatus: MessageDeliveryStatus.sending,
    );
    setState(() {
      _messages.add(draft);
      _composer.clear();
      _error = null;
    });
    await _deliver(draft);
  }

  Future<void> _retry(PrivateMessage message) async {
    if (widget.isClosed ||
        message.deliveryStatus != MessageDeliveryStatus.failed) {
      return;
    }
    _replace(message.copyWith(deliveryStatus: MessageDeliveryStatus.sending));
    await _deliver(message);
  }

  Future<void> _deliver(PrivateMessage message) async {
    try {
      final saved = await widget.repository.sendMessage(
        requestId: widget.requestId,
        senderId: widget.currentUserId,
        clientMessageId: message.clientMessageId,
        body: message.body,
      );
      if (!mounted) return;
      _replace(saved);
    } catch (_) {
      if (!mounted) return;
      _replace(message.copyWith(deliveryStatus: MessageDeliveryStatus.failed));
    }
  }

  void _replace(PrivateMessage replacement) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere(
        (m) => m.clientMessageId == replacement.clientMessageId,
      );
      if (index >= 0) {
        _messages[index] = replacement;
      } else {
        _messages.add(replacement);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Private Conversation (Demo)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accessDenied
          ? Center(
              child: Text(
                _error ?? 'Access denied',
                key: const Key('access-denied'),
              ),
            )
          : Column(
              children: [
                if (widget.isClosed)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'This request is closed. Messages are read-only.',
                      key: Key('closed-banner'),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!, key: const Key('message-error')),
                  ),
                Expanded(
                  child: ListView(
                    key: const Key('message-list'),
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_cursor != null)
                        TextButton(
                          key: const Key('load-older'),
                          onPressed: _loadingOlder ? null : _loadOlder,
                          child: Text(
                            _loadingOlder
                                ? 'Loading...'
                                : 'Load older messages',
                          ),
                        ),
                      if (_messages.isEmpty)
                        const Center(child: Text('No messages yet.')),
                      for (final message in _messages) _messageBubble(message),
                    ],
                  ),
                ),
                if (!widget.isClosed)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('message-input'),
                              controller: _composer,
                              maxLength: 2000,
                              maxLines: 3,
                              minLines: 1,
                              decoration: const InputDecoration(
                                hintText: 'Write a message',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('send-message'),
                            tooltip: 'Send message',
                            onPressed: _send,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _messageBubble(PrivateMessage message) {
    final mine = message.senderId == widget.currentUserId;
    final status = message.deliveryStatus;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        key: Key('message-${message.clientMessageId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.body),
              const SizedBox(height: 4),
              Text(
                status == MessageDeliveryStatus.sending
                    ? 'Sending...'
                    : status == MessageDeliveryStatus.failed
                    ? 'Failed'
                    : 'Sent',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (mine &&
                  status == MessageDeliveryStatus.failed &&
                  !widget.isClosed)
                TextButton(
                  key: Key('retry-${message.clientMessageId}'),
                  onPressed: () => _retry(message),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
