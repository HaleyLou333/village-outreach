import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/help_request.dart';
import '../services/request_service.dart';

/// Temporary development areas until location selection is implemented.
class RequestArea {
  final String name;
  final double latitude;
  final double longitude;

  const RequestArea(this.name, this.latitude, this.longitude);
}

const requestAreas = [
  RequestArea('Central Phoenix', 33.4484, -112.0740),
  RequestArea('Downtown Tempe', 33.4255, -111.9400),
  RequestArea('Downtown Mesa', 33.4152, -111.8315),
];

const requestCategories = {
  'FOOD_ASSISTANCE': 'Food Assistance',
  'TRANSPORTATION': 'Transportation',
  'CHILDCARE': 'Childcare',
  'DONATED_ITEMS': 'Donated Items',
  'DELIVERY_HELP': 'Delivery Help',
  'LOCAL_SERVICES': 'Local Services',
};

class RequestFormScreen extends StatefulWidget {
  final HelpRequest? existingRequest;
  final RequestRepository? requestRepository;

  const RequestFormScreen({
    super.key,
    this.existingRequest,
    this.requestRepository,
  });

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late final RequestRepository _repository;
  late final bool _ownsRepository;

  String? _category;
  String _urgency = 'standard';
  RequestArea? _area;
  late final List<RequestArea> _availableAreas;

  bool _saving = false;
  String? _error;

  String? _pendingKey;
  Map<String, dynamic>? _pendingPayload;

  bool get _isEditing => widget.existingRequest != null;

  @override
  void initState() {
    super.initState();

    _ownsRepository = widget.requestRepository == null;
    _repository = widget.requestRepository ?? RequestService();

    final existing = widget.existingRequest;

    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description;
      _category = existing.category;
      _urgency = existing.urgency;

      _area = RequestArea(existing.area, existing.latitude, existing.longitude);
      _availableAreas = [
        _area!,
        ...requestAreas.where((area) => area.name != existing.area),
      ];
    } else {
      _availableAreas = [...requestAreas];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    if (_ownsRepository) {
      (_repository as RequestService).dispose();
    }

    super.dispose();
  }

  String? _validateText(String? value, String fieldName, int maxLength) {
    final trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return '$fieldName is required.';
    }

    if (trimmed.length > maxLength) {
      return '$fieldName must be $maxLength characters or fewer.';
    }

    if (trimmed.contains('\u0000') ||
        trimmed.runes.any((rune) => rune >= 0xD800 && rune <= 0xDFFF)) {
      return '$fieldName contains unsupported characters.';
    }

    return null;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category!,
      'urgency': _urgency,
      'area': _area!.name,
      'latitude': _area!.latitude,
      'longitude': _area!.longitude,
    };
  }

  void _onFormChanged() {
    if (_saving || _error == null) return;

    setState(() {
      _error = null;
    });
  }

  bool _payloadEquals(Map<String, dynamic> first, Map<String, dynamic> second) {
    if (first.length != second.length) return false;

    for (final key in first.keys) {
      if (first[key] != second[key]) return false;
    }

    return true;
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_category == null || _area == null) return;

    final payload = _buildPayload();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      late final HelpRequest result;

      if (_isEditing) {
        final original = widget.existingRequest!;
        final changes = <String, dynamic>{};

        if (payload['title'] != original.title) {
          changes['title'] = payload['title'];
        }

        if (payload['description'] != original.description) {
          changes['description'] = payload['description'];
        }

        if (payload['category'] != original.category) {
          changes['category'] = payload['category'];
        }

        if (payload['urgency'] != original.urgency) {
          changes['urgency'] = payload['urgency'];
        }

        // Only update coordinates if the selected area changed.
        // The backend returns rounded public coordinates, so
        // comparing them directly to preset coordinates can
        // produce unintended location updates.
        if (payload['area'] != original.area) {
          changes['area'] = payload['area'];
          changes['latitude'] = payload['latitude'];
          changes['longitude'] = payload['longitude'];
        }

        if (changes.isEmpty) {
          if (mounted) {
            Navigator.of(context).pop(original);
          }
          return;
        }

        result = await _repository.updateRequest(
          requestId: original.id,
          changes: changes,
        );
      } else {
        // Reuse the same key and payload for an identical retry.
        // A changed payload gets a new idempotency key.
        final sameSubmission =
            _pendingPayload != null &&
            _payloadEquals(_pendingPayload!, payload);

        if (!sameSubmission) {
          _pendingKey = const Uuid().v4();
          _pendingPayload = Map<String, dynamic>.from(payload);
        }

        result = await _repository.createRequest(
          data: _pendingPayload!,
          idempotencyKey: _pendingKey!,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(result);
    } on RequestApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to save the request. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Request' : 'Request Help';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Form(
          key: _formKey,
          onChanged: _onFormChanged,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _isEditing
                    ? 'Update your request details.'
                    : 'Tell your neighbors what help you need.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                enabled: !_saving,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Request title',
                  hintText: 'Need help picking up groceries',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateText(value, 'Title', 120),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                // Updated for current Flutter versions.
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: requestCategories.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _category = value);
                      },
                validator: (value) =>
                    value == null ? 'Select a category.' : null,
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLength: 4000,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the help you need...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => _validateText(value, 'Description', 4000),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                // Updated for current Flutter versions.
                initialValue: _urgency,
                decoration: const InputDecoration(
                  labelText: 'Urgency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(
                    value: 'time_sensitive',
                    child: Text('Time-sensitive'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _urgency = value);
                        }
                      },
              ),

              const SizedBox(height: 24),

              DropdownButtonFormField<RequestArea>(
                // Updated for current Flutter versions.
                initialValue: _area,
                decoration: const InputDecoration(
                  labelText: 'Area',
                  border: OutlineInputBorder(),
                ),
                items: _availableAreas
                    .map(
                      (area) =>
                          DropdownMenuItem(value: area, child: Text(area.name)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _area = value);
                      },
                validator: (value) => value == null ? 'Select an area.' : null,
              ),

              const SizedBox(height: 12),

              Text(
                'Your selected area is used to display your '
                'request to nearby neighbors.',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              if (_error != null) ...[
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _isEditing
                      ? 'Save Changes'
                      : 'Submit Request',
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
