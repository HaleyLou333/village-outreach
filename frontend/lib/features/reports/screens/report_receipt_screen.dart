import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/report_receipt.dart';

class ReportReceiptScreen extends StatelessWidget {
  final ReportReceipt receipt;

  const ReportReceiptScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Submitted'),
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
              'Thank you for speaking up',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your report has been received. '
              'Thank you for helping keep our '
              'community safe.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submission receipt',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    const Text('Reference ID'),
                    SelectableText(receipt.id),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: receipt.id),
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reference ID copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy reference'),
                    ),
                    const Divider(),
                    const Text('Submission status'),
                    const Chip(label: Text('Pending review')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'For privacy and safety, moderation '
              'records and actions are not displayed '
              'in the application.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
