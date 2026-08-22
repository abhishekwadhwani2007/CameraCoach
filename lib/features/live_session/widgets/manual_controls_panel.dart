import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_text_styles.dart';

/// Compact row showing live camera settings (ISO, Shutter, WB, EV, MF) in PRO mode.
/// Rendered at the top of the bottom bar by [BottomBar].
class ManualControlsRow extends StatelessWidget {
  final String iso;
  final String shutter;
  final String wb;
  final double ev;
  final String mf;

  const ManualControlsRow({
    super.key,
    required this.iso,
    required this.shutter,
    required this.wb,
    required this.ev,
    required this.mf,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ISO', iso),
      ('SS', shutter),
      ('WB', wb),
      ('EV', ev >= 0 ? '+${ev.toStringAsFixed(1)}' : ev.toStringAsFixed(1)),
      ('MF', mf),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map(
            (item) => Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightSurface,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.$1,
                    style: AppTextStyles.cameraLabel.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cameraValue.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
