import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('public resources retain existing English UI strings', () {
    final strings = AppStrings('en');
    expect(strings.publicResourcesTitle, 'Community Resources');
    expect(strings.publicResourcesHeading, 'Find local support');
    expect(strings.publicMap, 'Map');
    expect(strings.publicList, 'List');
    expect(strings.publicFound(2), '2 resources found');
    expect(
      strings.publicShowingArea('Oklahoma City Metro'),
      'Showing resources in Oklahoma City Metro',
    );
    expect(
      strings.publicVerifiedDate('2026-11-10'),
      'Last verified: 2026-11-10',
    );
    expect(strings.publicViewDetails, 'View details');
    expect(strings.publicDetailsTitle, 'Resource Details');
    expect(strings.publicDisclaimer, contains('confirm availability'));
  });

  test('public resource discovery and details translate to Spanish', () {
    final strings = AppStrings('es');
    expect(strings.publicResourcesTitle, 'Recursos comunitarios');
    expect(strings.publicSearchArea, 'Buscar área');
    expect(strings.publicUseLocation, 'Usar mi ubicación actual');
    expect(strings.publicMap, 'Mapa');
    expect(strings.publicList, 'Lista');
    expect(strings.publicFound(3), '3 recursos encontrados');
    expect(
      strings.publicShowingArea('Oklahoma City Metro'),
      'Mostrando recursos en Oklahoma City Metro',
    );
    expect(
      strings.publicVerifiedDate('2026-11-10'),
      'Última verificación: 2026-11-10',
    );
    expect(strings.publicDetailsTitle, 'Detalles del recurso');
    expect(strings.publicLinkError, 'No se puede abrir este enlace.');
    expect(strings.publicDisclaimer, contains('disponibilidad'));
  });
}
