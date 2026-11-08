import 'dart:async';

import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../auth_feedback.dart';

/// Shared reset/confirmation email form, with no account-enumeration response.
class EmailActionScreen extends StatefulWidget {
  const EmailActionScreen({
    super.key,
    required this.resetPassword,
    this.authService,
    this.initialEmail = '',
    this.emailAlreadyRequested = false,
  });
  final bool resetPassword;
  final AuthService? authService;
  final String initialEmail;
  final bool emailAlreadyRequested;
  @override
  State<EmailActionScreen> createState() => _EmailActionScreenState();
}

class _EmailActionScreenState extends State<EmailActionScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  late final _auth = widget.authService ?? AuthService();
  bool _sending = false;
  bool _sent = false;
  String? _error;
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  String? _requestedEmail;

  @override
  void initState() {
    super.initState();
    if (widget.emailAlreadyRequested) {
      _sent = true;
      _requestedEmail = widget.initialEmail.trim();
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _secondsRemaining = 60;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining == 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (_sending || _secondsRemaining > 0 || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _sent = false;
    });
    try {
      if (widget.resetPassword) {
        await _auth.requestPasswordReset(_email.text);
      } else {
        await _auth.resendConfirmation(_email.text);
      }
      if (mounted) {
        setState(() {
          _sent = true;
          _requestedEmail = _email.text.trim();
          _startCooldown();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = emailRequestError(error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.resetPassword ? 'Reset password' : 'Confirm your email',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.resetPassword
                          ? 'Enter your account email to request a password reset.'
                          : 'Enter your account email to request another confirmation link.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      enabled: !_sending,
                      onChanged: (_) => setState(() {
                        _sent = false;
                        _error = null;
                      }),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Enter a valid email address.',
                    ),
                    const SizedBox(height: 20),
                    if (_sent) ...[
                      AuthFeedback(
                        title: 'Check your inbox',
                        icon: Icons.mark_email_read_outlined,
                        message:
                            'Email request accepted for $_requestedEmail. If this account is eligible, you will receive a link. Check your spam folder too.\n\nOpen the newest link on this device, where you requested it. ${widget.resetPassword ? 'Then choose a new password.' : 'Then return here to sign in.'}',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      AuthFeedback(
                        title: 'Email not requested',
                        message: _error!,
                        error: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _sending || _secondsRemaining > 0
                          ? null
                          : _send,
                      child: _sending
                          ? const AuthBusyLabel('Sending email...')
                          : Text(
                              _secondsRemaining > 0
                                  ? 'Send again in ${_secondsRemaining}s'
                                  : _sent
                                  ? 'Send another email'
                                  : 'Send email',
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                      child: Text(
                        _auth.currentSession == null
                            ? 'Back to sign in'
                            : 'Back to app',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
