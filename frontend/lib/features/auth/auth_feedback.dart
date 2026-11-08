import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persistent, screen-reader announced feedback for an authentication step.
class AuthFeedback extends StatelessWidget {
  const AuthFeedback({
    super.key,
    required this.title,
    required this.message,
    this.error = false,
    this.icon = Icons.check_circle_outline,
  });
  final String title;
  final String message;
  final bool error;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = error
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(error ? Icons.error_outline : icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 6),
                  Text(message, style: TextStyle(color: foreground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthBusyLabel extends StatelessWidget {
  const AuthBusyLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}

String passwordUpdateError(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'same_password':
        return 'Choose a different password. Your new password must be different from your current password.';
      case 'weak_password':
        return 'Choose a stronger password. Use at least 8 characters and avoid common or easily guessed passwords.';
      case 'session_not_found':
      case 'session_expired':
      case 'otp_expired':
      case 'reauthentication_needed':
        return 'Your reset session has expired. Request a new reset email below and open the newest link on this device.';
    }
  }
  return 'Unable to update your password. Check your connection and try again, or request a new reset email if the link expired.';
}

String emailRequestError(Object error) {
  if (error is AuthException &&
      (error.code == 'over_email_send_rate_limit' ||
          error.code == 'over_request_rate_limit' ||
          error.statusCode == '429')) {
    return 'Too many email requests. Wait a few minutes before trying again. Check your inbox and spam folder for the newest email.';
  }
  return 'Unable to request the email. Check your connection and try again. If an email arrives, use only its newest link.';
}
