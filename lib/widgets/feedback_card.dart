import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shows a single coaching tip or photo-quality note after a capture.
/// The `critique` string uses a prefix (FAIL:, PRO:, LIMIT:, INFO:) to
/// determine the icon and colour — the prefix is stripped before display.
class FeedbackCard extends StatelessWidget {
  final String critique;

  const FeedbackCard({
    super.key,
    required this.critique,
  });

  @override
  Widget build(BuildContext context) {
    final isFail = critique.startsWith('FAIL:');
    final isPro = critique.startsWith('PRO:');
    final cleanText = critique
        .replaceFirst('FAIL:', '')
        .replaceFirst('PRO:', '')
        .replaceFirst('LIMIT:', '')
        .replaceFirst('INFO:', '')
        .trim();

    IconData icon = Icons.info_outline_rounded;
    Color color = AppTheme.textSecondary;
    if (isFail) {
      icon = Icons.cancel_outlined;
      color = AppTheme.errorColor;
    } else if (isPro) {
      icon = Icons.stars_rounded;
      color = AppTheme.successColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cleanText,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
