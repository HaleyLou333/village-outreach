import '../models/help_offer.dart';

class OfferException implements Exception {
  const OfferException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class OfferRepository {
  Future<HelpOffer> submitOffer({
    required String requestId,
    required String requestOwnerId,
    required String helperId,
    required String message,
  });

  Future<List<HelpOffer>> getRequestOffers({
    required String requestId,
    required String requesterId,
    required String requestOwnerId,
  });

  Future<HelpOffer?> getMyOffer({
    required String requestId,
    required String helperId,
  });

  Future<HelpOffer> acceptOffer({
    required String requestId,
    required String offerId,
    required String requesterId,
    required String requestOwnerId,
  });
}

class MockOfferRepository implements OfferRepository {
  final List<HelpOffer> _offers = [];
  int _nextId = 1;

  @override
  Future<HelpOffer> submitOffer({
    required String requestId,
    required String requestOwnerId,
    required String helperId,
    required String message,
  }) async {
    if (helperId == requestOwnerId) {
      throw const OfferException('You cannot offer help on your own request.');
    }

    if (message.trim().isEmpty) {
      throw const OfferException('Please enter a message.');
    }

    final existing = _offers.any(
      (offer) => offer.requestId == requestId && offer.helperId == helperId,
    );

    if (existing) {
      throw const OfferException('You have already submitted an offer.');
    }

    final alreadyAccepted = _offers.any(
      (offer) =>
          offer.requestId == requestId && offer.status == OfferStatus.accepted,
    );

    if (alreadyAccepted) {
      throw const OfferException(
        'This request already has an accepted helper.',
      );
    }

    final offer = HelpOffer(
      id: 'mock-offer-${_nextId++}',
      requestId: requestId,
      helperId: helperId,
      message: message.trim(),
      status: OfferStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );

    _offers.add(offer);
    return offer;
  }

  @override
  Future<List<HelpOffer>> getRequestOffers({
    required String requestId,
    required String requesterId,
    required String requestOwnerId,
  }) async {
    if (requesterId != requestOwnerId) {
      throw const OfferException('Only the request owner can review offers.');
    }

    return List.unmodifiable(
      _offers.where((offer) => offer.requestId == requestId),
    );
  }

  @override
  Future<HelpOffer?> getMyOffer({
    required String requestId,
    required String helperId,
  }) async {
    for (final offer in _offers) {
      if (offer.requestId == requestId && offer.helperId == helperId) {
        return offer;
      }
    }

    return null;
  }

  @override
  Future<HelpOffer> acceptOffer({
    required String requestId,
    required String offerId,
    required String requesterId,
    required String requestOwnerId,
  }) async {
    if (requesterId != requestOwnerId) {
      throw const OfferException('Only the request owner can accept offers.');
    }

    final index = _offers.indexWhere(
      (offer) => offer.id == offerId && offer.requestId == requestId,
    );

    if (index == -1) {
      throw const OfferException('Offer not found.');
    }

    if (_offers[index].status != OfferStatus.pending) {
      throw const OfferException('This offer is no longer pending.');
    }

    if (_offers.any(
      (offer) =>
          offer.requestId == requestId && offer.status == OfferStatus.accepted,
    )) {
      throw const OfferException('Another offer has already been accepted.');
    }

    // Update all affected offers in one synchronous operation.
    for (var i = 0; i < _offers.length; i++) {
      final offer = _offers[i];

      if (offer.requestId != requestId || offer.status != OfferStatus.pending) {
        continue;
      }

      _offers[i] = offer.copyWith(
        status: offer.id == offerId
            ? OfferStatus.accepted
            : OfferStatus.declined,
      );
    }

    return _offers[index];
  }
}
