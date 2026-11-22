import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';
import 'user_profile.dart';
import '../../core/localization/app_language.dart';

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
        _error = AppStrings.of(context).profileNameInvalid;
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
        SnackBar(content: Text(AppStrings.of(context).profileSaveSuccess)),
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
          title: Text(AppStrings.of(dialogContext).profileSignOutTitle),
          content: Text(
            _editing
                ? AppStrings.of(dialogContext).profileUnsavedSignOut
                : AppStrings.of(dialogContext).profileConfirmSignOut,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(AppStrings.of(dialogContext).cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(AppStrings.of(dialogContext).signOut),
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
        _error = AppStrings.of(context).profileSignOutFailed;
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
    final strings = AppStrings.of(context);

    return PopScope(
      canPop: !_saving && !_signingOut,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.settings),
          actions: [
            IconButton(
              tooltip: strings.refreshProfile,
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
                      strings.manageAccount,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      strings.accountDescription,
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
                      Text(strings.profileLoadFailed),

                      const SizedBox(height: 12),

                      FilledButton(
                        onPressed: _signingOut ? null : _loadProfile,
                        child: Text(strings.profileTryAgain),
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
                        decoration: InputDecoration(
                          labelText: strings.displayName,
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
                        decoration: InputDecoration(
                          labelText: strings.profileEmail,
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Account role.
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: Text(strings.accountRole),
                        subtitle: Text(profile.role),
                      ),

                      // Account status.
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(strings.accountStatus),
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
                          label: Text(
                            _saving
                                ? strings.profileSaving
                                : strings.saveChanges,
                          ),
                        )
                      else
                        FilledButton.icon(
                          key: const Key('edit-profile'),
                          onPressed: _signingOut ? null : _startEditing,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(strings.editProfile),
                        ),

                      // Cancel editing.
                      if (_editing)
                        TextButton(
                          key: const Key('cancel-profile-edit'),
                          onPressed: _saving || _signingOut
                              ? null
                              : _cancelEditing,
                          child: Text(strings.cancel),
                        ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // CCVO-82: Language selection is independent of profile API availability.
                    Text(strings.language, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(strings.languageHint),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const Key('app-language-selector'),
                      initialValue:
                          AppLanguageScope.maybeOf(context)
                              ?.locale
                              .languageCode ??
                          'en',
                      decoration: InputDecoration(labelText: strings.language),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(strings.english),
                        ),
                        DropdownMenuItem(
                          value: 'es',
                          child: Text(strings.spanishLabel),
                        ),
                      ],
                      onChanged: (code) {
                        if (code != null) {
                          AppLanguageScope.maybeOf(context)?.select(code);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Account session management.
                    Text(
                      strings.accountSession,
                      style: theme.textTheme.titleLarge,
                    ),

                    const SizedBox(height: 8),

                    Text(strings.profileSignOutHint),

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
                      label: Text(
                        _signingOut
                            ? strings.profileSigningOut
                            : strings.signOut,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
