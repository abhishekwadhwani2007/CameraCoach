import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_text_styles.dart';
import 'camera_ui_colors.dart';
import 'manual_controls_panel.dart';

class BottomBar extends StatelessWidget {
  final int selectedModeIndex;
  final ValueChanged<int> onModeChanged;
  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final bool capturing;
  final VoidCallback onFlip;
  final AnimationController flipAnim;
  final double bottomSafeAreaPadding;
  final double matchScore;
  final String guidance;
  final String iso;
  final String shutter;
  final String wb;
  final double ev;
  final String manualFocusValue;

  const BottomBar({
    super.key,
    required this.selectedModeIndex,
    required this.onModeChanged,
    required this.zoom,
    required this.onZoomChanged,
    required this.onCapture,
    required this.capturing,
    required this.onFlip,
    required this.flipAnim,
    required this.bottomSafeAreaPadding,
    required this.matchScore,
    required this.guidance,
    required this.iso,
    required this.shutter,
    required this.wb,
    required this.ev,
    required this.manualFocusValue,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(bottom: bottomSafeAreaPadding + 4, top: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedModeIndex == 1) ...[
              ManualControlsRow(
                iso: iso,
                shutter: shutter,
                wb: wb,
                ev: ev,
                mf: manualFocusValue,
              ),
              const SizedBox(height: 6),
            ],
            ZoomSelector(
              currentZoom: zoom,
              onZoomChanged: onZoomChanged,
              matchScore: matchScore,
              guidance: guidance,
            ),
            const SizedBox(height: 6),
            ModeTabs(selected: selectedModeIndex, onSelect: onModeChanged),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Gallery button ─────────────────────────────────────
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cameraBorderColor, width: 1),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/gallery_footer.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          AppColors.secondaryText,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  // ── Shutter button ─────────────────────────────────────
                  ShutterBtn(
                      onTap: onCapture,
                      busy: capturing,
                      matchScore: matchScore),

                  // ── Flip camera button ─────────────────────────────────
                  AnimatedBuilder(
                    animation: flipAnim,
                    builder: (_, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(flipAnim.value * math.pi),
                      child: child,
                    ),
                    child: GestureDetector(
                      onTap: onFlip,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: cameraBorderColor, width: 1),
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_outlined,
                          color: AppColors.secondaryText,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class ZoomSelector extends StatelessWidget {
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final double matchScore;
  final String guidance;

  const ZoomSelector({
    super.key,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.matchScore,
    required this.guidance,
  });

  @override
  Widget build(BuildContext context) {
    final presets = [1.0, 2.0, 4.0];
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: presets.map((z) {
            final active = (currentZoom - z).abs() < 0.15;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onZoomChanged(z);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.lightSurface : AppColors.surface,
                  border: Border.all(
                    color: active ? cameraAccentGold : cameraBorderColor,
                    width: active ? 1.5 : 1.0,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: cameraAccentGold.withValues(alpha: 0.18),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${z.toInt()}x',
                  style: AppTextStyles.cameraLabel.copyWith(
                    color: active ? cameraAccentGold : AppColors.tertiaryText,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        Positioned(
          left: 28,
          child: IgnorePointer(
            child: Text(
              'Match: ${matchScore.toInt()}%',
              style: AppTextStyles.cameraLabel,
            ),
          ),
        ),
        if (guidance != 'Hold it right there' && matchScore < 95)
          Positioned(
            right: 28,
            child: IgnorePointer(
              child: SizedBox(
                width: 150,
                child: Text(
                  guidance,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.secondaryBody,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ModeTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  static const _modes = ['PHOTO', 'PRO', 'VIDEO'];

  const ModeTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_modes.length, (i) {
          final on = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _modes[i],
                    style: AppTextStyles.modeTab.copyWith(
                      color: on ? cameraAccentGold : AppColors.tertiaryText,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: on ? 22 : 0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: cameraAccentGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
}

class ShutterBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool busy;
  final double matchScore;

  const ShutterBtn({
    super.key,
    required this.onTap,
    required this.busy,
    required this.matchScore,
  });

  @override
  State<ShutterBtn> createState() => _ShutterBtnState();
}

class _ShutterBtnState extends State<ShutterBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressAnimController;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressAnimController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        lowerBound: 0.88,
        upperBound: 1.0,
        value: 1.0);
    _pressScale = _pressAnimController;
  }

  @override
  void dispose() {
    _pressAnimController.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    if (widget.busy) {
      return; // Ignore taps while a capture is already in flight.
    }
    await _pressAnimController.reverse();
    await _pressAnimController.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _press,
        child: ScaleTransition(
          scale: _pressScale,
          child: SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer silver ring
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.silverMid,
                      width: 2.5,
                    ),
                  ),
                ),
                // Inner silver gradient fill
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.silverTop,
                        AppColors.silverMid,
                        AppColors.silverBot,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.silverMid,
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: widget.busy
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                              color: AppColors.background, strokeWidth: 2),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
}
