import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';

import '../models/community_resource.dart';

class ResourceCard extends StatelessWidget {
  final CommunityResource resource;
  final VoidCallback onTap;
  final bool selected;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip(label: Text(resource.categoryLabel)),
              const SizedBox(height: 8),
              Text(resource.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(resource.address)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.of(context)
                    .publicVerifiedDate(resource.verificationDate),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.of(context).publicViewDetails,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
