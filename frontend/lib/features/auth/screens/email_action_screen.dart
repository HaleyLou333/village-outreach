import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';

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
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.resetPassword ? strings.resetPassword : strings.confirmEmail,
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
                          ? strings.resetEmailInstruction
                          : strings.confirmationInstruction,
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
                      decoration: InputDecoration(
                        labelText: strings.emailAddress,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value?.trim() ?? '')
                          ? null
                          : strings.invalidEmailPeriod,
                    ),
                    const SizedBox(height: 20),
                    if (_sent) ...[
                      AuthFeedback(
                        title: strings.checkInbox,
                        icon: Icons.mark_email_read_outlined,
                        message: strings.emailRequestAccepted(
                          _requestedEmail ?? '',
                          resetPassword: widget.resetPassword,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      AuthFeedback(
                        title: strings.emailNotRequested,
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
                          ? AuthBusyLabel(strings.sendingEmail)
                          : Text(
                              _secondsRemaining > 0
                                  ? strings.sendAgainIn(_secondsRemaining)
                                  : _sent
                                  ? strings.sendAnother
                                  : strings.sendEmail,
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
                            ? strings.backSignIn
                            : strings.backApp,
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
