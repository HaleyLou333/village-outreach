import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:village_outreach/app/app.dart';
import 'package:village_outreach/features/auth/auth_service.dart';
import 'package:village_outreach/features/auth/screens/email_action_screen.dart';
import 'package:village_outreach/features/auth/screens/create_account_screen.dart';
import 'package:village_outreach/features/auth/screens/reset_password_screen.dart';

Session session() {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return Session.fromJson({
    'access_token': '${part({'alg': 'HS256'})}.${part({'exp': exp})}.test',
    'token_type': 'bearer',
    'refresh_token': 'test-refresh',
    'expires_in': 3600,
    'user': {
      'id': '00000000-0000-0000-0000-000000000001',
      'aud': 'authenticated',
      'email': 'test@example.invalid',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-11-01T12:00:00Z',
    },
  })!;
}

class FakeAuthService extends AuthService {
  FakeAuthService()
    : super(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        ),
      );
  final events = StreamController<AuthState>.broadcast();
  Session? current;
  int resets = 0;
  int confirmations = 0;
  String? changedPassword;
  Object? failure;
  bool emitUpdateEvent = false;
  Completer<void>? pending;
  @override
  Session? get currentSession => current;
  @override
  Stream<AuthState> get authChanges => events.stream;
  @override
  Future<AuthResponse> signUp(
    String name,
    String email,
    String password,
  ) async => AuthResponse();
  @override
  Future<void> requestPasswordReset(String email) async {
    resets++;
    await pending?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    confirmations++;
    await pending?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> updatePassword(String password) async {
    await pending?.future;
    if (failure != null) throw failure!;
    changedPassword = password;
    if (emitUpdateEvent) emit(AuthChangeEvent.userUpdated, current);
  }

  void emit(AuthChangeEvent event, Session? value) {
    current = value;
    events.add(AuthState(event, value));
  }
}

class ReplayedAuthService extends FakeAuthService {
  @override
  Stream<AuthState> get authChanges async* {
    yield AuthState(AuthChangeEvent.passwordRecovery, current);
    yield* events.stream;
  }
}

