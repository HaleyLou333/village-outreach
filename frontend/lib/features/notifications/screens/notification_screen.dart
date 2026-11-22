import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../../core/localization/app_language.dart';
import '../../requests/screens/request_detail_screen.dart';
import '../../requests/services/request_service.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    this.repository,
    this.onOpenRequest,
    this.checkRequestAccess,
    this.initialUserId,
    this.authUserChanges,
  });

  final NotificationRepository? repository;

  // Allows navigation to be verified in widget tests.
  final Future<void> Function(BuildContext context, String requestId)?
  onOpenRequest;

  // Allows request-access checks to be simulated in tests.
  final Future<void> Function(String requestId)? checkRequestAccess;

  // Optional authentication overrides for widget tests.
  final String? initialUserId;
  final Stream<String?>? authUserChanges;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const int _pageSize = 20;

  late final NotificationRepository _repository;
  late final bool _ownsRepository;

  StreamSubscription<String?>? _authSubscription;

  final List<AppNotification> _notifications = [];
  final Set<String> _processingIds = {};

  String? _currentUserId;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  String? _error;
  String? _loadMoreError;
  String? _actionError;

  // Invalidates requests started under previous sessions.
  int _generation = 0;

  // Tracks account changes independently from refreshes.
  int _accountGeneration = 0;

  @override
  void initState() {
    super.initState();

    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? NotificationService();

    if (widget.authUserChanges != null) {
      _currentUserId = widget.initialUserId;

      _authSubscription = widget.authUserChanges!.listen(_handleAuthUserChange);
    } else if (widget.repository != null) {
      // Existing repository-injected widget tests do not
      // require an initialized Supabase client.
      _currentUserId = widget.initialUserId ?? 'test-user';
    } else {
      final auth = AuthService();

      _currentUserId = auth.currentSession?.user.id;

      _authSubscription = auth.authChanges
          .map((state) => state.session?.user.id)
          .listen(_handleAuthUserChange);
    }

    if (_currentUserId != null) {
      _refresh();
    } else {
      _loading = false;
      _hasMore = false;
    }
  }

  void _handleAuthUserChange(String? nextUserId) {
    if (!mounted || nextUserId == _currentUserId) {
      return;
    }

    _currentUserId = nextUserId;

    // Invalidate all requests and actions from the old user.
    _generation++;
    _accountGeneration++;

    setState(() {
      _notifications.clear();
      _processingIds.clear();

      _loading = false;
      _loadingMore = false;
      _hasMore = false;

      _error = null;
      _loadMoreError = null;
      _actionError = null;
    });

    if (nextUserId != null) {
      _refresh();
    }
  }

  bool _isCurrentOperation(int generation, String? userId) {
    return mounted &&
        generation == _generation &&
        userId == _currentUserId &&
        userId != null;
  }

  bool _isCurrentAccount(int accountGeneration, String? userId) {
    return mounted &&
        accountGeneration == _accountGeneration &&
        userId == _currentUserId &&
        userId != null;
  }

  @override
  void dispose() {
    _generation++;
    _accountGeneration++;

    _authSubscription?.cancel();

    if (_ownsRepository) {
      (_repository as NotificationService).dispose();
    }

    super.dispose();
  }

  Future<void> _refresh() async {
    final userId = _currentUserId;

    if (userId == null) return;

    final generation = ++_generation;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;

      _error = null;
      _loadMoreError = null;
      _actionError = null;
    });

    try {
      final results = await _repository.getNotifications(
        limit: _pageSize,
        offset: 0,
      );

      if (!_isCurrentOperation(generation, userId)) {
        return;
      }

      setState(() {
        _notifications
          ..clear()
          ..addAll(results);

        _hasMore = results.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!_isCurrentOperation(generation, userId)) {
        return;
      }

      setState(() {
        _loading = false;
        _error = AppStrings.of(context).notificationsLoadFailed;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_currentUserId == null || _loading || _loadingMore || !_hasMore) {
      return;
    }

    final generation = _generation;
    final userId = _currentUserId;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final results = await _repository.getNotifications(
        limit: _pageSize,
        offset: _notifications.length,
      );

      if (!_isCurrentOperation(generation, userId)) {
        return;
      }

      setState(() {
        final existingIds = _notifications
            .map((notification) => notification.id)
            .toSet();

        _notifications.addAll(
          results.where(
            (notification) => !existingIds.contains(notification.id),
          ),
        );

        _hasMore = results.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!_isCurrentOperation(generation, userId)) {
        return;
      }

      setState(() {
        _loadingMore = false;
        _loadMoreError = AppStrings.of(context).notificationsMoreFailed;
      });
    }
  }

  Future<void> _checkRequestAccess(String requestId) async {
    if (widget.checkRequestAccess != null) {
      await widget.checkRequestAccess!(requestId);
      return;
    }

    // Existing widget tests can use their injected
    // navigation callback without a live API request.
    if (widget.onOpenRequest != null) return;

    final service = RequestService();

    try {
      await service.getRequestDetail(requestId);
    } finally {
      service.dispose();
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    final userId = _currentUserId;

    if (userId == null || _processingIds.contains(notification.id)) {
      return;
    }

    final accountGeneration = _accountGeneration;

    setState(() {
      _processingIds.add(notification.id);
      _actionError = null;
    });

    try {
      // Confirm the linked request is accessible.
      await _checkRequestAccess(notification.requestId);

      if (!_isCurrentAccount(accountGeneration, userId)) {
        return;
      }

      if (notification.isUnread) {
        // Persist the read state through the backend.
        await _repository.markAsRead(notification.id);

        if (!_isCurrentAccount(accountGeneration, userId)) {
          return;
        }

        // Refresh because unread/read changes backend sorting.
        await _refresh();

        if (!_isCurrentAccount(accountGeneration, userId) || _error != null) {
          return;
        }
      }

      // Capture the navigator after the asynchronous work,
      // with an explicit mounted-state guard.
      if (!mounted || !_isCurrentAccount(accountGeneration, userId)) {
        return;
      }

      if (widget.onOpenRequest != null) {
        await widget.onOpenRequest!(context, notification.requestId);
      } else {
        final navigator = Navigator.of(context);

        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                RequestDetailScreen(requestId: notification.requestId),
          ),
        );
      }

      if (!_isCurrentAccount(accountGeneration, userId)) {
        return;
      }

      await _refresh();
    } on RequestApiException catch (error) {
      if (!_isCurrentAccount(accountGeneration, userId)) {
        return;
      }

      setState(() {
        if (error.statusCode == 403 || error.statusCode == 404) {
          _actionError = AppStrings.of(context).notificationsUnavailable;
        } else if (error.statusCode == 401) {
          _actionError = AppStrings.of(context).notificationsSessionExpired;
        } else {
          _actionError = AppStrings.of(context).notificationsOpenFailed;
        }
      });
    } catch (_) {
      if (!_isCurrentAccount(accountGeneration, userId)) {
        return;
      }

      setState(() {
        _actionError =
            'Unable to open this notification. '
            'Please try again.';
      });
    } finally {
      if (_isCurrentAccount(accountGeneration, userId)) {
        setState(() {
          _processingIds.remove(notification.id);
        });
      }
    }
  }

  IconData _iconFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.offerReceived:
        return Icons.volunteer_activism_outlined;

      case AppNotificationType.offerAccepted:
        return Icons.handshake_outlined;

      case AppNotificationType.messageReceived:
        return Icons.chat_bubble_outline;
    }
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    final difference = DateTime.now().difference(local);

    if (difference.isNegative || difference.inMinutes < 1) {
      return AppStrings.of(context).notificationJustNow;
    }

    if (difference.inMinutes < 60) {
      return AppStrings.of(context)
          .notificationMinutesAgo(difference.inMinutes);
    }

    if (difference.inHours < 24) {
      return AppStrings.of(context).notificationHoursAgo(difference.inHours);
    }

    if (difference.inDays < 7) {
      return AppStrings.of(context).notificationDaysAgo(difference.inDays);
    }

    return '${local.month}/${local.day}/${local.year}';
  }

  String _notificationTitle(AppNotificationType type, AppStrings strings) {
    switch (type) {
      case AppNotificationType.offerReceived:
        return strings.notificationOfferReceived;
      case AppNotificationType.offerAccepted:
        return strings.notificationOfferAccepted;
      case AppNotificationType.messageReceived:
        return strings.notificationMessageReceived;
    }
  }

  String _notificationDescription(
    AppNotificationType type,
    AppStrings strings,
  ) {
    switch (type) {
      case AppNotificationType.offerReceived:
        return strings.notificationOfferReceivedDetail;
      case AppNotificationType.offerAccepted:
        return strings.notificationOfferAcceptedDetail;
      case AppNotificationType.messageReceived:
        return strings.notificationMessageReceivedDetail;
    }
  }

  Widget _buildNotification(AppNotification notification) {
    final theme = Theme.of(context);

    final isProcessing = _processingIds.contains(notification.id);

    return Card(
      key: Key('notification-${notification.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          _iconFor(notification.type),
          size: 28,
          color: theme.colorScheme.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _notificationTitle(notification.type, AppStrings.of(context)),
                style: TextStyle(
                  fontWeight: notification.isUnread
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (notification.isUnread)
              Container(
                key: Key('unread-${notification.id}'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _notificationDescription(
                  notification.type,
                  AppStrings.of(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _timeLabel(notification.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        enabled: !isProcessing,
        onTap: isProcessing ? null : () => _openNotification(notification),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentUserId == null) {
      return Center(child: Text(AppStrings.of(context).notificationsSignIn));
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.of(context).notificationsRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.notifications_none_outlined, size: 56),
            const SizedBox(height: 16),
            Center(
              child: Text(
                AppStrings.of(context).notificationsEmpty,
                style: TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppStrings.of(context).notificationsEmptyHint,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_actionError != null) ...[
            Text(
              _actionError!,
              key: const Key('notification-action-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          for (final notification in _notifications)
            _buildNotification(notification),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_loadMoreError != null) ...[
            Text(_loadMoreError!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _loadMore,
              child: Text(AppStrings.of(context).notificationsRetryMore),
            ),
          ],
          if (_hasMore && !_loadingMore && _loadMoreError == null)
            OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(AppStrings.of(context).notificationsLoadMore),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).notificationsTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).refreshNotifications,
            onPressed: _loading || _currentUserId == null ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildContent(),
    );
  }
}
