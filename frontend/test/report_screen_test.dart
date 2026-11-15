import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_outreach/features/reports/models/safety_report.dart';
import 'package:village_outreach/features/reports/models/report_receipt.dart';
import 'package:village_outreach/features/reports/screens/report_screen.dart';
import 'package:village_outreach/features/reports/services/report_service.dart';
import 'package:village_outreach/features/requests/services/request_service.dart';

const targetId = '4b79cf48-a7c2-4b97-9543-f4cef86ffc2f';

const receiptId = '95972aa0-2d05-4590-badf-7833215973ba';

class FakeReportRepository implements ReportRepository {
  final List<SafetyReport> reports = [];
  final List<String> keys = [];

  RequestApiException? failure;

  @override
  Future<ReportReceipt> submitReport(
    SafetyReport report, {
    required String idempotencyKey,
  }) async {
    reports.add(report);
    keys.add(idempotencyKey);

    if (failure != null) {
      throw failure!;
    }

    return const ReportReceipt(id: receiptId, status: 'pending');
  }
}

Future<void> openReport(
  WidgetTester tester,
  FakeReportRepository repository, {
  ReportTargetType targetType = ReportTargetType.request,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));

  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      home: ReportScreen(
        targetType: targetType,
        targetId: targetId,
        targetLabel: 'Test community request',
        repository: repository,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> selectReason(WidgetTester tester, String reason) async {
  final dropdown = find.byType(DropdownButtonFormField<ReportReason>);

  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(find.text(reason).last);
  await tester.pumpAndSettle();
}

Future<void> submitReport(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();

  await tester.pumpAndSettle();

  final button = find.text('Submit Report');

  await tester.scrollUntilVisible(
    button,
    150,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  expect(button.hitTestable(), findsOneWidget);

  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> enterDescription(WidgetTester tester, String description) async {
  final field = find.byType(TextField);

  await tester.ensureVisible(field);

  await tester.enterText(field, description);

  FocusManager.instance.primaryFocus?.unfocus();

  await tester.pumpAndSettle();
}

void main() {
  group('CCVO-70 Safety Reporting', () {
    testWidgets('Requires a reporting reason', (tester) async {
      final repository = FakeReportRepository();

      await openReport(tester, repository);
      await submitReport(tester);

      expect(
        find.text('Please select a reason for reporting.'),
        findsOneWidget,
      );

      expect(repository.reports, isEmpty);
    });

    testWidgets('Displays emergency service guidance', (tester) async {
      final repository = FakeReportRepository();

      await openReport(tester, repository);

      await tester.scrollUntilVisible(
        find.text('Immediate danger?'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('call 911'), findsOneWidget);
    });

    testWidgets('Submits a request report and shows receipt', (tester) async {
      final repository = FakeReportRepository();

      await openReport(tester, repository);

      await selectReason(tester, 'Spam');

      await enterDescription(tester, 'Test spam report.');

      await submitReport(tester);

      expect(repository.reports.length, 1);

      final report = repository.reports.single;

      expect(report.targetId, targetId);

      expect(report.targetType, ReportTargetType.request);

      expect(report.reason, ReportReason.spam);
      expect(report.description, 'Test spam report.');

      expect(find.text('Report Submitted'), findsOneWidget);

      expect(find.text(receiptId), findsOneWidget);

      expect(find.text('Pending review'), findsOneWidget);
    });

    testWidgets('Supports reporting another user', (tester) async {
      final repository = FakeReportRepository();

      await openReport(tester, repository, targetType: ReportTargetType.user);

      await selectReason(tester, 'Harassment');
      await submitReport(tester);

      expect(repository.reports.single.targetType, ReportTargetType.user);

      expect(repository.reports.single.reason, ReportReason.harassment);

      expect(find.text('Report Submitted'), findsOneWidget);
    });

    testWidgets('Failed submission preserves details and retry key', (
      tester,
    ) async {
      final repository = FakeReportRepository()
        ..failure = const RequestApiException(
          'Reporting is temporarily unavailable.',
          statusCode: 503,
        );

      await openReport(tester, repository);

      await selectReason(tester, 'Fraud');

      await enterDescription(tester, 'Preserve these details.');

      await submitReport(tester);

      expect(
        find.text('Reporting is temporarily unavailable.'),
        findsOneWidget,
      );

      expect(repository.reports.length, 1);

      final originalKey = repository.keys.first;

      final field = tester.widget<TextField>(find.byType(TextField));

      expect(field.controller!.text, 'Preserve these details.');

      repository.failure = null;

      await submitReport(tester);

      expect(repository.reports.length, 2);
      expect(repository.keys.last, originalKey);

      expect(repository.reports.last.reason, ReportReason.fraud);

      expect(repository.reports.last.description, 'Preserve these details.');

      expect(find.text('Report Submitted'), findsOneWidget);
    });

    testWidgets('Displays an invalid target error', (tester) async {
      final repository = FakeReportRepository()
        ..failure = const RequestApiException(
          'The report target could not be found.',
          statusCode: 404,
        );

      await openReport(tester, repository);
      await selectReason(tester, 'Other');
      await submitReport(tester);

      expect(
        find.text('The report target could not be found.'),
        findsOneWidget,
      );

      expect(find.text('Report Submitted'), findsNothing);
    });

    testWidgets('Displays an expired session error', (tester) async {
      final repository = FakeReportRepository()
        ..failure = const RequestApiException(
          'Your session expired. Please sign in again.',
          statusCode: 401,
        );

      await openReport(tester, repository);
      await selectReason(tester, 'Spam');
      await submitReport(tester);

      expect(
        find.text('Your session expired. Please sign in again.'),
        findsOneWidget,
      );

      expect(find.text('Report Submitted'), findsNothing);
    });
  });
}
