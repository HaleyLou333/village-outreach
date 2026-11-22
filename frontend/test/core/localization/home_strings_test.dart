import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('home labels translate to Spanish', () {
    final es = AppStrings('es');
    expect(es.nearbyRequests, 'Solicitudes cercanas');
    expect(es.requestHelp, 'Solicitar ayuda');
    expect(es.allCategories, 'Todas las categorías');
    expect(es.withinKm(10), 'A 10 km o menos');
    expect(es.noNearbyRequests, contains('No se encontraron'));
    expect(es.signOutFailed('error'), contains('error'));
  });

  test('home labels preserve existing English text', () {
    final en = AppStrings('en');
    expect(en.nearbyRequests, 'Nearby Requests');
    expect(en.requestHelp, 'Request Help');
    expect(en.withinKm(10), 'Within 10 km');
    expect(en.noNearbyRequests, contains('No active requests'));
  });
}
