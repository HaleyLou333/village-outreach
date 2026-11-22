import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('request detail strings preserve English labels', () {
    final strings = AppStrings('en');
    expect(strings.manageYourRequest, 'Manage Your Request');
    expect(strings.markCompleted, 'Mark Completed');
    expect(strings.cancelRequestMessage, contains('cannot be undone'));
    expect(strings.requestCompleted, 'Request marked as completed.');
  });

  test('request detail strings translate to Spanish', () {
    final strings = AppStrings('es');
    expect(strings.manageYourRequest, 'Administrar tu solicitud');
    expect(strings.markCompleted, 'Marcar como completada');
    expect(strings.cancelRequestTitle, '¿Cancelar solicitud?');
    expect(strings.requestCompleted, 'Solicitud marcada como completada.');
    expect(strings.milesAway('2.5'), 'A 2.5 millas');
    expect(strings.ownershipFailure('offline'), contains('offline'));
  });
}
