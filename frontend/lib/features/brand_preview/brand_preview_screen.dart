import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_typography.dart';

class BrandPreviewScreen extends StatelessWidget {
  const BrandPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Village Outreach')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Image.asset(
                'assets/brand/logo.png',
                width: 94,
                height: 86,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Text(strings.brandLogoFailed);
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(strings.brandTagline, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),

            Text(strings.brandDescription, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.brandCommunitySupport,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.brandCommunityDescription,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {},
              child: Text(strings.brandRequestSupport),
            ),
            const SizedBox(height: 12),

            OutlinedButton(onPressed: () {}, child: Text(strings.offerHelp)),
            const SizedBox(height: 24),

            Text(strings.brandColors, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),

            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ColorSwatch(AppColors.forestGreen),
                _ColorSwatch(AppColors.sandBeige),
                _ColorSwatch(AppColors.clayOrange),
                _ColorSwatch(AppColors.skyBlue),
                _ColorSwatch(AppColors.softOlive),
                _ColorSwatch(AppColors.charcoal),
                _ColorSwatch(AppColors.offWhite),
                _ColorSwatch(AppColors.warmGray),
              ],
            ),
            const SizedBox(height: 24),

            Text('Village Outreach', style: AppTypography.brandTitle),
            const SizedBox(height: 8),

            Text(
              strings.brandClosingTagline,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;

  const _ColorSwatch(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warmGray),
      ),
    );
  }
}
