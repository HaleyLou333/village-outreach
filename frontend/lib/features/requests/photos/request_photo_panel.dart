import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'request_photo_repository.dart';
import '../../../core/localization/app_language.dart';

/// Injectable picker makes denied permission and invalid files testable.
abstract class RequestPhotoPicker {
  Future<XFile?> pick();
}

class DeviceRequestPhotoPicker implements RequestPhotoPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<XFile?> pick() => _picker.pickImage(source: ImageSource.gallery);
}

class RequestPhotoPanel extends StatefulWidget {
  final String requestId;
  final RequestPhotoRepository? repository;
  final RequestPhotoPicker? picker;

  const RequestPhotoPanel({
    super.key,
    required this.requestId,
    this.repository,
    this.picker,
  });

  @override
  State<RequestPhotoPanel> createState() => _RequestPhotoPanelState();
}

class _RequestPhotoPanelState extends State<RequestPhotoPanel> {
  // Provisional client-side ceiling; replace with backend-advertised limits.
  static const maxBytes = 5 * 1024 * 1024;

  late final RequestPhotoRepository _repository =
      widget.repository ?? const UnavailableRequestPhotoRepository();

  late final RequestPhotoPicker _picker =
      widget.picker ?? DeviceRequestPhotoPicker();

  Uint8List? _bytes;
  String? _name;
  String? _type;
  String? _operationKey;
  String? _error;
  bool _busy = false;
  double _progress = 0;
  RequestPhoto? _uploaded;

  String? validateFile(String name, int size) {
    final lower = name.toLowerCase();

    if (!(lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp'))) {
      return AppStrings.of(context).photoInvalidFormat;
    }

    if (size == 0 || size > maxBytes) {
      return AppStrings.of(context).photoInvalidSize;
    }

    return null;
  }

  Future<void> _select() async {
    if (_busy) return;

    try {
      final selected = await _picker.pick();

      if (selected == null || !mounted) return;

      final bytes = await selected.readAsBytes();

      if (!mounted) return;

      final problem = validateFile(selected.name, bytes.length);

      if (problem != null) {
        setState(() => _error = problem);
        return; // Retain the prior valid selection.
      }

      final name = selected.name.toLowerCase();

      setState(() {
        _bytes = bytes;
        _name = selected.name;
        _type = name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
        _operationKey = const Uuid().v4();
        _uploaded = null;
        _progress = 0;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _error = AppStrings.of(context).photoPermissionError);
    }
  }

  Future<void> _upload() async {
    if (_busy || _bytes == null || _operationKey == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });

    try {
      final result = await _repository.upload(
        requestId: widget.requestId,
        bytes: _bytes!,
        fileName: _name!,
        contentType: _type!,
        idempotencyKey: _operationKey!,
        onProgress: (value) {
          if (mounted) {
            setState(() => _progress = value.clamp(0, 1));
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _uploaded = result;
        _progress = 1;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = AppStrings.of(context).photoErrorMessage(error));

      // Preserve bytes and key for a safe retry. Text request stays usable.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshUrl() async {
    final photo = _uploaded;

    if (photo == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final fresh = await _repository.refreshViewingUrl(
        widget.requestId,
        photo.id,
      );

      if (mounted) {
        setState(() => _uploaded = fresh);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = AppStrings.of(context).photoErrorMessage(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final photo = _uploaded;
    final hasValidUrl = photo != null && !photo.needsRefresh(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.requestPhotos,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(strings.photoOptionalHint),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _select,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(strings.choosePhoto),
            ),
            if (_bytes != null) ...[
              const SizedBox(height: 8),
              Image.memory(
                _bytes!,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Text(strings.photoPreviewUnavailable),
              ),
              Text(_name ?? strings.selectedPhoto),
              if (_busy) LinearProgressIndicator(value: _progress),
              if (photo == null)
                FilledButton(
                  onPressed: _busy ? null : _upload,
                  child: Text(
                    _error == null
                        ? strings.uploadPhoto
                        : strings.retryPhotoUpload,
                  ),
                ),
            ],
            if (photo != null) ...[
              Text(strings.photoUploaded),
              if (hasValidUrl)
                Image.network(
                  photo.viewUrl,
                  height: 140,
                  errorBuilder: (context, error, stackTrace) => TextButton(
                    onPressed: _busy ? null : _refreshUrl,
                    child: Text(strings.refreshPrivatePhotoLink),
                  ),
                )
              else
                TextButton(
                  onPressed: _busy ? null : _refreshUrl,
                  child: Text(strings.refreshExpiredPhotoLink),
                ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
