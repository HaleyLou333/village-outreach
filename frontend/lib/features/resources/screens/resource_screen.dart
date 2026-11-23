import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/community_resource.dart';
import '../services/location_service.dart';
import '../services/resource_service.dart';
import '../widgets/resource_card.dart';
import 'resource_detail_screen.dart';
import 'resource_guide_screen.dart';
import 'organization_resource_editor_screen.dart';
import '../services/organization_resource_service.dart';

class ResourceScreen extends StatefulWidget {
  final ResourceRepository? repository;
  final ResourceLocationRepository? locationRepository;

  const ResourceScreen({super.key, this.repository, this.locationRepository});

  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  final _areaController = TextEditingController(text: 'Oklahoma City Metro');

  late final ResourceRepository _repository;
  late final ResourceLocationRepository _locationRepository;
  late final bool _ownsRepository;

  GoogleMapController? _mapController;

  List<CommunityResource> _resources = [];
  CommunityResource? _selectedResource;

  bool _loading = true;
  bool _locating = false;
  bool _showMap = false;
  bool _hasMore = false;

  String? _error;
  String? _locationMessage;
  String? _mapError;

  String? _activeArea;
  double? _latitude;
  double? _longitude;

  int _generation = 0;
  late final Future<bool> _canManageOrganizations;

  Future<bool> _checkManagementAccess() async {
    OrganizationResourceService? service;
    try {
      service = OrganizationResourceService();
      return (await service.memberships()).any((m) => m.canManage);
    } catch (_) {
      return false;
    } finally {
      service?.dispose();
    }
  }

  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();

    _canManageOrganizations = _checkManagementAccess();
    _ownsRepository = widget.repository == null;

    _repository = widget.repository ?? ResourceService();

    _locationRepository = widget.locationRepository ?? LocationService();

    _activeArea = _areaController.text.trim();

