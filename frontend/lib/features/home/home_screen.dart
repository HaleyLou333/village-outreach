import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../profile/profile_screen.dart';
import '../requests/models/help_request.dart';
import '../requests/screens/request_detail_screen.dart';
import '../requests/screens/request_form_screen.dart';
import '../requests/services/request_service.dart';
import '../requests/widgets/request_card.dart';
import '../resources/screens/resource_screen.dart';
import '../notifications/screens/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  final RequestRepository? requestRepository;

  const HomeScreen({super.key, this.requestRepository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 20;
  final _nearbySection = GlobalKey();

  RequestArea _searchArea = requestAreas.first;
  String? _category;
  String? _urgency;
  double _radiusKm = 10;
  int _nextOffset = 0;
  int _feedGeneration = 0;

  static const Map<String, String> _categories = {
    'FOOD_ASSISTANCE': 'Food Assistance',
    'TRANSPORTATION': 'Transportation',
    'CHILDCARE': 'Childcare',
    'DONATED_ITEMS': 'Donated Items',
    'DELIVERY_HELP': 'Delivery Help',
    'LOCAL_SERVICES': 'Local Services',
  };

  bool get _hasActiveFilters =>
      _searchArea != requestAreas.first ||
      _category != null ||
      _urgency != null ||
      _radiusKm != 10;

  void _resetFilters() {
    if (!_hasActiveFilters) return;
    setState(() {
      _searchArea = requestAreas.first;
      _category = null;
      _urgency = null;
      _radiusKm = 10;
    });
    _loadRequests();
  }

  void _changeCategory(String? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _loadRequests();
  }

  void _changeUrgency(String? urgency) {
    if (urgency == _urgency) return;
    setState(() => _urgency = urgency);
    _loadRequests();
  }

  void _changeRadius(double? radius) {
    if (radius == null || radius == _radiusKm) return;
    setState(() => _radiusKm = radius);
    _loadRequests();
  }

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

  /// Loads the first page of nearby requests.
  ///
  /// Also used for pull-to-refresh and after request creation.
  Future<void> _loadRequests({RequestArea? area}) async {
    final generation = ++_feedGeneration;
    final searchArea = area ?? _searchArea;
    setState(() {
      _searchArea = searchArea;
      _loading = true;
      _loadingMore = false;
      _error = null;
      _loadMoreError = null;
      _nextOffset = 0;
      _hasMore = true;
    });

    try {
      final results = await _requestService.getNearbyRequests(
        latitude: searchArea.latitude,
        longitude: searchArea.longitude,
        radiusKm: _radiusKm,
        category: _category,
        urgency: _urgency,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted || generation != _feedGeneration) return;

      setState(() {
        _requests
          ..clear()
          ..addAll(results);

        _nextOffset = results.length;
        _hasMore = results.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Loads additional nearby requests.
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _feedGeneration;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final results = await _requestService.getNearbyRequests(
        latitude: _searchArea.latitude,
        longitude: _searchArea.longitude,
        radiusKm: _radiusKm,
        category: _category,
        urgency: _urgency,
        limit: _pageSize,
        offset: _nextOffset,
      );

      if (!mounted || generation != _feedGeneration) return;

      setState(() {
        final existingIds = _requests.map((r) => r.id).toSet();

        _requests.addAll(results.where((r) => !existingIds.contains(r.id)));
        _nextOffset += results.length;

        _hasMore = results.length == _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;

      setState(() {
        _loadingMore = false;
        _loadMoreError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// CCVO-66: Opens the request creation form.
  ///
  /// Refreshes the nearby feed after a successful submission.
  Future<void> _openCreateRequest() async {
    final created = await Navigator.of(context).push<HelpRequest>(
      MaterialPageRoute<HelpRequest>(
        builder: (_) => RequestFormScreen(requestRepository: _requestService),
      ),
    );

    if (!mounted) return;

    if (created != null) {
      final area = requestAreas
          .where((area) => area.name == created.area)
          .firstOrNull;
      await _loadRequests(area: area);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).requestSubmitted)),
      );
    }
  }

  /// Opens request details and refreshes the feed on return.
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

  /// Signs out the authenticated user.
  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      // AuthGate redirects to the sign-in screen.
    } on AuthException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).signOutFailed(error.message)),
        ),
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

  /// Builds the nearby request feed.
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
            label: Text(AppStrings.of(context).retry),
          ),
        ],
      );
    }

    if (_requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Text(
                _hasActiveFilters
                    ? AppStrings.of(context).noFilteredRequests
                    : AppStrings.of(context).noNearbyRequests,
                textAlign: TextAlign.center,
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('empty-clear-filters'),
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(AppStrings.of(context).clearAllFilters),
                ),
              ],
            ],
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
            child: Text(AppStrings.of(context).retryLoadingMore),
          ),
        ],

        if (_hasMore && !_loadingMore && _loadMoreError == null)
          OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: Text(AppStrings.of(context).loadMore),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);

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
              semanticLabel: strings.brandLogoLabel,
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
            key: const Key('open-notifications'),
            tooltip: strings.notifications,
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),

          IconButton(
            tooltip: strings.signOut,
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
                strings.neighborsHelpingNeighbors,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(strings.homeIntro, style: textTheme.bodyLarge),
              const SizedBox(height: 24),

              // CCVO-66: Request Help is now interactive.
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      label: strings.requestHelp,
                      icon: Icons.volunteer_activism_outlined,
                      background: AppColors.forestGreen,
                      foreground: AppColors.white,
                      onTap: _openCreateRequest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      label: strings.offerHelp,
                      icon: Icons.handshake_outlined,
                      background: AppColors.sandBeige,
                      foreground: AppColors.charcoal,
                      onTap: () {
                        final section = _nearbySection.currentContext;
                        if (section != null) {
                          Scrollable.ensureVisible(
                            section,
                            duration: const Duration(milliseconds: 250),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                key: _nearbySection,
                children: [
                  Expanded(
                    child: Text(
                      strings.nearbyRequests,
                      style: textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: strings.refreshNearbyRequests,
                    onPressed: _loading ? null : _loadRequests,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(strings.liveCommunityRequests, style: textTheme.bodyMedium),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: strings.searchArea,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RequestArea>(
                    value: _searchArea,
                    isExpanded: true,
                    items: [
                      for (final area in requestAreas)
                        DropdownMenuItem(value: area, child: Text(area.name)),
                    ],
                    onChanged: (area) {
                      if (area != null && area != _searchArea) {
                        _loadRequests(area: area);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CCVO-76: Combined server-side request filters.
              DropdownButtonFormField<String?>(
                key: ValueKey('request-category-filter-$_category'),
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.categoryFilter,
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.allCategories),
                  ),
                  for (final entry in _categories.entries)
                    DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _changeCategory,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('request-urgency-filter-$_urgency'),
                initialValue: _urgency,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.urgencyFilter,
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.allUrgencyLevels),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'standard',
                    child: Text(strings.standard),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'time_sensitive',
                    child: Text(strings.timeSensitive),
                  ),
                ],
                onChanged: _changeUrgency,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                key: ValueKey('request-distance-filter-$_radiusKm'),
                initialValue: _radiusKm,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: strings.distanceFilter,
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 5.0,
                    child: Text(strings.withinKm(5)),
                  ),
                  DropdownMenuItem(
                    value: 10.0,
                    child: Text(strings.withinKm(10)),
                  ),
                  DropdownMenuItem(
                    value: 25.0,
                    child: Text(strings.withinKm(25)),
                  ),
                  DropdownMenuItem(
                    value: 50.0,
                    child: Text(strings.withinKm(50)),
                  ),
                  DropdownMenuItem(
                    value: 100.0,
                    child: Text(strings.withinKm(100)),
                  ),
                ],
                onChanged: _changeRadius,
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('clear-request-filters'),
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(strings.clearAll),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              _buildRequestFeed(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ResourceScreen()),
            );
          }

          if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            );
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: strings.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: strings.resources,
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            label: strings.help,
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            label: strings.events,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: strings.profile,
          ),
        ],
      ),
    );
  }
}

/// Reusable Home screen action card.
class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
      ),
    );
  }
}
