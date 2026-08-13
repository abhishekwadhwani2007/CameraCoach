import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/overlay_mask.dart';
import '../../services/local_storage_service.dart';
import '../../utils/logger.dart';
import 'mask_toolbar.dart';

enum OverlayEditMode { brush, eraser }

class OverlayStroke {
  final List<Offset> points;
  final Path path;
  final double brushSize;
  final OverlayEditMode mode;

  OverlayStroke({
    required this.points,
    required this.path,
    required this.brushSize,
    required this.mode,
  });
}

/// Lets the user manually correct the AI-generated pose overlay before saving.
///
/// Displays the model-generated overlay directly on top of the reference photo.
/// - Brush mode adds white outline strokes.
/// - Eraser mode uses BlendMode.clear to erase the white overlay back to the
///   photo underneath (no black lines!).
class EditableOverlayScreen extends StatefulWidget {
  final File imageFile;
  final File aiMaskFile;

  const EditableOverlayScreen({
    super.key,
    required this.imageFile,
    required this.aiMaskFile,
  });

  @override
  State<EditableOverlayScreen> createState() => _EditableOverlayScreenState();
}

class _EditableOverlayScreenState extends State<EditableOverlayScreen> {
  static const _helpSeenKey = 'hasSeenOverlayEditHelp';

  OverlayEditMode _activeMode = OverlayEditMode.brush;
  double _brushSize = 14.0;
  bool _isSaving = false;
  bool _isLoading = true;

  ui.Image? _aiMaskUiImage;
  ui.Image? _photoUiImage;

  final List<OverlayStroke> _strokes = [];
  final List<OverlayStroke> _redoStack = [];

