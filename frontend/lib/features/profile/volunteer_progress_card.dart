import 'package:flutter/material.dart';

import 'profile_service.dart';

class VolunteerProgressCard extends StatelessWidget {
  const VolunteerProgressCard({
    super.key,
    required this.progress,
    required this.featuredBadge,
    required this.onBadgeSelected,
  });

  final VolunteerProgress progress;
  final String? featuredBadge;
  final ValueChanged<String> onBadgeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final badges = progress.badgeLabels;
    final featured = badges.contains(featuredBadge)
        ? featuredBadge
        : badges.lastOrNull;
    final count = progress.completedHelpCount;
    final target = progress.nextTarget;
    final fraction = target == null ? 1.0 : (count / target).clamp(0.0, 1.0);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: Icon(
                      featured == null
                          ? Icons.volunteer_activism_outlined
                          : Icons.workspace_premium_outlined,
                      key: ValueKey(featured),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Volunteer level ${1 + badges.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(featured ?? 'Earn your first badge'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(count == 1 ? '1 request helped' : '$count requests helped'),
            if (target != null) ...[
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction),
                duration: duration,
                builder: (context, value, child) =>
                    LinearProgressIndicator(value: value),
              ),
              const SizedBox(height: 6),
              Text('Next badge: ${progress.nextLabel} ($count/$target)'),
            ],
            if (badges.length > 1) ...[
              const SizedBox(height: 12),
              const Text('Choose a badge to feature'),
              Wrap(
                spacing: 8,
                children: [
                  for (final badge in badges)
                    ChoiceChip(
                      label: Text(badge),
                      selected: badge == featured,
                      onSelected: (_) => onBadgeSelected(badge),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
