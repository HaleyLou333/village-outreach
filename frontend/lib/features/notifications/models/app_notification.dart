enum AppNotificationType {
  offerReceived('offer_received'),
  offerAccepted('offer_accepted'),
  messageReceived('message_received');

  const AppNotificationType(this.apiValue);

  final String apiValue;

  static AppNotificationType fromApi(String value) {
    for (final type in values) {
      if (type.apiValue == value) {
        return type;
      }
    }

    throw FormatException('Unsupported notification type: $value');
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.requestId,
    required this.type,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String requestId;
  final AppNotificationType type;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;

  String get title {
    switch (type) {
      case AppNotificationType.offerReceived:
        return 'New Offer Received';
      case AppNotificationType.offerAccepted:
        return 'Your Offer Was Accepted';
      case AppNotificationType.messageReceived:
        return 'New Message';
    }
  }

  String get description {
    switch (type) {
      case AppNotificationType.offerReceived:
        return 'Someone has offered to help with your request.';
      case AppNotificationType.offerAccepted:
        return 'Your offer was accepted. View the request for details.';
      case AppNotificationType.messageReceived:
        return 'You have a new message about a request.';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final requestId = json['request_id'];
    final type = json['type'];
    final createdAt = json['created_at'];
    final readAt = json['read_at'];

    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id)) {
      throw const FormatException('Invalid notification ID.');
    }

    if (requestId is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(requestId)) {
      throw const FormatException('Invalid notification request ID.');
    }

    if (type is! String ||
        createdAt is! String ||
        (readAt != null && readAt is! String)) {
      throw const FormatException('Invalid notification response.');
    }

    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedReadAt = readAt == null ? null : DateTime.tryParse(readAt);

    if (parsedCreatedAt == null || (readAt != null && parsedReadAt == null)) {
      throw const FormatException('Invalid notification timestamp.');
    }

    return AppNotification(
      id: id,
      requestId: requestId,
      type: AppNotificationType.fromApi(type),
      createdAt: parsedCreatedAt.toUtc(),
      readAt: parsedReadAt?.toUtc(),
    );
  }
}
