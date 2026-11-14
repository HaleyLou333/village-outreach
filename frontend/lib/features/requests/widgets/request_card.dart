import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/help_request.dart';

class RequestCard extends StatelessWidget {
  final HelpRequest request;
  final VoidCallback onTap;

  const RequestCard({super.key, required this.request, required this.onTap});

  IconData get _categoryIcon => switch (request.category) {
    'FOOD_ASSISTANCE' => Icons.shopping_basket_outlined,
    'TRANSPORTATION' => Icons.directions_car_outlined,
    'CHILDCARE' => Icons.child_care_outlined,
    'DONATED_ITEMS' => Icons.card_giftcard_outlined,
    'DELIVERY_HELP' => Icons.local_shipping_outlined,
    'LOCAL_SERVICES' => Icons.handyman_outlined,
    _ => Icons.volunteer_activism_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sandBeige,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_categoryIcon, color: AppColors.forestGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.forestGreen),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(request.categoryLabel)),
                  Chip(label: Text(request.distanceLabel)),
                  Chip(label: Text(request.urgencyLabel)),
                  Chip(label: Text(request.statusLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
