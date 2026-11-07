enum OfferStatus { pending, accepted, declined }

class HelpOffer {
  const HelpOffer({
    required this.id,
    required this.requestId,
    required this.helperId,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String helperId;
  final String message;
  final OfferStatus status;
  final DateTime createdAt;

  HelpOffer copyWith({OfferStatus? status}) {
    return HelpOffer(
      id: id,
      requestId: requestId,
      helperId: helperId,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
