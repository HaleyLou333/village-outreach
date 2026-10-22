import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_NearbyRequest> _requests = [
    _NearbyRequest(
      title: 'Grocery Pickup',
      category: 'Errands',
      distance: '0.8 mi away',
      description: 'Looking for help picking up a few groceries.',
      urgency: 'Standard',
      icon: Icons.shopping_basket_outlined,
    ),
    _NearbyRequest(
      title: 'Ride to Appointment',
      category: 'Transportation',
      distance: '1.4 mi away',
      description: 'Could use a ride to a local appointment.',
      urgency: 'Time-sensitive',
      icon: Icons.directions_car_outlined,
    ),
    _NearbyRequest(
      title: 'Help With Yard Work',
      category: 'Household',
      distance: '2.1 mi away',
      description: 'Need help with some light yard work this weekend.',
      urgency: 'Standard',
      icon: Icons.yard_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/brand/logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              semanticLabel: 'Village Outreach logo',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Village Outreach',
                style: textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications - coming soon',
            onPressed: null,
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Neighbors helping neighbors',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Find local support or lend a helping hand.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    label: 'Request Help',
                    icon: Icons.volunteer_activism_outlined,
                    background: AppColors.forestGreen,
                    foreground: AppColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    label: 'Offer Help',
                    icon: Icons.handshake_outlined,
                    background: AppColors.sandBeige,
                    foreground: AppColors.charcoal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            Text('Nearby Requests', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Sample requests in your community',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Static filter placeholders.
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('All categories')),
                Chip(label: Text('Within 5 miles')),
              ],
            ),

            const SizedBox(height: 16),

            for (final request in _requests) ...[
              _RequestCard(request: request),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {
          // Navigation will be implemented in a future ticket.
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            label: 'Help',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _NearbyRequest {
  final String title;
  final String category;
  final String distance;
  final String description;
  final String urgency;
  final IconData icon;

  const _NearbyRequest({
    required this.title,
    required this.category,
    required this.distance,
    required this.description,
    required this.urgency,
    required this.icon,
  });
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _NearbyRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: AppColors.white,
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
                  child: Icon(request.icon, color: AppColors.forestGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.title,
                    style: textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(request.description, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: request.category),
                _InfoChip(label: request.distance),
                _InfoChip(label: request.urgency),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sandBeige,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
      ),
    );
  }
}
