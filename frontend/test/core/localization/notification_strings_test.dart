import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('notification inbox strings are available in both languages', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.notificationsTitle, 'Notifications');
    expect(es.notificationsTitle, 'Notificaciones');
    expect(en.notificationsEmpty, 'No notifications yet');
    expect(es.notificationsEmpty, 'Aún no hay notificaciones');
    expect(en.notificationOfferReceived, 'New Offer Received');
    expect(es.notificationOfferReceived, 'Nueva oferta recibida');
    expect(
      en.notificationMessageReceivedDetail,
      'You have a new message about a request.',
    );
    expect(
      es.notificationMessageReceivedDetail,
      'Tienes un mensaje nuevo sobre una solicitud.',
    );
    expect(en.notificationMinutesAgo(3), '3m ago');
    expect(es.notificationMinutesAgo(3), 'Hace 3 min');
  });
}
