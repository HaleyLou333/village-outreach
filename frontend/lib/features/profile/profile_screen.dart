
import 'package:flutter/material.dart';

import 'profile_service.dart';
import 'user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  final TextEditingController _nameController = TextEditingController();

  UserProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || name.length > 100) {
      setState(() {
        _error = 'Display name must be between 1 and 100 characters.';
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

      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _loading || _saving ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 42,
                      child: Icon(Icons.person_outline, size: 44),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (profile == null) ...[
                    const Text('Unable to load your profile.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Try Again'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _nameController,
                      enabled: _editing && !_saving,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: profile.email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Account Role'),
                      subtitle: Text(profile.role),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Account Status'),
                      subtitle: Text(profile.status),
                    ),
                    const SizedBox(height: 24),
                    if (_editing)
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
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
                        onPressed: () {
                          setState(() {
                            _editing = true;
                            _error = null;
                          });
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Profile'),
                      ),
                    if (_editing)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _editing = false;
                                  _error = null;
                                  _nameController.text = profile.displayName;
                                });
                              },
                        child: const Text('Cancel'),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
