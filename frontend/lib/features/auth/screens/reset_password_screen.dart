import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';

import '../auth_service.dart';
import '../auth_feedback.dart';
import 'email_action_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.authService,
    required this.onCompleted,
  });
  final AuthService? authService;
  final VoidCallback onCompleted;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final _auth = widget.authService ?? AuthService();
  bool _saving = false;
  bool _saved = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _auth.updatePassword(_password.text);
      if (mounted) {
        _password.clear();
        _confirmation.clear();
        setState(() => _saved = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = passwordUpdateError(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.chooseNewPassword)),
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
                  children: _saved
                      ? [
                          AuthFeedback(
                            title: strings.passwordUpdated,
                            message: strings.passwordSavedMessage,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: widget.onCompleted,
                            child: Text(strings.continueVillage),
                          ),
                        ]
                      : [
                          AuthFeedback(
                            title: strings.resetVerified,
                            message: strings.choosePasswordInstruction,
                            icon: Icons.lock_open_outlined,
                          ),
                          const SizedBox(height: 20),
                          Text(strings.passwordRule),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            enabled: !_saving,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: strings.newPassword,
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => (value?.length ?? 0) >= 8
                                ? null
                                : strings.minEightPeriod,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmation,
                            obscureText: true,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText: strings.confirmNewPassword,
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == _password.text
                                ? null
                                : strings.passwordMismatch,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            AuthFeedback(
                              title: strings.passwordNotUpdated,
                              message: _error!,
                              error: true,
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? AuthBusyLabel(strings.updatingPassword)
                                : Text(strings.updatePassword),
                          ),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => EmailActionScreen(
                                        resetPassword: true,
                                        authService: _auth,
                                        initialEmail:
                                            _auth.currentSession?.user.email ??
                                            '',
                                      ),
                                    ),
                                  ),
                            child: Text(strings.anotherResetEmail),
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