  List<Offset> _currentPoints = [];
  Path _currentPath = Path();

  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _maybeShowHelpDialog();
  }

  Future<void> _loadImages() async {
    try {
      final imgBytes = await widget.imageFile.readAsBytes();
      final maskBytes = await widget.aiMaskFile.readAsBytes();

      final codecImg = await ui.instantiateImageCodec(imgBytes);
      final frameImg = await codecImg.getNextFrame();

      final codecMask = await ui.instantiateImageCodec(maskBytes);
      final frameMask = await codecMask.getNextFrame();

      if (mounted) {
        setState(() {
          _photoUiImage = frameImg.image;
          _aiMaskUiImage = frameMask.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('EditableOverlayScreen: Error loading images: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _maybeShowHelpDialog() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_helpSeenKey) == true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Editing the overlay',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'The AI overlay is displayed over your photo.\n\n'
            '• Use Brush to add missing outline parts.\n'
            '• Use Eraser to wipe away unwanted outline areas.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      prefs.setBool(_helpSeenKey, true);
    });
  }

  void _onModeChanged(DrawMode mode) {
    setState(() {
      _activeMode = mode == DrawMode.brush
          ? OverlayEditMode.brush
          : OverlayEditMode.eraser;
    });
  }

  void _onBrushSizeChanged(double size) {
    setState(() {
      _brushSize = size;
    });
  }

  void _onUndo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStack.add(_strokes.removeLast());
      });
    }
  }

  void _onRedo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _strokes.add(_redoStack.removeLast());
      });
    }
  }

  void _onReset() {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset overlay edits?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'All your edits will be discarded.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _strokes.clear();
          _redoStack.clear();
        });
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    setState(() {
      _currentPoints = [pos];
      _currentPath = Path()..moveTo(pos.dx, pos.dy);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = details.localPosition;
    setState(() {
      _currentPoints.add(pos);
      _currentPath.lineTo(pos.dx, pos.dy);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPoints.isNotEmpty) {
      setState(() {
        _strokes.add(
          OverlayStroke(
            points: List.from(_currentPoints),
            path: Path.from(_currentPath),
            brushSize: _brushSize,
            mode: _activeMode,
          ),
        );
        _currentPoints.clear();
        _currentPath = Path();
        _redoStack.clear();
      });
    }
  }

  Future<void> _onDone() async {
    if (_strokes.isEmpty) {
      _popWithResult(
        OverlayMask(
          maskFile: widget.aiMaskFile,
          aiMaskPath: widget.aiMaskFile.path,
          userEdited: false,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final editedFile = await _exportFinalMask();
      _popWithResult(
        OverlayMask(
          maskFile: editedFile,
          aiMaskPath: widget.aiMaskFile.path,
          userEdited: true,
        ),
      );
    } catch (e) {
      AppLogger.error('EditableOverlayScreen: Failed to export final mask: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the edited mask. Please try again.'),
        ),
      );
    }
  }

  Future<File> _exportFinalMask() async {
    final width = _aiMaskUiImage!.width;
    final height = _aiMaskUiImage!.height;
    final scaleX = width / _canvasSize.width;
    final scaleY = height / _canvasSize.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Save isolated layer for mask rendering
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );

    // 1. Draw base AI mask
    canvas.drawImage(_aiMaskUiImage!, Offset.zero, Paint());

    // 2. Draw user strokes scaled to full image resolution
    for (final stroke in _strokes) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.brushSize * scaleX;

      if (stroke.mode == OverlayEditMode.brush) {
        paint.color = Colors.white;
        paint.style = PaintingStyle.stroke;
      } else {
        // Eraser mode: clear pixels from the mask layer
        paint.blendMode = BlendMode.clear;
        paint.style = PaintingStyle.stroke;
      }

      final scaledPath = stroke.path.transform(
        Matrix4.diagonal3Values(scaleX, scaleY, 1.0).storage,
      );

      if (stroke.points.length == 1) {
        paint.style = PaintingStyle.fill;
        final p = stroke.points.first;
        canvas.drawCircle(
          Offset(p.dx * scaleX, p.dy * scaleY),
          (stroke.brushSize * scaleX) / 2,
          paint,
        );
      } else {
        canvas.drawPath(scaledPath, paint);
      }
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final scopedPath = await LocalStorageService.getScopedTempPath();
    final outputFile = File(
      '$scopedPath/user_edited_mask_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await outputFile.writeAsBytes(pngBytes!.buffer.asUint8List(), flush: true);

    return outputFile;
  }

  void _popWithResult(OverlayMask result) {
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Overlay',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () => _popWithResult(
                      OverlayMask(
                        maskFile: widget.aiMaskFile,
                        aiMaskPath: widget.aiMaskFile.path,
                        userEdited: false,
                      ),
                    ),
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ],
      ),
      body: _isLoading || _aiMaskUiImage == null || _photoUiImage == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imgW = _photoUiImage!.width.toDouble();
                      final imgH = _photoUiImage!.height.toDouble();
                      final aspect = imgW / imgH;

                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight;

                      double canvasW, canvasH;
                      if (aspect > (maxW / maxH)) {
                        canvasW = maxW;
                        canvasH = maxW / aspect;
                      } else {
                        canvasH = maxH;
                        canvasW = maxH * aspect;
                      }

                      _canvasSize = Size(canvasW, canvasH);

                      OverlayStroke? activeStroke;
                      if (_currentPoints.isNotEmpty) {
                        activeStroke = OverlayStroke(
                          points: List.from(_currentPoints),
                          path: Path.from(_currentPath),
                          brushSize: _brushSize,
                          mode: _activeMode,
                        );
                      }

                      return Center(
                        child: SizedBox(
                          width: canvasW,
                          height: canvasH,
                          child: Stack(
                            children: [
                              // 1. Photo Background (Bottom Layer)
                              Positioned.fill(
                                child: RawImage(
                                  image: _photoUiImage,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              // 2. Interactive Overlay (Top Layer: AI Mask + Brush/Eraser)
                              Positioned.fill(
                                child: GestureDetector(
                                  onPanStart: _onPanStart,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: _onPanEnd,
                                  behavior: HitTestBehavior.opaque,
                                  child: CustomPaint(
                                    size: Size(canvasW, canvasH),
                                    painter: OverlayCanvasPainter(
                                      aiMaskImage: _aiMaskUiImage!,
                                      strokes: _strokes,
                                      currentStroke: activeStroke,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isSaving)
                                const Positioned.fill(
                                  child: ColoredBox(
                                    color: Colors.black54,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                MaskToolbar(
                  onModeChanged: _onModeChanged,
                  onBrushSizeChanged: _onBrushSizeChanged,
                  onUndo: _onUndo,
                  onRedo: _onRedo,
                  onReset: _onReset,
                  onDone: _onDone,
                ),
              ],
            ),
    );
  }
}

class OverlayCanvasPainter extends CustomPainter {
  final ui.Image aiMaskImage;
  final List<OverlayStroke> strokes;
  final OverlayStroke? currentStroke;

  OverlayCanvasPainter({
    required this.aiMaskImage,
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Isolated layer so BlendMode.clear only erases from the overlay layer,
    // revealing the photo underneath cleanly!
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final srcRect = Rect.fromLTWH(
      0,
      0,
      aiMaskImage.width.toDouble(),
      aiMaskImage.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(aiMaskImage, srcRect, dstRect, Paint());

    void drawStroke(OverlayStroke stroke) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.brushSize;

      if (stroke.mode == OverlayEditMode.brush) {
        paint.color = Colors.white.withValues(alpha: 0.9);
        paint.style = PaintingStyle.stroke;
      } else {
        // Eraser mode: clear pixels from the overlay layer!
        paint.blendMode = BlendMode.clear;
        paint.style = PaintingStyle.stroke;
      }

      if (stroke.points.length == 1) {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(stroke.points.first, stroke.brushSize / 2, paint);
      } else {
        canvas.drawPath(stroke.path, paint);
      }
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }

    if (currentStroke != null) {
      drawStroke(currentStroke!);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OverlayCanvasPainter oldDelegate) => true;
}


