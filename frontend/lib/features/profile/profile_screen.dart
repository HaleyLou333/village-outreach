import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';
import 'user_profile.dart';

class ProfileScreen extends StatefulWidget {
  // Optional dependencies for automated testing.
  final ProfileService? profileService;
  final Future<void> Function()? signOutAction;

  const ProfileScreen({super.key, this.profileService, this.signOutAction});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileService _service;
  late final bool _ownsService;

  final TextEditingController _nameController = TextEditingController();

  UserProfile? _profile;

  String? _error;

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();

    _ownsService = widget.profileService == null;
    _service = widget.profileService ?? ProfileService();

    _loadProfile();
  }

  /// Retrieves the authenticated user's profile.
  Future<void> _loadProfile() async {
    // Prevent refresh from overwriting unsaved changes.
    if (_editing || _saving || _signingOut) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.getProfile();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _nameController.text = profile.displayName;
        _editing = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Updates the authenticated user's display name.
  Future<void> _saveProfile() async {
    if (_saving || _signingOut || !_editing) return;

    final name = _nameController.text.trim();

    if (name.isEmpty || name.length > 100) {
      setState(() {
        _error =
            'Display name must be between '
            '1 and 100 characters.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = await _service.updateDisplayName(name);

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _nameController.text = profile.displayName;
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (error) {
      if (!mounted) return;

      // Preserve the entered display name after a failure.
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// Enables profile editing.
  void _startEditing() {
    if (_loading || _saving || _signingOut) return;

    setState(() {
      _editing = true;
      _error = null;
    });
  }

  /// Discards unsaved profile changes.
  void _cancelEditing() {
    if (_saving || _signingOut) return;

    final profile = _profile;

    if (profile == null) return;

    setState(() {
      _editing = false;
      _error = null;
      _nameController.text = profile.displayName;
    });
  }

  /// CCVO-70: Signs out of the authenticated session.
  Future<void> _signOut() async {
    if (_signingOut || _saving || _loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: Text(
            _editing
                ? 'Unsaved profile changes will be lost. '
                      'Are you sure you want to sign out?'
                : 'Are you sure you want to sign out '
                      'of Village Outreach?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _signingOut || _saving) {
      return;
    }

    setState(() {
      _signingOut = true;
      _error = null;
    });

    try {
      final signOutAction = widget.signOutAction;

      if (signOutAction != null) {
        await signOutAction();
      } else {
        await Supabase.instance.client.auth.signOut();
      }

      // AuthGate handles the authenticated route transition.
      // Do not manually push another authentication screen.
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to sign out. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();

    if (_ownsService) {
      _service.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_saving && !_signingOut,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account Settings'),
          actions: [
            IconButton(
              tooltip: 'Refresh profile',
              onPressed: _loading || _saving || _editing || _signingOut
                  ? null
                  : _loadProfile,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Profile avatar.
                    const Center(
                      child: CircleAvatar(
                        radius: 42,
                        child: Icon(Icons.person_outline, size: 44),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Manage your account',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'View and update your Village Outreach '
                      'profile and account settings.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Inline error message.
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],

                    // Profile loading failure.
                    if (profile == null) ...[
                      const Text('Unable to load your profile.'),

                      const SizedBox(height: 12),

                      FilledButton(
                        onPressed: _signingOut ? null : _loadProfile,
                        child: const Text('Try Again'),
                      ),
                    ] else ...[
                      // Display name.
                      TextField(
                        key: const Key('profile-display-name'),
                        controller: _nameController,
                        enabled: _editing && !_saving && !_signingOut,
                        maxLength: 100,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_editing && !_saving && !_signingOut) {
                            _saveProfile();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Email address is read-only.
                      TextFormField(
                        key: ValueKey('profile-email-${profile.email}'),
                        initialValue: profile.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Account role.
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Account Role'),
                        subtitle: Text(profile.role),
                      ),

                      // Account status.
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Account Status'),
                        subtitle: Text(profile.status),
                      ),

                      const SizedBox(height: 24),

                      // Save or edit profile.
                      if (_editing)
                        FilledButton.icon(
                          key: const Key('save-profile'),
                          onPressed: _saving || _signingOut
                              ? null
                              : _saveProfile,
                          icon: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save Changes'),
                        )
                      else
                        FilledButton.icon(
                          key: const Key('edit-profile'),
                          onPressed: _signingOut ? null : _startEditing,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Profile'),
                        ),

                      // Cancel editing.
                      if (_editing)
                        TextButton(
                          key: const Key('cancel-profile-edit'),
                          onPressed: _saving || _signingOut
                              ? null
                              : _cancelEditing,
                          child: const Text('Cancel'),
                        ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Account session management.
                    Text('Account Session', style: theme.textTheme.titleLarge),

                    const SizedBox(height: 8),

                    const Text(
                      'Sign out of your Village Outreach '
                      'account on this device.',
                    ),

                    const SizedBox(height: 16),

                    // CCVO-70: Sign-out control.
                    OutlinedButton.icon(
                      key: const Key('account-sign-out'),
                      onPressed: _saving || _signingOut ? null : _signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: _signingOut
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_signingOut ? 'Signing Out...' : 'Sign Out'),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
