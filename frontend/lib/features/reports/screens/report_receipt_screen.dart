import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_language.dart';

import '../models/report_receipt.dart';

class ReportReceiptScreen extends StatelessWidget {
  final ReportReceipt receipt;

  const ReportReceiptScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.reportSubmittedTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              strings.reportThankYou,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(strings.reportReceived, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.reportReceiptHeading,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(strings.reportReferenceId),
                    SelectableText(receipt.id),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: receipt.id),
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.reportReferenceCopied),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(strings.reportCopyReference),
                    ),
                    const Divider(),
                    Text(strings.reportSubmissionStatus),
                    Chip(label: Text(strings.reportPendingReview)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(strings.reportPrivacyNote),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.reportDone),
            ),
          ],
        ),
      ),
    );
  }
}
