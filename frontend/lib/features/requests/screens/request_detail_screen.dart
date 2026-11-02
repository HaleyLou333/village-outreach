import 'package:flutter/material.dart';

import '../models/help_request.dart';
import '../services/request_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final double? distanceKm;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    this.distanceKm,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late final RequestService _service;

  HelpRequest? _request;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RequestService();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getRequestDetail(widget.requestId);

      if (!mounted) return;

      setState(() {
        _request = result;
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

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadRequest,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _buildDetails(_request!),
    );
  }

  Widget _buildDetails(HelpRequest request) {
    final theme = Theme.of(context);

    final distanceLabel = widget.distanceKm == null
        ? 'Distance unavailable'
        : '${(widget.distanceKm! * 0.621371).toStringAsFixed(1)} mi away';

    return RefreshIndicator(
      onRefresh: _loadRequest,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(request.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(request.categoryLabel)),
              Chip(label: Text(request.urgencyLabel)),
              Chip(label: Text(request.statusLabel)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Description', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(request.description),
          const SizedBox(height: 24),
          Text('Location', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(request.area),
          Text(distanceLabel),
          const SizedBox(height: 24),
          Text('Status', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(request.statusLabel),
          if (request.isClosed) ...[
            const SizedBox(height: 16),
            const Text(
              'This request is closed and is no longer accepting help.',
            ),
          ],
          const SizedBox(height: 24),
          Text('Request ID', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText(request.id),
        ],
      ),
    );
  }
}
