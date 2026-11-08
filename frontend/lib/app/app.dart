import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/auth_service.dart';
import '../features/home/home_screen.dart';

class VillageOutreachApp extends StatelessWidget {
  const VillageOutreachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Village Outreach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService, this.homeBuilder});
  final AuthService? authService;
  final WidgetBuilder? homeBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _auth = widget.authService ?? AuthService();
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  bool _recovering = false;
  int _recoveryGeneration = 0;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    _session = _auth.currentSession;
    _subscription = _auth.authChanges.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          _session = state.session;
          _linkError = null;
          if (state.event == AuthChangeEvent.passwordRecovery &&
              state.session != null) {
            _recovering = true;
            _recoveryGeneration++;
          } else if (state.event == AuthChangeEvent.signedOut) {
            _recovering = false;
          }
        });
        if (state.event == AuthChangeEvent.passwordRecovery ||
            state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.signedOut) {
          _showRootRoute();
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        const linkErrors = {
          'otp_expired',
          'flow_state_expired',
          'flow_state_not_found',
          'bad_code_verifier',
          'access_denied',
        };
        final isLinkError =
            error is AuthPKCEGrantCodeExchangeError ||
            (error is AuthException &&
                (linkErrors.contains(error.code) ||
                    linkErrors.contains(error.statusCode)));
        if (isLinkError) {
          setState(
            () => _linkError = 'This email link could not be used. It may have expired or already been used. Request a new email and open it immediately on this device.',
          );
          _showRootRoute();
        } else {
          // Refresh/network errors must not discard a form's unsaved input.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Unable to refresh your session. Check your connection and try again.',
                  ),
                ),
              );
            }
          });
        }
      },
    );
  }

  void _showRootRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _finishRecovery() {
    setState(() => _recovering = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Password updated.')));
  }

  @override
  Widget build(BuildContext context) {
    final Widget page;
    if (_session == null || _session!.isExpired) {
      page = SignInScreen(authService: _auth);
    } else if (_recovering) {
      page = ResetPasswordScreen(
        key: ValueKey(_recoveryGeneration),
        authService: _auth,
        onCompleted: _finishRecovery,
      );
    } else {
      page = widget.homeBuilder?.call(context) ?? const HomeScreen();
    }
    if (_linkError == null) return page;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: MaterialBanner(
            content: Text(_linkError!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _linkError = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
        Expanded(child: page),
      ],
    );
  }
}
