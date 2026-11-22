import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_resource.dart';
import '../services/resource_service.dart';

class ResourceDetailScreen extends StatefulWidget {
  final CommunityResource resource;
  final ResourceRepository repository;

  const ResourceDetailScreen({
    super.key,
    required this.resource,
    required this.repository,
  });

  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  CommunityResource? _resource;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resource = await widget.repository.getResourceDetail(
        widget.resource.id,
      );

      if (!mounted) return;

      setState(() {
        _resource = resource;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Resource details could not be loaded. '
            'Please try again.';
      });
    }
  }

  Future<void> _openLink(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        throw Exception('Unable to open link');
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link.')),
      );
    }
  }

  Future<void> _openWebsite(String value) async {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid website address.')));
      return;
    }

    await _openLink(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resource = _resource;

    return Scaffold(
      appBar: AppBar(title: const Text('Resource Details')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(resource!.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text(resource.categoryLabel)),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Address'),
                    subtitle: Text(resource.address),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.map_outlined),
                    title: const Text('Service area'),
                    subtitle: Text(resource.area),
                  ),
                  if (resource.phone != null &&
                      resource.phone!.trim().isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone'),
                      subtitle: Text(resource.phone!),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () =>
                          _openLink(Uri(scheme: 'tel', path: resource.phone!)),
                    ),
                  if (resource.website != null &&
                      resource.website!.trim().isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language),
                      title: const Text('Website'),
                      subtitle: Text(resource.website!),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openWebsite(resource.website!),
                    ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Last verified'),
                    subtitle: Text(resource.verificationDate),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.source),
                    title: const Text('Information source'),
                    subtitle: Text(resource.sourceUrl),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openWebsite(resource.sourceUrl),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Resource information may change. '
                        'Please contact the organization '
                        'directly to confirm availability, '
                        'hours, and eligibility.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
