import 'package:flutter/material.dart';

import '../../messaging/screens/private_conversation_screen.dart';
import '../../messaging/services/message_service.dart';

import '../models/help_offer.dart';
import '../services/offer_service.dart';

class RequestOffersScreen extends StatefulWidget {
  const RequestOffersScreen({
    super.key,
    required this.requestId,
    required this.requestOwnerId,
    required this.currentUserId,
    required this.repository,
    this.messageRepository,
    this.isClosed = false,
  });

  final String requestId;
  final String requestOwnerId;
  final String currentUserId;
  final OfferRepository repository;
  final MessageRepository? messageRepository;
  final bool isClosed;

  @override
  State<RequestOffersScreen> createState() => _RequestOffersScreenState();
}

class _RequestOffersScreenState extends State<RequestOffersScreen> {
  final TextEditingController _messageController = TextEditingController();

  List<HelpOffer> _offers = [];
  HelpOffer? _myOffer;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isOwner => widget.currentUserId == widget.requestOwnerId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isOwner) {
        final offers = await widget.repository.getRequestOffers(
          requestId: widget.requestId,
          requesterId: widget.currentUserId,
          requestOwnerId: widget.requestOwnerId,
        );

        if (!mounted) return;
        setState(() => _offers = offers);
      } else {
        final offer = await widget.repository.getMyOffer(
          requestId: widget.requestId,
          helperId: widget.currentUserId,
        );

        if (!mounted) return;
        setState(() => _myOffer = offer);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitOffer() async {
    if (_busy || widget.isClosed) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.submitOffer(
        requestId: widget.requestId,
        requestOwnerId: widget.requestOwnerId,
        helperId: widget.currentUserId,
        message: _messageController.text,
      );

      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptOffer(HelpOffer offer) async {
    if (_busy || widget.isClosed) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.acceptOffer(
        requestId: widget.requestId,
        offerId: offer.id,
        requesterId: widget.currentUserId,
        requestOwnerId: widget.requestOwnerId,
      );

      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());

      // A stale acceptance may mean another offer was accepted.
      // Refresh so the screen displays the latest state.
      await _refresh();
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openConversation(HelpOffer offer) async {
    if (offer.status != OfferStatus.accepted) return;

    final repository = widget.messageRepository;
    if (repository == null) return;

    if (widget.currentUserId != widget.requestOwnerId &&
        widget.currentUserId != offer.helperId) {
      return;
    }

    if (repository is MockMessageRepository) {
      repository.configureConversation(
        requestId: widget.requestId,
        requesterId: widget.requestOwnerId,
        acceptedHelperId: offer.helperId,
        isClosed: widget.isClosed,
      );
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrivateConversationScreen(
          requestId: widget.requestId,
          currentUserId: widget.currentUserId,
          repository: repository,
          isClosed: widget.isClosed,
        ),
      ),
    );
  }

  String _statusLabel(OfferStatus status) {
    switch (status) {
      case OfferStatus.pending:
        return 'Pending';
      case OfferStatus.accepted:
        return 'Accepted';
      case OfferStatus.declined:
        return 'Declined';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwner ? 'Incoming Offers' : 'Offer to Help'),
        actions: [
          IconButton(
            tooltip: 'Refresh offers',
            onPressed: _busy || _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        key: const Key('offer-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_isOwner) _buildOwnerView() else _buildHelperView(),
                ],
              ),
            ),
    );
  }

  Widget _buildHelperView() {
    final offer = _myOffer;

    if (widget.isClosed && offer == null) {
      return const Text('This request is closed. New offers are unavailable.');
    }

    if (offer != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Offer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Status: ${_statusLabel(offer.status)}'),
              const SizedBox(height: 12),
              Text(offer.message),
              if (widget.isClosed) ...[
                const SizedBox(height: 12),
                const Text(
                  'This request is closed. Conversation history is read-only.',
                ),
              ],
              if (offer.status == OfferStatus.accepted) ...[
                const SizedBox(height: 16),
                const Text('Your offer was accepted!'),
                if (widget.messageRepository != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('open-helper-conversation'),
                    onPressed: () => _openConversation(offer),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Open Conversation (Demo)'),
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Offer to Help',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('Let the requester know how you can help.'),
        const SizedBox(height: 16),
        TextField(
          key: const Key('offer-message'),
          controller: _messageController,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Your message',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('submit-offer'),
          onPressed: _busy ? null : _submitOffer,
          child: Text(_busy ? 'Submitting...' : 'Submit Offer'),
        ),
      ],
    );
  }

  Widget _buildOwnerView() {
    if (_offers.isEmpty) {
      return const Text('No offers have been submitted for this request.');
    }

    final hasAccepted = _offers.any(
      (offer) => offer.status == OfferStatus.accepted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isClosed) ...[
          const Text(
            'This request is closed. Existing conversations are read-only.',
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Incoming Offers',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final offer in _offers)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Helper: ${offer.helperId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(offer.message),
                  const SizedBox(height: 8),
                  Text('Status: ${_statusLabel(offer.status)}'),
                  if (offer.status == OfferStatus.accepted &&
                      widget.messageRepository != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: Key('open-owner-conversation-${offer.id}'),
                      onPressed: () => _openConversation(offer),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Open Conversation (Demo)'),
                    ),
                  ],
                  if (offer.status == OfferStatus.pending &&
                      !hasAccepted &&
                      !widget.isClosed) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      key: Key('accept-${offer.id}'),
                      onPressed: _busy ? null : () => _acceptOffer(offer),
                      child: const Text('Accept Offer'),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
