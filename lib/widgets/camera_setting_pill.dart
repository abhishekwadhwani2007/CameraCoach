import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// Pill widget displaying a hardware camera setting (ISO, Shutter Speed, etc.).
class CameraSettingPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const CameraSettingPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.yellow, size: 20),
        const SizedBox(height: 6),
        Text(label, style: AppTextStyles.cameraLabel),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.cameraValue),
      ],
    );
  }
}