    _loadResources();
  }

  Future<void> _loadResources({bool append = false}) async {
    final generation = ++_generation;

    setState(() {
      _loading = true;
      _error = null;

      if (!append) {
        _mapController = null;
        _mapError = null;
        _selectedResource = null;
        _resources = [];
        _hasMore = false;
      }
    });

    try {
      final results = await _repository.getResources(
        area: _activeArea,
        latitude: _latitude,
        longitude: _longitude,
        radiusKm: _latitude != null ? 10 : null,
        limit: _pageSize,
        offset: append ? _resources.length : 0,
      );

      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _resources = append ? [..._resources, ...results] : results;

        _hasMore = results.length == _pageSize;

        if (_resources.isNotEmpty) {
          _selectedResource ??= _resources.first;
        }

        _loading = false;
      });

      if (_showMap) {
        await _centerMap();
      }
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _loading = false;
        _error = AppStrings.of(context).publicLoadError;
      });
    }
  }

  Future<void> _searchByArea() async {
    final area = _areaController.text.trim();

    if (area.isEmpty || area.length > 100) {
      setState(() {
        _locationMessage = AppStrings.of(context).publicAreaInvalid;
      });
      return;
    }

    setState(() {
      _activeArea = area;
      _latitude = null;
      _longitude = null;
      _locationMessage = null;
    });

    await _loadResources();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });

    final result = await _locationRepository.getCurrentLocation();

    if (!mounted) return;

    setState(() {
      _locating = false;
      _locationMessage = result.message;
    });

    if (!result.isAvailable) return;

    setState(() {
      _activeArea = null;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });

    await _loadResources();
  }

  LatLng get _initialPosition {
    if (_selectedResource != null) {
      return LatLng(_selectedResource!.latitude, _selectedResource!.longitude);
    }

    if (_latitude != null && _longitude != null) {
      return LatLng(_latitude!, _longitude!);
    }

    return const LatLng(35.4676, -97.5164);
  }

  Set<Marker> get _markers {
    return _resources.map((resource) {
      final selected = resource.id == _selectedResource?.id;

      return Marker(
        markerId: MarkerId(resource.id),
        position: LatLng(resource.latitude, resource.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          selected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: resource.name,
          snippet: resource.categoryLabel,
          onTap: () => _openDetails(resource),
        ),
        onTap: () {
          setState(() {
            _selectedResource = resource;
          });
        },
      );
    }).toSet();
  }

  Future<void> _centerMap() async {
    final controller = _mapController;

    if (controller == null || !_showMap) return;

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_initialPosition, 12),
      );
    } catch (_) {
      if (!mounted || !_showMap || !identical(controller, _mapController)) {
        return;
      }

      setState(() {
        _mapError = AppStrings.of(context).publicMapError;
        _showMap = false;
        _mapController = null;
      });
    }
  }

  void _changeView(bool showMap) {
    setState(() {
      _showMap = showMap;
      _mapError = null;

      if (!showMap) {
        _mapController = null;
      }
    });
  }

  Future<void> _openDetails(CommunityResource resource) async {
    setState(() {
      _selectedResource = resource;
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResourceDetailScreen(resource: resource, repository: _repository),
      ),
    );
  }

  Widget _buildMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                if (!mounted || !_showMap) return;
                _mapController = controller;
              },
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _changeView(false),
          icon: const Icon(Icons.list),
          label: Text(AppStrings.of(context).publicMapFallback),
        ),
        if (_selectedResource != null)
          ResourceCard(
            resource: _selectedResource!,
            selected: true,
            onTap: () => _openDetails(_selectedResource!),
          ),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading && _resources.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _resources.isEmpty) {
      return Column(
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          FilledButton(
            onPressed: () => _loadResources(),
            child: Text(AppStrings.of(context).retry),
          ),
        ],
      );
    }

    if (_resources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context).publicEmpty,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).publicFound(_resources.length),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        if (_showMap)
          _buildMap()
        else
          for (final resource in _resources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ResourceCard(
                resource: resource,
                selected: resource.id == _selectedResource?.id,
                onTap: () => _openDetails(resource),
              ),
            ),

        if (_loading) const Center(child: CircularProgressIndicator()),

        if (_error != null) Text(_error!, textAlign: TextAlign.center),

        if (_hasMore && !_loading)
          OutlinedButton.icon(
            onPressed: () => _loadResources(append: true),
            icon: const Icon(Icons.expand_more),
            label: Text(AppStrings.of(context).publicLoadMore),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _generation++;
    _areaController.dispose();

    if (_ownsRepository) {
      (_repository as ResourceService).dispose();
    }

    // GoogleMap manages its platform controller lifecycle.
    _mapController = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).publicResourcesTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).guideBrowseTooltip,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ResourceGuideScreen(),
              ),
            ),
          ),
          FutureBuilder<bool>(
            future: _canManageOrganizations,
            builder: (context, snapshot) => snapshot.data == true
                ? IconButton(
                    tooltip: AppStrings.of(context)
                        .publicOrganizationManagement,
                    icon: const Icon(Icons.business),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const OrganizationResourceEditorScreen(),
                        ),
                      );
                      if (mounted) await _loadResources();
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadResources(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                AppStrings.of(context).publicResourcesHeading,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(AppStrings.of(context).publicResourcesIntro),
              const SizedBox(height: 20),

              TextField(
                controller: _areaController,
                enabled: !_loading && !_locating,
                maxLength: 100,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchByArea(),
                decoration: InputDecoration(
                  labelText: AppStrings.of(context).publicAreaLabel,
                  hintText: AppStrings.of(context).publicAreaHint,
                  counterText: '',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: AppStrings.of(context).publicSearchArea,
                    onPressed: _loading || _locating ? null : _searchByArea,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _loading || _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _locating
                      ? AppStrings.of(context).publicFindingLocation
                      : AppStrings.of(context).publicUseLocation,
                ),
              ),

              if (_locationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_locationMessage!),
                ),

              const SizedBox(height: 12),

              Text(
                _activeArea != null
                    ? AppStrings.of(context).publicShowingArea(_activeArea!)
                    : AppStrings.of(context).publicShowingNearby,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 16),

              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(AppStrings.of(context).publicMap),
                    icon: const Icon(Icons.map_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(AppStrings.of(context).publicList),
                    icon: const Icon(Icons.list),
                  ),
                ],
                selected: {_showMap},
                onSelectionChanged: (selection) {
                  _changeView(selection.first);
                },
              ),

              if (_mapError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_mapError!),
                ),

              const SizedBox(height: 20),

              _buildResults(),
            ],
          ),
        ),
      ),
    );
  }
}
