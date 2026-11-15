import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../requests/services/request_service.dart';
import '../models/safety_report.dart';
import '../services/report_service.dart';
import 'report_receipt_screen.dart';

class ReportScreen extends StatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  final String targetLabel;
  final ReportRepository? repository;

  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    this.repository,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();

  late final ReportRepository _repository;
  late final bool _ownsRepository;

  ReportReason? _reason;

  bool _submitting = false;
  String? _error;

  String? _idempotencyKey;
  String? _lastPayload;

  @override
  void initState() {
    super.initState();

    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? ReportService();
  }

  Future<void> _submitReport() async {
    if (_submitting) return;

    final reason = _reason;
    final description = _descriptionController.text.trim();

    if (reason == null) {
      setState(() {
        _error = 'Please select a reason for reporting.';
      });
      return;
    }

    if (description.length > 1000) {
      setState(() {
        _error =
            'Additional details cannot exceed '
            '1,000 characters.';
      });
      return;
    }

    final report = SafetyReport(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: reason,
      description: description,
    );

    final payload = jsonEncode(report.toJson());

    // Reuse the key when retrying an unchanged report.
    if (_lastPayload != payload || _idempotencyKey == null) {
      _idempotencyKey = const Uuid().v4();
      _lastPayload = payload;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final receipt = await _repository.submitReport(
        report,
        idempotencyKey: _idempotencyKey!,
      );

      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReportReceiptScreen(receipt: receipt),
        ),
      );
    } on RequestApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Unable to submit your report. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();

    if (_ownsRepository) {
      (_repository as ReportService).dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final targetTypeLabel = widget.targetType == ReportTargetType.request
        ? 'Request'
        : 'User';

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Submit a Report')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Help keep our community safe',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Use this form to report inappropriate '
                'behavior, unsafe content, or other '
                'community safety concerns.',
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text('Reporting $targetTypeLabel'),
                  subtitle: Text(widget.targetLabel),
                ),
              ),
              const SizedBox(height: 24),
              Text('Reason for reporting', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReportReason>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select a reason',
                  border: OutlineInputBorder(),
                ),
                items: ReportReason.values.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason.label),
                  );
                }).toList(),
                onChanged: _submitting
                    ? null
                    : (reason) {
                        setState(() {
                          _reason = reason;
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _descriptionController,
                enabled: !_submitting,
                maxLength: 1000,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  hintText: 'Describe your concern...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Immediate danger?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Village Outreach is not an '
                        'emergency response service. '
                        'If you or someone else is in '
                        'immediate danger, call 911.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submitReport,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined),
                label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
