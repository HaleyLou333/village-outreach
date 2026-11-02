import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../requests/models/help_request.dart';
import '../requests/screens/request_detail_screen.dart';
import '../requests/services/request_service.dart';
import '../requests/widgets/request_card.dart';

class HomeScreen extends StatefulWidget {
  final RequestRepository? requestRepository;

  const HomeScreen({super.key, this.requestRepository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 20;

  // Temporary development coordinates.
  // These do not represent the user's actual location.
  static const double _latitude = 33.4484;
  static const double _longitude = -112.0740;

  late final RequestRepository _requestService;
  late final bool _ownsService;

  final List<HelpRequest> _requests = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  String? _error;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();

    _ownsService = widget.requestRepository == null;
    _requestService = widget.requestRepository ?? RequestService();

    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadMoreError = null;
    });

    try {
      final results = await _requestService.getNearbyRequests(
        latitude: _latitude,
        longitude: _longitude,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) return;

      setState(() {
        _requests
          ..clear()
          ..addAll(results);

        _hasMore = results.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final results = await _requestService.getNearbyRequests(
        latitude: _latitude,
        longitude: _longitude,
        limit: _pageSize,
        offset: _requests.length,
      );

      if (!mounted) return;

      setState(() {
        final existingIds = _requests.map((r) => r.id).toSet();

        _requests.addAll(results.where((r) => !existingIds.contains(r.id)));

        _hasMore = results.length == _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingMore = false;
        _loadMoreError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openRequest(HelpRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailScreen(
          requestId: request.id,
          distanceKm: request.distanceKm,
        ),
      ),
    );

    if (mounted) {
      await _loadRequests();
    }
  }

  // TEMPORARY DEBUG FEATURE:
  // Copies the current user's Supabase JWT to the clipboard.
  // Remove this method and the AppBar button after testing.
  Future<void> _copyDebugJwt() async {
    if (!kDebugMode) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null || session.accessToken.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active Supabase session. Please sign in first.'),
        ),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: session.accessToken));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Development access token copied to clipboard.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy access token.')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      // AuthGate redirects to the sign-in screen.
    } on AuthException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to sign out: ${error.message}')),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong while signing out. '
            'Please try again.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      (_requestService as RequestService).dispose();
    }

    super.dispose();
  }

  Widget _buildRequestFeed() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    if (_requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No active requests found nearby.\n'
            'Try another area or check back later.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final request in _requests) ...[
          RequestCard(request: request, onTap: () => _openRequest(request)),
          const SizedBox(height: 12),
        ],

        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),

        if (_loadMoreError != null) ...[
          Text(_loadMoreError!, textAlign: TextAlign.center),
          TextButton(
            onPressed: _loadMore,
            child: const Text('Retry loading more'),
          ),
        ],

        if (_hasMore && !_loadingMore && _loadMoreError == null)
          OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Load More'),
          ),
      ],
    );
  }

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
          // TEMPORARY: Visible only in debug builds.
          if (kDebugMode)
            IconButton(
              tooltip: 'Copy JWT for API testing',
              icon: const Icon(Icons.key_outlined),
              onPressed: _copyDebugJwt,
            ),

          IconButton(
            tooltip: 'Notifications - coming soon',
            onPressed: null,
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _signOut(context),
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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

              const Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      label: 'Request Help',
                      icon: Icons.volunteer_activism_outlined,
                      background: AppColors.forestGreen,
                      foreground: AppColors.white,
                    ),
                  ),
                  SizedBox(width: 12),
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
                'Live requests from your community',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('All categories')),
                  Chip(label: Text('Within 10 km')),
                ],
              ),

              const SizedBox(height: 16),
              _buildRequestFeed(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ProfileScreen(),
              ),
            );
          }
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
