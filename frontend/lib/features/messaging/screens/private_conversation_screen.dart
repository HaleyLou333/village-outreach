import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
  String? _refreshCursor;
  String? _error;
  bool _accessDenied = false;
  bool _closedByServer = false;

  bool get _isClosed => widget.isClosed || _closedByServer;
  bool get _sending => _messages.any(
    (message) => message.deliveryStatus == MessageDeliveryStatus.sending,
  );

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
        cursor: _refreshCursor,
        limit: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _mergePage(page);
        _error = null;
        _accessDenied = false;
        _loading = false;
      });
    } on MessageException catch (error) {
      if (!mounted) return;
      setState(() {
        _showLoadError(error);
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
        _mergePage(page);
        _error = null;
      });
    } on MessageException catch (error) {
      if (!mounted) return;
      setState(() => _showLoadError(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load more messages.');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    if (_isClosed || _accessDenied || _loading) return;
    final body = _composer.text.trim();
    if (body.isEmpty || body.length > 2000) return;
    final clientId = const Uuid().v4();
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
    if (_isClosed ||
        _loading ||
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
    } on MessageException catch (error) {
      if (!mounted) return;
      _replace(message.copyWith(deliveryStatus: MessageDeliveryStatus.failed));
      setState(() {
        if (error.statusCode == 409 &&
            error.message.contains('closed requests')) {
          _closedByServer = true;
        }
        if (error.statusCode == 403) {
          _accessDenied = true;
          _messages.clear();
        }
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      _replace(message.copyWith(deliveryStatus: MessageDeliveryStatus.failed));
    }
  }

  void _replace(PrivateMessage replacement) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere(
        (m) =>
            m.clientMessageId == replacement.clientMessageId ||
            m.id == replacement.id,
      );
      _messages.add(replacement);
      _sortMessages();
    });
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime == 0 ? a.id.compareTo(b.id) : byTime;
    });
  }

  Future<void> _refresh() async {
    if (_loading || _loadingOlder || _sending) return;
    setState(() => _loading = true);
    await _loadInitial();
  }

  void _mergePage(MessagePage page) {
    final known = _messages.map((message) => message.id).toSet();
    _messages.addAll(page.messages.where((message) => known.add(message.id)));
    _sortMessages();
    _cursor = page.nextCursor;
    _refreshCursor = page.refreshCursor;
  }

  void _showLoadError(MessageException error) {
    _error = error.message;
    _accessDenied =
        error.statusCode == 403 || error.message.contains('cannot access');
    if (_accessDenied) {
      _messages.clear();
      _cursor = null;
      _refreshCursor = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Conversation'),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading || _loadingOlder || _sending ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                if (_isClosed)
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
                            _loadingOlder ? 'Loading...' : 'Load more messages',
                          ),
                        ),
                      if (_messages.isEmpty)
                        const Center(child: Text('No messages yet.')),
                      for (final message in _messages) _messageBubble(message),
                    ],
                  ),
                ),
                if (!_isClosed)
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
              if (mine && status == MessageDeliveryStatus.failed && !_isClosed)
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
