import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';

void main() {
  test('authentication strings are available in both languages', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.signIn, 'Sign In');
    expect(es.signIn, 'Iniciar sesión');
    expect(es.createAccount, 'Crear cuenta');
    expect(es.invalidEmail, 'Ingresa un correo electrónico válido');
    expect(es.passwordMismatch, 'Las contraseñas deben coincidir.');
  });
  test('email feedback preserves account privacy and locale', () {
    final es = AppStrings('es');
    final en = AppStrings('en');
    expect(
      es.emailRequestAccepted('a@example.com', resetPassword: true),
      contains('a@example.com'),
    );
    expect(
      en.emailRequestAccepted('a@example.com', resetPassword: false),
      contains('If this account is eligible'),
    );
    expect(es.sendAgainIn(25), contains('25'));
  });
}
