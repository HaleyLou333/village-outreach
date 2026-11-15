import 'package:flutter_test/flutter_test.dart';

import 'package:village_outreach/features/reports/models/safety_report.dart';
import 'package:village_outreach/features/reports/models/report_receipt.dart';

void main() {
  const targetId = '4b79cf48-a7c2-4b97-9543-f4cef86ffc2f';

  group('CCVO-70 SafetyReport', () {
    test('serializes a request report', () {
      const report = SafetyReport(
        targetType: ReportTargetType.request,
        targetId: targetId,
        reason: ReportReason.unsafeContent,
        description: '  Unsafe request content.  ',
      );

      expect(report.toJson(), {
        'target_type': 'request',
        'target_id': targetId,
        'reason': 'unsafe_content',
        'description': 'Unsafe request content.',
      });
    });

    test('serializes a user report', () {
      const report = SafetyReport(
        targetType: ReportTargetType.user,
        targetId: targetId,
        reason: ReportReason.harassment,
      );

      expect(report.toJson()['target_type'], 'user');
      expect(report.toJson()['reason'], 'harassment');
    });

    test('omits an empty description', () {
      const report = SafetyReport(
        targetType: ReportTargetType.request,
        targetId: targetId,
        reason: ReportReason.spam,
        description: '   ',
      );

      expect(report.toJson().containsKey('description'), isFalse);
    });

    test('supports all backend report reasons', () {
      expect(ReportReason.values.map((r) => r.apiValue), [
        'spam',
        'harassment',
        'unsafe_content',
        'fraud',
        'other',
      ]);
    });
  });

  group('CCVO-70 ReportReceipt', () {
    test('parses a successful submission receipt', () {
      final receipt = ReportReceipt.fromJson({
        'id': targetId,
        'status': 'pending',
      });

      expect(receipt.id, targetId);
      expect(receipt.status, 'pending');
    });

    test('rejects an invalid receipt status', () {
      expect(
        () => ReportReceipt.fromJson({'id': targetId, 'status': 'invalid'}),
        throwsFormatException,
      );
    });

    test('rejects a missing receipt identifier', () {
      expect(
        () => ReportReceipt.fromJson({'status': 'pending'}),
        throwsFormatException,
      );
    });
  });
}
