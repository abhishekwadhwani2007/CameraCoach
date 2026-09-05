import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/pose_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/photo_quality_analyzer.dart';
import '../../services/silhouette_generator.dart';
import '../../utils/logger.dart';
import '../../models/overlay_mask.dart';
import '../../services/mask_upload_service.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../draw_erase/editable_overlay_screen.dart';

class PoseConfirmationScreen extends StatefulWidget {
  final String imagePath;
  final String? overlayPath;

  const PoseConfirmationScreen({
    super.key,
    required this.imagePath,
    this.overlayPath,
  });

  @override
  State<PoseConfirmationScreen> createState() => _PoseConfirmationScreenState();
}

class _PoseConfirmationScreenState extends State<PoseConfirmationScreen> {
  bool _isProcessing = true;
  bool _isSaving = false;
  Map<String, dynamic>? _landmarks;
  String? _outlinePath;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    AppLogger.debug(
        'PoseConfirmationScreen: received overlayPath: ${widget.overlayPath != null ? "present" : "null"}');
    try {
      final file = File(widget.imagePath);
      final decodedImage = await decodeImageFromList(await file.readAsBytes());

      setState(() {
        _imageSize = Size(
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        );
      });

      final poses = await PoseService.detectPose(widget.imagePath);
      PoseService.dispose();
      if (poses.isNotEmpty) {
        final landmarks = PoseService.poseToMap(poses.first);
        final outline = widget.overlayPath ??
            await SilhouetteGenerator.generate(
              imagePath: widget.imagePath,
              landmarks: landmarks,
            );
        if (outline != null) {
          final provider = FileImage(File(outline));
          await provider.evict();
        }
        setState(() {
          _landmarks = landmarks;
          _outlinePath = outline;
        });
      }
    } catch (e) {
      AppLogger.error('Error processing pose image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveReference() async {
    if (_landmarks == null) return;

    setState(() => _isSaving = true);

    try {
      final proSettingsJson =
          await PhotoQualityAnalyzer.analyzeJson(widget.imagePath);

      AppLogger.debug(
          'PoseConfirmationScreen: saving with outlinePath: ${_outlinePath != null ? "present" : "null"}');
      await LocalStorageService.saveReference(
        originalImagePath: widget.imagePath,
        keypointsJson: jsonEncode(_landmarks),
        width: _imageSize!.width,
        height: _imageSize!.height,
        outlinePath: _outlinePath,
        proSettingsJson: proSettingsJson,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference saved — you\'re all set!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('Failed to save reference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Something went wrong saving that. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Opens the overlay editor. If the user saves a correction, we update
  // _outlinePath and fire off an upload in the background — the save flow
  // is completely unaffected either way.
  Future<void> _openOverlayEditor() async {
    if (_outlinePath == null) return;

    final result = await Navigator.push<OverlayMask>(
      context,
      MaterialPageRoute(
        builder: (_) => EditableOverlayScreen(
          imageFile: File(widget.imagePath),
          aiMaskFile: File(_outlinePath!),
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result.userEdited) {
      // Evict the old overlay from the image cache so the new one renders.
      await FileImage(File(_outlinePath!)).evict();
      setState(() => _outlinePath = result.maskFile.path);

      // Upload original + AI mask + corrected mask for model training.
      // Fire-and-forget — never blocks the user.
      MaskUploadService.uploadCorrection(
        originalImage: File(widget.imagePath),
        aiMask: File(result.aiMaskPath),
        correctedMask: result.maskFile,
        deviceId: 'device',
      );

      AppLogger.debug('PoseConfirmationScreen: overlay updated by user edit.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(color: AppColors.background),
          if (_imageSize != null)
            Positioned.fill(
              child: Transform.scale(
                scale: 1.2,
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.aiGlow.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!_isProcessing && _outlinePath != null)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_outlinePath!),
                              key: ValueKey(_outlinePath),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_isProcessing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryText),
                  SizedBox(height: 16),
                  Text(
                    'Finding your pose…',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          if (!_isProcessing && _landmarks == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Couldn\'t find a person in this photo.\n\nTry using a photo where someone is standing and visible from head to toe — the clearer the better! 🧍',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.primaryBody.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primaryText,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Silhouette',
                        style: AppTextStyles.pageTitle.copyWith(fontSize: 17),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: AppColors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    if (!_isProcessing && _outlinePath != null)
                      TextButton(
                        onPressed: _isSaving ? null : _openOverlayEditor,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Edit Overlay',
                          style: AppTextStyles.buttonSecondary,
                        ),
                      ),
                    if (!_isProcessing && _landmarks != null)
                      TextButton(
                        onPressed: _isSaving ? null : _saveReference,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryText,
                                ),
                              )
                            : Text(
                                'Save',
                                style: AppTextStyles.buttonSecondary.copyWith(
                                  color: AppColors.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
