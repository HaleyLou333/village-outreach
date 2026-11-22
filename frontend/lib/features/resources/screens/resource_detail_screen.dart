import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';

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
        _error = AppStrings.of(context).publicDetailsError;
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
        SnackBar(content: Text(AppStrings.of(context).publicLinkError)),
      );
    }
  }

  Future<void> _openWebsite(String value) async {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).publicInvalidWebsite)),
      );
      return;
    }

    await _openLink(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resource = _resource;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context).publicDetailsTitle)),
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
                        child: Text(AppStrings.of(context).retry),
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
                    title: Text(AppStrings.of(context).publicAddress),
                    subtitle: Text(resource.address),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.map_outlined),
                    title: Text(AppStrings.of(context).publicServiceArea),
                    subtitle: Text(resource.area),
                  ),
                  if (resource.phone != null &&
                      resource.phone!.trim().isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone),
                      title: Text(AppStrings.of(context).publicPhone),
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
                      title: Text(AppStrings.of(context).publicWebsite),
                      subtitle: Text(resource.website!),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openWebsite(resource.website!),
                    ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_outlined),
                    title: Text(AppStrings.of(context).publicLastVerified),
                    subtitle: Text(resource.verificationDate),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.source),
                    title: Text(AppStrings.of(context).publicInformationSource),
                    subtitle: Text(resource.sourceUrl),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openWebsite(resource.sourceUrl),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        AppStrings.of(context).publicDisclaimer,
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
