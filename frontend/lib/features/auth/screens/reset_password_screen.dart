import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
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
                          const AuthFeedback(
                            title: 'Password updated',
                            message: 'Your new password is saved. Use it the next time you sign in. You can continue to Village Outreach now.',
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: widget.onCompleted,
                            child: const Text('Continue to Village Outreach'),
                          ),
                        ]
                      : [
                          const AuthFeedback(
                            title: 'Reset link verified',
                            message: 'Choose a new password to finish resetting your account.',
                            icon: Icons.lock_open_outlined,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Use at least 8 characters and a password different from your current one.',
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            enabled: !_saving,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: const InputDecoration(
                              labelText: 'New password',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => (value?.length ?? 0) >= 8
                                ? null
                                : 'Use at least 8 characters.',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmation,
                            obscureText: true,
                            enabled: !_saving,
                            decoration: const InputDecoration(
                              labelText: 'Confirm new password',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == _password.text
                                ? null
                                : 'Passwords must match.',
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            AuthFeedback(
                              title: 'Password not updated',
                              message: _error!,
                              error: true,
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const AuthBusyLabel('Updating password...')
                                : const Text('Update password'),
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
                            child: const Text('Request another reset email'),
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
