import 'dart:ui';
import 'package:flutter/material.dart';

enum DrawMode { brush, eraser }

/// Floating toolbar at the bottom of the overlay editor.
///
/// Sits *outside* the image area so it never covers what the user is editing.
/// Uses a blur + semi-transparent background to match the app's glass style.
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
            color: Colors.black.withValues(alpha: 0.55),
            border: const Border(
              top: BorderSide(color: Colors.white12, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — gives the user a visual affordance
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Main icon row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToolButton(
                    icon: Icons.brush,
                    label: 'Brush',
                    isActive: _mode == DrawMode.brush,
                    onTap: () => _switchMode(DrawMode.brush),
                  ),
                  _ToolButton(
                    icon: Icons.auto_fix_normal,
                    label: 'Erase',
                    isActive: _mode == DrawMode.eraser,
                    onTap: () => _switchMode(DrawMode.eraser),
                  ),
                  _ToolButton(
                    icon: Icons.undo,
                    label: 'Undo',
                    onTap: widget.onUndo,
                  ),
                  _ToolButton(
                    icon: Icons.redo,
                    label: 'Redo',
                    onTap: widget.onRedo,
                  ),
                  _ToolButton(
                    icon: Icons.refresh,
                    label: 'Reset',
                    onTap: widget.onReset,
                  ),
                  _ToolButton(
                    icon: Icons.check_circle_outline,
                    label: 'Done',
                    activeColor: const Color(0xFF34A853), // green = confirm
                    isActive: true,
                    onTap: widget.onDone,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Brush size row — only relevant when in brush or erase mode
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.white54),
                  Expanded(
                    child: Slider(
                      value: _brushSize,
                      min: 4,
                      max: 32,
                      divisions: 14,
                      activeColor: Colors.white70,
                      inactiveColor: Colors.white24,
                      onChanged: (v) {
                        setState(() => _brushSize = v);
                        widget.onBrushSizeChanged(v);
                      },
                    ),
                  ),
                  const Icon(Icons.circle, size: 18, color: Colors.white54),

                  // Live preview of the current brush size
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _brushSize,
                      height: _brushSize,
                      decoration: const BoxDecoration(
                        color: Colors.white54,
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
class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor = Colors.white,
  });

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
    final color = widget.isActive ? widget.activeColor : Colors.white38;
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
