import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

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
    Color color = AppColors.secondaryText;
    if (isFail) {
      icon = Icons.cancel_outlined;
      color = AppColors.error;
    } else if (isPro) {
      icon = Icons.stars_rounded;
      color = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              style: AppTextStyles.primaryBody.copyWith(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
