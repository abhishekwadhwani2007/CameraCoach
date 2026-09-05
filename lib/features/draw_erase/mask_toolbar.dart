import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';

enum DrawMode { brush, eraser }

/// Toolbar for the overlay editor. Sits below the canvas so it never
/// occludes the editing area. Uses a blur backdrop for the glass effect.
class MaskToolbar extends StatefulWidget {
  final DrawMode initialMode;
  final double initialBrushSize;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onDone;
  final ValueChanged<DrawMode> onModeChanged;
  final ValueChanged<double> onBrushSizeChanged;

  const MaskToolbar({
    super.key,
    this.initialMode = DrawMode.brush,
    this.initialBrushSize = 12.0,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onDone,
    required this.onModeChanged,
    required this.onBrushSizeChanged,
  });

  @override
  State<MaskToolbar> createState() => _MaskToolbarState();
}

class _MaskToolbarState extends State<MaskToolbar> {
  late DrawMode _mode;
  late double _brushSize;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _brushSize = widget.initialBrushSize;
  }

  void _switchMode(DrawMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    widget.onModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        // The blur is what gives this the glass feel.
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            border: const Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — visual affordance
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.disabledText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Main icon row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Brush — custom SVG
                  _ToolButton(
                    svgAsset: 'assets/icons/brush.svg',
                    label: 'Brush',
                    isActive: _mode == DrawMode.brush,
                    onTap: () => _switchMode(DrawMode.brush),
                  ),
                  // Erase — custom SVG
                  _ToolButton(
                    svgAsset: 'assets/icons/erase.svg',
                    label: 'Erase',
                    isActive: _mode == DrawMode.eraser,
                    onTap: () => _switchMode(DrawMode.eraser),
                  ),
                  // Undo, Redo, Reset — Material icons (match perfectly)
                  _ToolButton(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    onTap: widget.onUndo,
                  ),
                  _ToolButton(
                    icon: Icons.redo_rounded,
                    label: 'Redo',
                    onTap: widget.onRedo,
                  ),
                  _ToolButton(
                    icon: Icons.refresh_rounded,
                    label: 'Reset',
                    onTap: widget.onReset,
                  ),
                  // Done — green confirmation
                  _ToolButton(
                    icon: Icons.check_circle_rounded,
                    label: 'Done',
                    activeColor: AppColors.green,
                    isActive: true,
                    onTap: widget.onDone,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Brush size row
              Row(
                children: [
                  const Icon(Icons.circle,
                      size: 8, color: AppColors.secondaryText),
                  Expanded(
                    child: Slider(
                      value: _brushSize,
                      min: 4,
                      max: 32,
                      divisions: 14,
                      activeColor: AppColors.silverMid,
                      inactiveColor: AppColors.border,
                      onChanged: (v) {
                        setState(() => _brushSize = v);
                        widget.onBrushSizeChanged(v);
                      },
                    ),
                  ),
                  const Icon(Icons.circle,
                      size: 18, color: AppColors.secondaryText),

                  // Live brush size preview dot
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _brushSize,
                      height: _brushSize,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryText,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single icon button in the toolbar.
/// Accepts either [icon] (Material) or [svgAsset] (custom SVG path).
class _ToolButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAsset;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToolButton({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor = AppColors.primaryText,
  }) : assert(icon != null || svgAsset != null,
            '_ToolButton requires either icon or svgAsset');

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _ctrl.reverse();
    _ctrl.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? widget.activeColor : AppColors.tertiaryText;
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.svgAsset != null)
              SvgPicture.asset(
                widget.svgAsset!,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
            else
              Icon(widget.icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontStyle: FontStyle.normal,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
