import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/core/localization/app_language.dart';
import 'package:village_outreach/features/reports/models/safety_report.dart';

void main() {
  test('safety reporting and receipt strings are localized', () {
    final en = AppStrings('en');
    final es = AppStrings('es');
    expect(en.reportSubmitTitle, 'Submit a Report');
    expect(es.reportSubmitTitle, 'Enviar un reporte');
    expect(en.reportPendingReview, 'Pending review');
    expect(es.reportPendingReview, 'Pendiente de revisión');
    expect(es.reportReasonLabel('harassment'), 'Acoso');
    expect(es.reportReferenceCopied, 'ID de referencia copiado.');
  });

  test('localized reason labels do not change API payload values', () {
    const report = SafetyReport(
      targetType: ReportTargetType.request,
      targetId: 'request-1',
      reason: ReportReason.unsafeContent,
    );
    expect(report.toJson()['reason'], 'unsafe_content');
    expect(report.toJson()['target_type'], 'request');
  });
}
