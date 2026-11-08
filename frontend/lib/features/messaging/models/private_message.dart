enum MessageDeliveryStatus { sending, sent, failed }

class PrivateMessage {
  const PrivateMessage({
    required this.id,
    required this.clientMessageId,
    required this.requestId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  final String id;
  final String clientMessageId;
  final String requestId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final MessageDeliveryStatus deliveryStatus;

  PrivateMessage copyWith({MessageDeliveryStatus? deliveryStatus}) =>
      PrivateMessage(
        id: id,
        clientMessageId: clientMessageId,
        requestId: requestId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      );
}
