import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../requests/services/request_service.dart';

class MemberCard {
  const MemberCard(this.name, this.completed, this.badges, this.photo);

  final String name;
  final int completed;
  final List<String> badges;
  final Uint8List? photo;

  static Future<MemberCard> load(
    RequestService api,
    String requestId,
    String memberId,
  ) async {
    final data = await api.requestJson(
      'GET',
      '/requests/${Uri.encodeComponent(requestId)}/members/${Uri.encodeComponent(memberId)}',
      operation: 'view this member',
    ) as Map<String, dynamic>;
    final photo = data['photo'] as String?;
    return MemberCard(
      data['display_name'] as String,
      data['completed_help_count'] as int,
      (data['badges'] as List<dynamic>).cast<String>(),
      photo == null ? null : base64Decode(photo),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.photo,
    this.badgeCount = 0,
    this.radius = 22,
  });

  final String name;
  final Uint8List? photo;
  final int badgeCount;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ring = switch (badgeCount) {
      0 => colors.outlineVariant,
      1 => colors.secondary,
      2 => colors.primary,
      _ => colors.tertiary,
    };
    final initials = name.trim().characters.firstOrNull?.toUpperCase() ?? '?';
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: badgeCount == 0 ? 1 : 3),
          ),
          child: CircleAvatar(
            radius: radius,
            foregroundImage: photo == null ? null : MemoryImage(photo!),
            onForegroundImageError: photo == null ? null : (_, _) {},
            child: Text(initials),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: radius * .34,
              backgroundColor: ring,
              foregroundColor: badgeCount == 1
                  ? colors.onSecondary
                  : badgeCount == 2
                  ? colors.onPrimary
                  : colors.onTertiary,
              child: Icon(Icons.workspace_premium, size: radius * .47),
            ),
          ),
      ],
    );
  }
}

Future<void> showMemberCard(BuildContext context, Future<MemberCard> member) {
  final result = member.then<MemberCard?>(
    (card) => card,
    onError: (Object _) => null,
  );
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      semanticLabel: 'Member profile',
      scrollable: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      content: SizedBox(
        width: 300,
        child: FutureBuilder<MemberCard?>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final card = snapshot.data;
            if (card == null) return const Text('Member profile unavailable.');
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberAvatar(
                  name: card.name,
                  photo: card.photo,
                  radius: 42,
                  badgeCount: card.badges.length,
                ),
                const SizedBox(height: 12),
                Text(
                  card.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  card.completed == 1
                      ? '1 request helped'
                      : '${card.completed} requests helped',
                  textAlign: TextAlign.center,
                ),
                if (card.badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final badge in card.badges)
                        Chip(
                          avatar: const Icon(Icons.workspace_premium_outlined),
                          label: Text(badge),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}
