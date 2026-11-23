import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';
import 'user_profile.dart';
import 'volunteer_progress_card.dart';

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
  Future<VolunteerProgress?>? _volunteerProgress;
  String? _featuredBadge;
  Uint8List? _photo;
  bool _updatingPhoto = false;
  static const _maxPhotoBytes = 256 * 1024;

  Future<void> _loadPhoto(String userId) async {
    try {
      final photo = await _service.getPhoto();
      if (!mounted || _profile?.id != userId) return;
      setState(() => _photo = photo);
    } catch (_) {
      // The photo can be retried separately from other profile settings.
    }
  }

  Future<void> _updatePhoto({required bool remove}) async {
    final userId = _profile?.id;
    if (userId == null || _updatingPhoto) return;
    setState(() => _updatingPhoto = true);
    try {
      Uint8List? photo;
      if (remove) {
        await _service.removePhoto();
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 384,
          maxHeight: 384,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        if (picked == null || !mounted || _profile?.id != userId) return;
        if (await picked.length() > _maxPhotoBytes) {
          throw const FormatException('Choose a smaller photo.');
        }
        final bytes = await picked.readAsBytes();
        if (bytes.isEmpty || bytes.length > _maxPhotoBytes) {
          throw const FormatException('Choose a supported photo under 256 KB.');
        }
        if (!mounted || _profile?.id != userId) return;
        photo = await _service.uploadPhoto(bytes);
      }
      if (!mounted || _profile?.id != userId) return;
      setState(() => _photo = photo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remove ? 'Profile photo removed.' : 'Profile photo updated.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not update your photo. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

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
    if (_editing || _saving || _signingOut || _updatingPhoto) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.getProfile();

      if (!mounted) return;

      setState(() {
        if (_profile?.id != profile.id) {
          _featuredBadge = null;
          _photo = null;
        }
        _profile = profile;
        _volunteerProgress = _service
            .getVolunteerProgress()
            .then<VolunteerProgress?>(
              (progress) => progress,
              onError: (Object _) => null,
            );
        _nameController.text = profile.displayName;
        _editing = false;
      });
      await _loadPhoto(profile.id);
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
    if (_signingOut || _saving || _loading || _updatingPhoto) return;

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
      canPop: !_saving && !_signingOut && !_updatingPhoto,
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
                    FutureBuilder<VolunteerProgress?>(
                      future: _volunteerProgress,
                      builder: (context, snapshot) {
                        final badges =
                            snapshot.data?.badgeLabels ?? const <String>[];
                        final badge = badges.contains(_featuredBadge)
                            ? _featuredBadge
                            : badges.lastOrNull;
                        final colors = theme.colorScheme;
                        return Center(
                          child: Semantics(
                            label: badge == null
                                ? 'Profile avatar'
                                : 'Volunteer badge: $badge',
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: badge == null
                                          ? Colors.transparent
                                          : colors.primary,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 42,
                                    foregroundImage: _photo == null
                                        ? null
                                        : MemoryImage(_photo!),
                                    onForegroundImageError: _photo == null
                                        ? null
                                        : (_, _) {},
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 44,
                                    ),
                                  ),
                                ),
                                if (badge != null)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      child: const Icon(
                                        Icons.workspace_premium,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (profile != null)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _updatingPhoto || _signingOut
                                ? null
                                : () => _updatePhoto(remove: false),
                            child: Text(
                              _photo == null ? 'Upload photo' : 'Change photo',
                            ),
                          ),
                          if (_photo != null)
                            TextButton(
                              onPressed: _updatingPhoto || _signingOut
                                  ? null
                                  : () => _updatePhoto(remove: true),
                              child: const Text('Remove photo'),
                            ),
                        ],
                      ),
                    if (profile != null)
                      Text(
                        'Your photo appears on your member card in offers and chats.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
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
                      FutureBuilder<VolunteerProgress?>(
                        future: _volunteerProgress,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading volunteer progress…'),
                            );
                          }
                          final progress = snapshot.data;
                          if (snapshot.hasError || progress == null) {
                            return const ListTile(
                              title: Text('Volunteer progress unavailable'),
                            );
                          }
                          return VolunteerProgressCard(
                            progress: progress,
                            featuredBadge: _featuredBadge,
                            onBadgeSelected: (badge) =>
                                setState(() => _featuredBadge = badge),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Identity verification'),
                        subtitle: Text(switch (_service.isEmailConfirmed) {
                          true => 'Email confirmed. Government ID verification is unavailable.',
                          false => 'Email confirmation pending. Government ID verification is unavailable.',
                          null => 'Government ID verification is unavailable.',
                        }),
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
