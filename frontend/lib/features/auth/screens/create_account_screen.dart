import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_service.dart';
import '../auth_feedback.dart';
import 'email_action_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, this.authService});
  final AuthService? authService;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _auth = widget.authService ?? AuthService();

  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _auth.signUp(
        _name.text,
        _email.text,
        _password.text,
      );

      if (!mounted) return;

      if (response.session == null) {
        final email = _email.text.trim();
        _password.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => EmailActionScreen(
              resetPassword: false,
              authService: _auth,
              initialEmail: email,
              emailAlreadyRequested: true,
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pop();
      // If sign-up created a session, AuthGate shows Home.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Account creation failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/brand/logo.png', height: 72),
                    const SizedBox(height: 20),
                    Text(
                      'Join Village Outreach',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value?.trim() ?? '')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _loading ? null : _createAccount,
                        child: _loading
                            ? const AuthBusyLabel('Creating account...')
                            : const Text('Create Account'),
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
