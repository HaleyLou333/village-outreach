import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';

import 'package:url_launcher/url_launcher.dart';

import '../models/resource_guide.dart';
import '../services/resource_guide_service.dart';

class ResourceGuideScreen extends StatefulWidget {
  final ResourceGuideRepository? repository;
  const ResourceGuideScreen({super.key, this.repository});
  @override
  State<ResourceGuideScreen> createState() => _ResourceGuideScreenState();
}

class _ResourceGuideScreenState extends State<ResourceGuideScreen> {
  late final ResourceGuideRepository _repository;
  final _area = TextEditingController();
  final _category = TextEditingController();
  List<ResourceGuide> _guides = [];
  bool _loading = false;
  bool _hasMore = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ResourceGuideService();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guides = await _repository.list(
        area: _area.text.trim(),
        category: _category.text.trim().toLowerCase(),
        offset: more ? _guides.length : 0,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _guides = more ? [..._guides, ...guides] : guides;
        _hasMore = guides.length == 20;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = AppStrings.of(context).guideLoadError;
      });
    }
  }

  @override
  void dispose() {
    ++_generation;
    _area.dispose();
    _category.dispose();
    if (widget.repository == null) {
      (_repository as ResourceGuideService).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppStrings.of(context).guideBrowse)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _area,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).guideArea,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).guideCategory,
              hintText: AppStrings.of(context).guideCategoryHint,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : () => _load(),
            child: Text(AppStrings.of(context).guideSearch),
          ),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            OutlinedButton(
              onPressed: () => _load(),
              child: Text(AppStrings.of(context).guideRetry),
            ),
          ],
          if (!_loading && _error == null && _guides.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(AppStrings.of(context).guideEmpty),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.of(context).guideReturn),
            ),
          ],
          for (final guide in _guides)
            Card(
              child: ListTile(
                title: Text(guide.title),
                subtitle: Text(
                  '${guide.area} · ${guide.category} · ${AppStrings.of(context).guideReviewed} ${_date(guide.reviewedAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResourceGuideDetailScreen(
                      id: guide.id,
                      repository: _repository,
                    ),
                  ),
                ),
              ),
            ),
          if (_hasMore && !_loading)
            OutlinedButton(
              onPressed: () => _load(more: true),
              child: Text(AppStrings.of(context).guideLoadMore),
            ),
        ],
      ),
    ),
  );
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ResourceGuideDetailScreen extends StatefulWidget {
  final String id;
  final ResourceGuideRepository repository;
  const ResourceGuideDetailScreen({
    super.key,
    required this.id,
    required this.repository,
  });
  @override
  State<ResourceGuideDetailScreen> createState() =>
      _ResourceGuideDetailScreenState();
}

class _ResourceGuideDetailScreenState extends State<ResourceGuideDetailScreen> {
  late Future<ResourceGuide?> _future;

  // Convert repository failures into an explicit unavailable result.
  // This also prevents asynchronous failures from escaping the widget test zone.
  Future<ResourceGuide?> _fetchDetail() async {
    try {
      return await widget.repository.detail(widget.id);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _fetchDetail();
  }

  Future<void> _openSource(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      _showError();
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showError();
      }
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).guideOpenError)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppStrings.of(context).guideDetailTitle)),
    body: SafeArea(
      child: FutureBuilder<ResourceGuide?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppStrings.of(context).guideUnavailable),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _future = _fetchDetail();
                      }),
                      child: Text(AppStrings.of(context).guideRetry),
                    ),
                  ],
                ),
              ),
            );
          }
          final guide = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                guide.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('${guide.area} · ${guide.category}'),
              Text(
                '${AppStrings.of(context).guideSourceReviewed}: ${_date(guide.reviewedAt)}',
              ),
              const SizedBox(height: 20),
              SelectableText(guide.body ?? ''),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _openSource(guide.sourceUrl),
                icon: const Icon(Icons.open_in_new),
                label: Text(AppStrings.of(context).guideOpenSource),
              ),
            ],
          );
        },
      ),
    ),
  );
}
