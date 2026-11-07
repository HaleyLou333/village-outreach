import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/profile_service.dart';
import '../../offers/screens/request_offers_screen.dart';
import '../../offers/services/offer_service.dart';
import '../../messaging/services/message_service.dart';
import '../models/help_request.dart';
import '../services/request_service.dart';
import 'request_form_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final double? distanceKm;

  // Optional dependencies for automated testing.
  final RequestRepository? requestRepository;
  final ProfileService? profileService;
  final OfferRepository? offerRepository;
  final MessageRepository? messageRepository;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    this.distanceKm,
    this.requestRepository,
    this.profileService,
    this.offerRepository,
    this.messageRepository,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

// Shared only for development demos. Real offers require the backend API.
final MockOfferRepository _developmentOfferRepository = MockOfferRepository();
// Demo-only, shared between visits; never used as a production message store.
final MockMessageRepository _developmentMessageRepository =
    MockMessageRepository();

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late final RequestRepository _repository;
  late final bool _ownsRepository;

  late final ProfileService _profileService;
  late final bool _ownsProfileService;

  HelpRequest? _request;

  bool _loading = true;
  bool _updating = false;
  bool _loadingProfile = true;

  String? _error;
  String? _actionError;
  String? _profileError;

  // Internal FastAPI application user ID.
  String? _applicationUserId;

  String? get _supabaseUserId {
    // Unit/widget tests may not initialize Supabase.
    // Ownership is determined by _applicationUserId instead.
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool _isOwner(HelpRequest request) {
    return _applicationUserId != null &&
        request.requesterId == _applicationUserId;
  }

  bool _canManage(HelpRequest request) {
    return _isOwner(request) && request.isActive;
  }

  String _diagnostics(HelpRequest request) {
    final isOwner = _isOwner(request);
    final isActive = request.isActive;

    return [
      '========== REQUEST OWNERSHIP ==========',
      'Supabase user ID: ${_supabaseUserId ?? "NULL"}',
      'Application user ID: ${_applicationUserId ?? "NULL"}',
      'Request owner ID: ${request.requesterId}',
      'Request ID: ${request.id}',
      'Request status: ${request.status}',
      'Profile loading: $_loadingProfile',
      'Profile error: ${_profileError ?? "None"}',
      'Is owner: $isOwner',
      'Is active: $isActive',
      'Can manage: ${isOwner && isActive}',
      '=======================================',
    ].join('\n');
  }

  void _logOwnership(HelpRequest request) {
    if (!kDebugMode) return;

    debugPrint(_diagnostics(request));
  }

  Future<void> _copyDiagnostics(HelpRequest request) async {
    await Clipboard.setData(ClipboardData(text: _diagnostics(request)));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ownership diagnostics copied.')),
    );
  }

  @override
  void initState() {
    super.initState();

    // Request repository:
    // Use the injected fake during tests, or the real API service.
    _ownsRepository = widget.requestRepository == null;
    _repository = widget.requestRepository ?? RequestService();

    // Profile service:
    // Use the injected fake during tests, or GET /users/me.
    _ownsProfileService = widget.profileService == null;
    _profileService = widget.profileService ?? ProfileService();

    _loadProfile();
    _loadRequest();
  }

  /// Retrieves the internal application user ID from FastAPI.
  ///
  /// Supabase authentication IDs and internal application user IDs
  /// are different UUIDs. Request ownership uses the internal ID.
  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _loadingProfile = true;
      _profileError = null;
      _applicationUserId = null;
    });

    try {
      final profile = await _profileService.getProfile();

      if (!mounted) return;

      setState(() {
        _applicationUserId = profile.id;
        _loadingProfile = false;
      });

      if (kDebugMode) {
        debugPrint('Application profile loaded: ${profile.id}');
      }

      final request = _request;

      if (request != null) {
        _logOwnership(request);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
        _profileError = error.toString();
        _applicationUserId = null;
      });

      if (kDebugMode) {
        debugPrint('Profile loading failed: $error');
      }
    }
  }

  /// Retrieves the latest request details.
  Future<void> _loadRequest() async {
    if (_updating) return;

    setState(() {
      _loading = true;
      _error = null;
      _actionError = null;
    });

    try {
      final result = await _repository.getRequestDetail(widget.requestId);

      if (!mounted) return;

      setState(() {
        _request = result;
        _loading = false;
      });

      _logOwnership(result);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openOffers() async {
    final request = _request;
    final currentUserId = _applicationUserId;
    if (!kDebugMode ||
        request == null ||
        currentUserId == null ||
        _loadingProfile ||
        _updating) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RequestOffersScreen(
          requestId: request.id,
          requestOwnerId: request.requesterId,
          currentUserId: currentUserId,
          repository: widget.offerRepository ?? _developmentOfferRepository,
          messageRepository:
              widget.messageRepository ?? _developmentMessageRepository,
          isClosed: request.isClosed,
        ),
      ),
    );
    if (!mounted) return;
    await _loadRequest();
  }

  /// Opens the request form with the existing request information.
  Future<void> _editRequest() async {
    final request = _request;

    if (request == null || !_canManage(request) || _updating) {
      return;
    }

    final updated = await Navigator.of(context).push<HelpRequest>(
      MaterialPageRoute<HelpRequest>(
        builder: (_) => RequestFormScreen(
          existingRequest: request,
          requestRepository: _repository,
        ),
      ),
    );

    if (!mounted) return;

    if (updated != null) {
      setState(() {
        _request = updated;
        _actionError = null;
      });

      _logOwnership(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request updated successfully.')),
      );

      await _loadRequest();
    }
  }

  /// Displays a confirmation before completing or canceling.
  Future<void> _confirmStatusChange({
    required String status,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final request = _request;

    if (request == null || !_canManage(request) || _updating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    final current = _request;

    if (current == null ||
        current.id != request.id ||
        !_canManage(current) ||
        _updating) {
      return;
    }

    await _changeStatus(status);
  }

  /// Sends PATCH /requests/{request_id} with the new status.
  Future<void> _changeStatus(String status) async {
    final request = _request;

    if (request == null || !_canManage(request) || _updating) {
      return;
    }

    setState(() {
      _updating = true;
      _actionError = null;
    });

    try {
      final updated = await _repository.updateRequest(
        requestId: request.id,
        changes: {'status': status},
      );

      if (!mounted) return;

      setState(() {
        _request = updated;
      });

      _logOwnership(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'completed'
                ? 'Request marked as completed.'
                : 'Request canceled successfully.',
          ),
        ),
      );
    } on RequestApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _actionError = error.message;
      });

      if (error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 409) {
        await _loadLatestAfterActionError();
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _actionError = 'Unable to update this request. Please try again.';
      });

      if (kDebugMode) {
        debugPrint('Request status update failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  /// Refreshes request state after an API conflict or rejection.
  Future<void> _loadLatestAfterActionError() async {
    try {
      final latest = await _repository.getRequestDetail(widget.requestId);

      if (!mounted) return;

      setState(() {
        _request = latest;
      });

      _logOwnership(latest);
    } catch (_) {
      // Preserve the original action error.
    }
  }

  @override
  void dispose() {
    // Dispose only services created by this screen.
    // Injected services remain owned by the caller/test.
    if (_ownsProfileService) {
      _profileService.dispose();
    }

    if (_ownsRepository) {
      (_repository as RequestService).dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_updating,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Request Details'),
          actions: [
            IconButton(
              tooltip: 'Refresh request',
              onPressed: _updating
                  ? null
                  : () async {
                      await Future.wait([_loadProfile(), _loadRequest()]);
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _request == null
            ? const Center(child: Text('Request not found.'))
            : _buildDetails(_request!),
      ),
    );
  }

  Widget _buildError() {
    return Center(
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
              onPressed: () async {
                await Future.wait([_loadProfile(), _loadRequest()]);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(HelpRequest request) {
    final theme = Theme.of(context);

    final isOwner = _isOwner(request);
    final canManage = _canManage(request);

    final distanceLabel = widget.distanceKm == null
        ? 'Distance unavailable'
        : '${(widget.distanceKm! * 0.621371).toStringAsFixed(1)} mi away';

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadProfile(), _loadRequest()]);
      },
      child: ListView(
        // Reset the scrollable when the request changes status.
        // Owner controls disappear on completion/cancellation, which can
        // otherwise cause viewport offset correction loops in widget tests.
        key: ValueKey('request-details-${request.id}-${request.status}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // Request title.
          Text(request.title, style: theme.textTheme.headlineMedium),

          const SizedBox(height: 16),

          // Request category, urgency, and status.
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

          // Description.
          Text('Description', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(request.description),

          const SizedBox(height: 24),

          // Location.
          Text('Location', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(request.area),
          Text(distanceLabel),

          const SizedBox(height: 24),

          // Status.
          Text('Status', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(request.statusLabel),

          if (request.isClosed) ...[
            const SizedBox(height: 16),
            const Text(
              'This request is closed and is no longer '
              'accepting help.',
            ),
          ],

          // Mock offers are only accessible in debug builds.
          // Never present locally stored demo offers as real submissions.
          if (kDebugMode &&
              _applicationUserId != null &&
              !_loadingProfile &&
              _profileError == null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text('Helper Offers (Demo)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Development preview only. Offers are stored in memory '
              'and are not sent to the server.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('open-offers-demo'),
              onPressed: _updating ? null : _openOffers,
              icon: Icon(
                isOwner ? Icons.people_outline : Icons.volunteer_activism,
              ),
              label: Text(
                request.isClosed
                    ? (isOwner
                          ? 'Review Offers & Messages (Demo)'
                          : 'View Offer & Messages (Demo)')
                    : (isOwner
                          ? 'Review Offers (Demo)'
                          : 'Offer to Help (Demo)'),
              ),
            ),
          ],

          // Owner-only management controls.
          if (canManage) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            Text('Manage Your Request', style: theme.textTheme.titleLarge),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _updating ? null : _editRequest,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Request'),
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: _updating
                  ? null
                  : () => _confirmStatusChange(
                      status: 'completed',
                      title: 'Mark Request Completed?',
                      message:
                          'Are you sure you want to mark this '
                          'request as completed? You will not '
                          'be able to edit it afterward.',
                      confirmLabel: 'Mark Completed',
                    ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark Completed'),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _updating
                  ? null
                  : () => _confirmStatusChange(
                      status: 'canceled',
                      title: 'Cancel Request?',
                      message:
                          'Are you sure you want to cancel this '
                          'request? This action cannot be undone.',
                      confirmLabel: 'Cancel Request',
                    ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Request'),
            ),
          ],

          // Wait for GET /users/me before determining ownership.
          if (_loadingProfile) ...[
            const SizedBox(height: 24),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Checking request ownership...'),
                ],
              ),
            ),
          ],

          // Ownership verification failure.
          if (_profileError != null) ...[
            const SizedBox(height: 24),

            Text(
              'Unable to verify request ownership: '
              '$_profileError',
              style: TextStyle(color: theme.colorScheme.error),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _loadingProfile ? null : _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Ownership Check'),
            ),
          ],

          // Request update progress.
          if (_updating) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],

          // Request update error.
          if (_actionError != null) ...[
            const SizedBox(height: 20),

            Text(
              _actionError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],

          // Closed owner request notice.
          if (isOwner && request.isClosed) ...[
            const SizedBox(height: 24),

            Text(
              'You can no longer edit or change the '
              'status of this request.',
              style: theme.textTheme.bodyMedium,
            ),
          ],

          const SizedBox(height: 32),

          // Debug-only ownership information.
          if (kDebugMode) ...[
            _buildDebugPanel(request),
            const SizedBox(height: 24),
          ],

          // Request identifier.
          Text('Request ID', style: theme.textTheme.titleLarge),

          const SizedBox(height: 8),

          SelectableText(request.id),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDebugPanel(HelpRequest request) {
    final theme = Theme.of(context);

    final isOwner = _isOwner(request);
    final isActive = request.isActive;
    final canManage = _canManage(request);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_outlined),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Ownership Debug',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SelectableText(
            _diagnostics(request),
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 12),

          Text(
            canManage
                ? 'RESULT: Management controls should be visible.'
                : 'RESULT: Management controls are hidden.',
            style: TextStyle(
              color: canManage ? Colors.green : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Owner match: $isOwner | Active: $isActive',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () => _copyDiagnostics(request),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy Diagnostics'),
          ),
        ],
      ),
    );
  }
}
