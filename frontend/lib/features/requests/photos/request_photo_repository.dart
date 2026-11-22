import 'dart:typed_data';

/// Backend contract pending CCVO-79. Never expose private storage paths or
/// replace signed viewing URLs with public URLs.
class RequestPhoto {
  final String id;
  final String requestId;
  final String viewUrl;
  final DateTime expiresAt;
  const RequestPhoto({required this.id, required this.requestId,
    required this.viewUrl, required this.expiresAt});

  bool needsRefresh(DateTime now) =>
      !expiresAt.isAfter(now.add(const Duration(seconds: 30)));
}

class PhotoUploadException implements Exception {
  final String message;
  const PhotoUploadException(this.message);
  @override
  String toString() => message;
}

/// The backend team must provide these authenticated, owner-scoped operations.
/// The idempotency key MUST be reused for retries of the same image.
abstract class RequestPhotoRepository {
  Future<List<RequestPhoto>> list(String requestId);
  Future<RequestPhoto> upload({required String requestId,
    required Uint8List bytes, required String fileName,
    required String contentType, required String idempotencyKey,
    required void Function(double) onProgress});
  Future<RequestPhoto> refreshViewingUrl(String requestId, String photoId);
}

/// Safe default: unavailable until the CCVO-79 backend contract exists.
class UnavailableRequestPhotoRepository implements RequestPhotoRepository {
  const UnavailableRequestPhotoRepository();
  @override
  Future<List<RequestPhoto>> list(String requestId) async => const [];
  @override
  Future<RequestPhoto> upload({required String requestId,
    required Uint8List bytes, required String fileName,
    required String contentType, required String idempotencyKey,
    required void Function(double) onProgress}) async =>
      throw const PhotoUploadException(
        'Photo upload is not available until the request attachment API is connected.');
  @override
  Future<RequestPhoto> refreshViewingUrl(String requestId, String photoId) async =>
      throw const PhotoUploadException('Private photo viewing is not available yet.');
}
