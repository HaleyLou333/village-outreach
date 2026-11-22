import '../../requests/services/request_service.dart';
import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
  });

  Future<AppNotification> markAsRead(String notificationId);
}

class NotificationService implements NotificationRepository {
  NotificationService({RequestService? transport})
    : _transport = transport ?? RequestService(),
      _ownsTransport = transport == null;

  final RequestService _transport;
  final bool _ownsTransport;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100) {
      throw const RequestApiException(
        'Notification page size must be between 1 and 100.',
      );
    }

    if (offset < 0 || offset > 10000) {
      throw const RequestApiException('Invalid notification page offset.');
    }

    final result = await _transport.requestJson(
      'GET',
      '/notifications',
      operation: 'view notifications',
      query: {'limit': limit.toString(), 'offset': offset.toString()},
    );

    if (result is! List) {
      throw const RequestApiException(
        'The notification service returned an unexpected response.',
      );
    }

    try {
      return result.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid notification item.');
        }

        return AppNotification.fromJson(item);
      }).toList();
    } on FormatException {
      throw const RequestApiException('Unable to read notification data.');
    } on TypeError {
      throw const RequestApiException('Unable to read notification data.');
    }
  }

  @override
  Future<AppNotification> markAsRead(String notificationId) async {
    if (!_uuidPattern.hasMatch(notificationId)) {
      throw const RequestApiException('Invalid notification ID.');
    }

    final result = await _transport.requestJson(
      'PATCH',
      '/notifications/${Uri.encodeComponent(notificationId)}/read',
      operation: 'mark notification as read',
    );

    if (result is! Map<String, dynamic>) {
      throw const RequestApiException(
        'The notification service returned an unexpected response.',
      );
    }

    try {
      final notification = AppNotification.fromJson(result);

      if (notification.id.toLowerCase() != notificationId.toLowerCase() ||
          notification.readAt == null) {
        throw const FormatException('Invalid notification read receipt.');
      }

      return notification;
    } on FormatException {
      throw const RequestApiException(
        'Unable to confirm the notification was marked as read.',
      );
    }
  }

  void dispose() {
    if (_ownsTransport) {
      _transport.dispose();
    }
  }
}
