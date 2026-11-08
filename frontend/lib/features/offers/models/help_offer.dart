enum OfferStatus { pending, accepted, declined, withdrawn }

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

  factory HelpOffer.fromJson(Map<String, dynamic> json) => HelpOffer(
    id: json['id'] as String,
    requestId: json['request_id'] as String,
    helperId: json['helper_id'] as String,
    message: json['message'] as String,
    status: OfferStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

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
