import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../review/pose_confirmation_screen.dart';
import '../live_session/live_coaching_screen.dart';
import '../../services/local_storage_service.dart';
import '../../services/backend_api_service.dart';
import '../../models/reference_model.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../utils/logger.dart';

/// Home screen — where the user picks a reference photo or jumps straight
/// into coaching if they already have one saved.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickReferencePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    const allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
    final ext = image.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains('.$ext')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only JPEG, PNG, or WebP images are supported — please pick one of those.'),
        ),
      );
      return;
    }

    const maxBytes = 10 * 1024 * 1024; // 10 MB
    final fileSize = await File(image.path).length();
    if (!mounted) return;
    if (fileSize > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That image is a bit too large. Please use a photo under 10 MB.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Flexible(
              child: Text('Hang tight — building your pose guide…'),
            ),
          ],
        ),
      ),
    );

    AppLogger.debug('Sending image to API: ${image.path}');
    final overlayPath = await BackendApiService.generateOverlay(image.path);
    AppLogger.debug('generateOverlay returned: ${overlayPath != null ? 'path' : 'null'}');

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoseConfirmationScreen(
          imagePath: image.path,
          overlayPath: overlayPath,
        ),
      ),
    );
  }

  Future<void> _startCoaching() async {
    final status = await Permission.camera.status;

    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (result.isPermanentlyDenied) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Camera access needed'),
            content: const Text(
              'CameraCoach needs your camera to guide you in real time. '
              'You can turn it on in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        return;
      }
      if (!result.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera access is needed to start coaching.')),
        );
        return;
      }
    }

    final refMap = await LocalStorageService.getSessionReference();

    if (mounted) {
      if (refMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You\'ll need a reference photo first — tap Upload Reference to pick one.')),
        );
        _pickReferencePhoto();
        return;
      }

      final reference = ReferenceModel.fromMap(refMap);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveCoachScreen(reference: reference),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // No AppBar — full dark immersive screen per reference design
      body: Stack(
        children: [
          // ── Background: camera lens image at low opacity ──────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/home_bg.png',
              fit: BoxFit.cover,
              color: AppColors.background.withValues(alpha: 0.88),
              colorBlendMode: BlendMode.srcOver,
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Header card ─────────────────────────────────────────
                  _buildHeaderCard(),

                  const SizedBox(height: 48),

                  // ── Upload Reference button ──────────────────────────────
                  _buildUploadReferenceButton(),

                  const SizedBox(height: 16),

                  // ── Start Coaching button (silver gradient) ──────────────
                  _buildStartCoachingButton(),

                  const SizedBox(height: 40),

                  // ── Tip caption ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 13,
                        color: AppColors.tertiaryText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tip: Use a bright room for best AI accuracy',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dark glass header card with metallic logo halfway out of the box
  Widget _buildHeaderCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // The card background
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 105), // Drops card top to logo's exact midpoint
          padding: const EdgeInsets.fromLTRB(28, 100, 28, 36), // Keeps bottom text gap identical
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'CameraCoach AI',
                style: AppTextStyles.mainTitle,
              ),
              const SizedBox(height: 12),
              Text(
                'Ready to capture perfection?',
                style: AppTextStyles.primaryBody.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        // Metallic CameraCoach logo floating out
        Positioned(
          top: 15, // Pushed slightly down
          child: Image.asset(
            'assets/images/logo.png',
            width: 180, // Enlarged
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  /// Dark pill button — Upload Reference
  Widget _buildUploadReferenceButton() {
    return GestureDetector(
      onTap: _pickReferencePhoto,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
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
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/gallery_add.svg',
                  width: 22,
                  height: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Reference',
                    style: AppTextStyles.primaryBody.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pick your target pose from gallery',
                    style: AppTextStyles.secondaryBody,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.tertiaryText,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Silver gradient pill button — Start Coaching
  Widget _buildStartCoachingButton() {
    return GestureDetector(
      onTap: _startCoaching,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.silverTop, AppColors.silverMid, AppColors.silverBot],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.silverMid.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dark circle with play icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/play_circle.svg',
                  width: 22,
                  height: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Coaching',
                    style: AppTextStyles.primaryBody.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: AppColors.background,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Match your pose in real-time',
                    style: AppTextStyles.secondaryBody.copyWith(
                      color: AppColors.background.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.background.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