void main() {
  testWidgets('Signing out removes an open private route', (tester) async {
    final service = FakeAuthService()..current = session();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: AuthGate(
          authService: service,
          homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Text('Private conversation content')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private conversation content'), findsOneWidget);
    service.emit(AuthChangeEvent.signedOut, null);
    await tester.pumpAndSettle();
    expect(find.text('Private conversation content'), findsNothing);
    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await service.events.close();
  });

  testWidgets(
    'Signup keeps confirmation instructions visible without resending',
    (tester) async {
      final service = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: CreateAccountScreen(authService: service)),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Neighbor');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test@example.invalid',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'test-password');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create Account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(service.confirmations, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Rate limited email requests explain next steps without success',
    (tester) async {
      final service = FakeAuthService()
        ..failure = const AuthException(
          'private',
          code: 'over_email_send_rate_limit',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: EmailActionScreen(
            resetPassword: false,
            authService: service,
            initialEmail: 'test@example.invalid',
          ),
        ),
      );
      await tester.tap(find.text('Send email'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Too many email requests'), findsOneWidget);
      expect(find.text('Check your inbox'), findsNothing);
      expect(find.text('private'), findsNothing);
    },
  );

  testWidgets('Saving password shows progress and blocks repeated updates', (
    tester,
  ) async {
    final service = FakeAuthService()..pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordScreen(authService: service, onCompleted: () {}),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), 'test-password');
    }
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Updating password...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    service.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Password updated'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
    'Same password explains what to change without completing recovery',
    (tester) async {
      final service = FakeAuthService()
        ..failure = const AuthException(
          'private diagnostics',
          code: 'same_password',
        );
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ResetPasswordScreen(
            authService: service,
            onCompleted: () => completed = true,
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.enterText(
          find.byType(TextFormField).at(i),
          'test-password',
        );
      }
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('different from your current password'),
        findsOneWidget,
      );
      expect(find.text('private diagnostics'), findsNothing);
      expect(completed, isFalse);
    },
  );

  testWidgets(
    'Email progress prevents duplicates and success clears on address edit',
    (tester) async {
      final service = FakeAuthService()..pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: EmailActionScreen(
            resetPassword: true,
            authService: service,
            initialEmail: 'test@example.invalid',
          ),
        ),
      );
      await tester.tap(find.text('Send email'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sending email...'), findsOneWidget);
      await tester.tap(find.text('Sending email...'));
      expect(service.resets, 1);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.textContaining('test@example.invalid'), findsWidgets);
      expect(find.text('Send again in 60s'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'other@example.invalid',
      );
      await tester.pump();
      expect(find.text('Check your inbox'), findsNothing);
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Send email'), findsOneWidget);
      service.failure = const AuthException('offline');
      await tester.tap(find.text('Send email'));
      await tester.pumpAndSettle();
      expect(service.resets, 2);
      expect(find.text('Email not requested'), findsOneWidget);
      expect(find.text('Check your inbox'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('A transient auth refresh error preserves an open form', (
    tester,
  ) async {
    final service = FakeAuthService()..current = session();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: AuthGate(
          authService: service,
          homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: TextField(
            decoration: InputDecoration(labelText: 'Unsaved title'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep my unsaved request');
    service.events.addError(AuthRetryableFetchException(message: 'offline'));
    await tester.pumpAndSettle();
    expect(find.text('Keep my unsaved request'), findsOneWidget);
    expect(find.textContaining('Request a new email'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await service.events.close();
  });
  for (final signedIn in [false, true]) {
    testWidgets(
      'Expired recovery returns from email page and shows error ($signedIn)',
      (tester) async {
        final service = FakeAuthService()
          ..current = signedIn ? session() : null;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: AuthGate(
              authService: service,
              homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
            ),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                EmailActionScreen(resetPassword: true, authService: service),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EmailActionScreen), findsOneWidget);
        service.events.addError(
          const AuthException(
            'flow state has expired',
            code: 'flow_state_expired',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EmailActionScreen), findsNothing);
        expect(find.textContaining('Request a new email'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.events.close();
      },
    );
  }
  testWidgets(
    'A recovery event replayed on cold start opens the reset screen',
    (tester) async {
      final service = ReplayedAuthService()..current = session();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: service,
            homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.text('Signed-in home'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.events.close();
    },
  );

  testWidgets('SDK userUpdated event completes recovery safely', (
    tester,
  ) async {
    final service = FakeAuthService()..emitUpdateEvent = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: service,
          homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
        ),
      ),
    );
    service.emit(AuthChangeEvent.passwordRecovery, session());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test-new-password',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'test-new-password',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(service.changedPassword, 'test-new-password');
    expect(find.text('Password updated'), findsOneWidget);
    expect(find.text('Signed-in home'), findsNothing);
    service.emit(AuthChangeEvent.passwordRecovery, session());
    await tester.pumpAndSettle();
    expect(find.text('Password updated'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      await tester.enterText(
        find.byType(TextFormField).at(i),
        'second-test-password',
      );
    }
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Village Outreach'));
    await tester.pumpAndSettle();
    expect(find.text('Signed-in home'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await service.events.close();
  });
  test('PKCE callbacks reject tokens in the query or fragment', () {
    for (final suffix in [
      '?access_token=test&refresh_token=test',
      '#access_token=test&refresh_token=test',
      '?code=test&access_token=test',
      '?code=test#refresh_token=test',
    ]) {
      expect(
        isAppAuthCallback(Uri.parse('${AuthService.callbackUrl}$suffix')),
        isFalse,
      );
    }
  });
  test('Callback detector accepts only the application callback with auth parameters', () {
    expect(
      isAppAuthCallback(Uri.parse('${AuthService.callbackUrl}?code=test')),
      isTrue,
    );
    expect(
      isAppAuthCallback(
        Uri.parse('${AuthService.callbackUrl}#error=access_denied'),
      ),
      isTrue,
    );
    expect(
      isAppAuthCallback(Uri.parse('https://other.example/?code=test')),
      isFalse,
    );
    expect(
      isAppAuthCallback(Uri.parse('io.villageoutreach://other/?code=test')),
      isFalse,
    );
    expect(isAppAuthCallback(Uri.parse(AuthService.callbackUrl)), isFalse);
  });

  test('Signup, reset and resend explicitly use the mobile callback', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/signup')
                ? {'user': session().user.toJson()}
                : {},
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final service = AuthService(supabase: client);
    await service.signUp('Neighbor', 'test@example.invalid', 'test-password');
    await service.requestPasswordReset('test@example.invalid');
    await service.resendConfirmation('test@example.invalid');
    expect(requests.length, 3);
    for (final request in requests) {
      expect(
        request.url.queryParameters['redirect_to'],
        AuthService.callbackUrl,
      );
      expect(request.url.toString(), isNot(contains('localhost')));
    }
    expect((jsonDecode(requests.first.body) as Map)['data'], {
      'display_name': 'Neighbor',
    });
    await client.dispose();
  });

  testWidgets(
    'Recovery stays on reset screen through token refresh until update succeeds',
    (tester) async {
      final service = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: service,
            homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
          ),
        ),
      );
      service.emit(AuthChangeEvent.passwordRecovery, session());
      await tester.pumpAndSettle();
      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.text('Signed-in home'), findsNothing);
      service.emit(AuthChangeEvent.tokenRefreshed, service.current);
      await tester.pumpAndSettle();
      expect(find.text('Choose a new password'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test-new-password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test-new-password',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(service.changedPassword, 'test-new-password');
      await tester.tap(find.text('Continue to Village Outreach'));
      await tester.pumpAndSettle();
      expect(find.text('Signed-in home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await service.events.close();
    },
  );

  testWidgets(
    'Bad auth-link stream error is handled without dropping signed-in state',
    (tester) async {
      final service = FakeAuthService()..current = session();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: service,
            homeBuilder: (_) => const Scaffold(body: Text('Signed-in home')),
          ),
        ),
      );
      service.events.addError(
        const AuthException(
          'private callback diagnostics',
          code: 'otp_expired',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Signed-in home'), findsOneWidget);
      expect(find.textContaining('Request a new email'), findsOneWidget);
      expect(find.textContaining('private callback diagnostics'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.events.close();
    },
  );

  testWidgets(
    'Reset validation blocks mismatched passwords and failed updates allow retry',
    (tester) async {
      final service = FakeAuthService()
        ..failure = const AuthException('expired');
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ResetPasswordScreen(
            authService: service,
            onCompleted: () {
              completed = true;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test-new-password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'different-password',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords must match.'), findsOneWidget);
      expect(service.changedPassword, isNull);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test-new-password',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(find.textContaining('Unable to update'), findsOneWidget);
      service.failure = null;
      await tester.ensureVisible(find.text('Update password'));
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(find.text('Password updated'), findsOneWidget);
      await tester.tap(find.text('Continue to Village Outreach'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    },
  );

  for (final reset in [true, false]) {
    testWidgets(
      'Email action validates input and reports same-device instructions ($reset)',
      (tester) async {
        final service = FakeAuthService();
        await tester.pumpWidget(
          MaterialApp(
            home: EmailActionScreen(authService: service, resetPassword: reset),
          ),
        );
        await tester.tap(find.text('Send email'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid email address.'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          'test@example.invalid',
        );
        await tester.tap(find.text('Send email'));
        await tester.pumpAndSettle();
        expect(reset ? service.resets : service.confirmations, 1);
        expect(find.textContaining('on this device'), findsOneWidget);
      },
    );
  }
}
