import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// Reusable widget showing a permission row with status indicator and retry button.
class PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final PermissionStatus status;
  final VoidCallback? onRequest;

  const PermissionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onRequest,
  });

  Color get _statusColor {
    if (status.isGranted) return AppColors.success;
    if (status.isPermanentlyDenied) return AppColors.error;
    return AppColors.warning;
  }

  IconData get _statusIcon {
    if (status.isGranted) return Icons.check_circle_rounded;
    if (status.isPermanentlyDenied) return Icons.block_rounded;
    return Icons.radio_button_unchecked_rounded;
  }

  String get _statusLabel {
    if (status.isGranted) return 'Allowed ✓';
    if (status.isPermanentlyDenied) return 'Blocked — tap Settings to fix';
    return 'Not allowed yet';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.yellow, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.primaryBody.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.secondaryBody),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(_statusIcon, size: 14, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel,
                      style: AppTextStyles.secondaryBody.copyWith(
                        fontSize: 12,
                        color: _statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!status.isGranted && onRequest != null)
            TextButton(
              onPressed: status.isPermanentlyDenied
                  ? () => openAppSettings()
                  : onRequest,
              child: Text(
                status.isPermanentlyDenied ? 'Settings' : 'Allow',
                style: AppTextStyles.buttonSecondary.copyWith(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
