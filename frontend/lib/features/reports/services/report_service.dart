import '../../requests/services/request_service.dart';
import '../models/report_receipt.dart';
import '../models/safety_report.dart';

abstract class ReportRepository {
  Future<ReportReceipt> submitReport(
    SafetyReport report, {
    required String idempotencyKey,
  });
}

class ReportService implements ReportRepository {
  final RequestService _transport;
  final bool _ownsTransport;

  ReportService({RequestService? transport})
    : _transport = transport ?? RequestService(),
      _ownsTransport = transport == null;

  @override
  Future<ReportReceipt> submitReport(
    SafetyReport report, {
    required String idempotencyKey,
  }) async {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    );

    if (!uuidPattern.hasMatch(report.targetId)) {
      throw const RequestApiException('The selected report target is invalid.');
    }

    if (idempotencyKey.trim().isEmpty) {
      throw const RequestApiException('A submission identifier is required.');
    }

    if ((report.description?.trim().length ?? 0) > 1000) {
      throw const RequestApiException(
        'Additional details cannot exceed '
        '1,000 characters.',
      );
    }

    try {
      final result = await _transport.requestJson(
        'POST',
        '/reports',
        operation: 'submit safety report',
        body: report.toJson(),
        idempotencyKey: idempotencyKey,
      );

      try {
        return ReportReceipt.fromJson(result as Map<String, dynamic>);
      } catch (_) {
        throw const RequestApiException(
          'The server returned an unexpected '
          'report receipt.',
        );
      }
    } on RequestApiException catch (error) {
      final message = switch (error.statusCode) {
        401 =>
          'Your session expired. '
              'Please sign in again.',
        403 =>
          'You cannot report this target, '
              'or your account does not have permission.',
        404 => 'The report target could not be found.',
        409 =>
          'This submission identifier was '
              'already used for different report details.',
        422 => 'Please review your report details.',
        503 =>
          'Reporting is temporarily unavailable. '
              'Please try again.',
        _ => error.message,
      };

      throw RequestApiException(message, statusCode: error.statusCode);
    }
  }

  void dispose() {
    if (_ownsTransport) {
      _transport.dispose();
    }
  }
}
