import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../home/home_screen.dart';
import '../../widgets/permission_tile.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Map<String, PermissionStatus> _permissionStatuses = {
    'camera': PermissionStatus.denied,
    'storage': PermissionStatus.denied,
    'sensors': PermissionStatus.denied,
  };

  bool get _allPermissionsGranted =>
      _permissionStatuses['camera']!.isGranted &&
      _permissionStatuses['storage']!.isGranted;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentPermissions() async {
    final camera = await Permission.camera.status;
    final storage = await _getStoragePermission().status;
    setState(() {
      _permissionStatuses['camera'] = camera;
      _permissionStatuses['storage'] = storage;
      _permissionStatuses['sensors'] = PermissionStatus.granted;
    });
  }

  Permission _getStoragePermission() {
    return Permission.photos;
  }

  Future<void> _requestAllPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await _getStoragePermission().request();

    setState(() {
      _permissionStatuses['camera'] = cameraStatus;
      _permissionStatuses['storage'] = storageStatus;
      _permissionStatuses['sensors'] = PermissionStatus.granted;
    });
  }

  Future<void> _requestSinglePermission(String key) async {
    PermissionStatus status;
    if (key == 'camera') {
      status = await Permission.camera.request();
    } else if (key == 'storage') {
      status = await _getStoragePermission().request();
    } else {
      status = PermissionStatus.granted;
    }
    setState(() {
      _permissionStatuses[key] = status;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingDoneKey, true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < AppConstants.totalOnboardingPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(),
                  _buildHowItWorksPage(),
                  _buildPermissionsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(AppConstants.totalOnboardingPages, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                  right: index < AppConstants.totalOnboardingPages - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: index <= _currentPage
                    ? AppColors.primaryText
                    : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_rounded,
              size: 100, color: AppColors.primaryText),
          const SizedBox(height: 32),
          const Text(
            'Welcome to CameraCoach',
            style: AppTextStyles.mainTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your personal pose guide — match any reference photo in real time and let the app take the shot when you\'ve nailed it.',
            style: AppTextStyles.primaryBody
                .copyWith(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksPage() {
    final steps = [
      (
        '1',
        Icons.photo_library_rounded,
        'Upload a Reference Photo',
        'Pick any photo that has the pose you\'re going for.'
      ),
      (
        '2',
        Icons.camera_rounded,
        'Enter Coach Mode',
        'See a neon silhouette guide overlaid on your camera feed in real time.'
      ),
      (
        '3',
        Icons.auto_awesome_rounded,
        'Auto-Capture at 97% Match',
        'Hold the pose at 97% match for a few frames and the app fires the shutter automatically.'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How It Works', style: AppTextStyles.mainTitle),
          const SizedBox(height: 32),
          ...steps.map((step) => _buildStepRow(step.$2, step.$3, step.$4)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Next →'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Icon(icon, color: AppColors.primaryText, size: 28),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.secondaryBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Just a couple of permissions',
              style: AppTextStyles.mainTitle),
          const SizedBox(height: 8),
          Text(
            'CameraCoach needs camera access and photo library access to work. Everything runs on your device — nothing is sent anywhere.',
            style: AppTextStyles.primaryBody
                .copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 32),
          PermissionTile(
            icon: Icons.camera_alt_rounded,
            title: 'Camera',
            subtitle: 'Required for real-time pose detection and coaching.',
            status: _permissionStatuses['camera']!,
            onRequest: () => _requestSinglePermission('camera'),
          ),
          const SizedBox(height: 12),
          PermissionTile(
            icon: Icons.photo_library_rounded,
            title: 'Photo Library',
            subtitle: 'To upload reference photos and save captured images.',
            status: _permissionStatuses['storage']!,
            onRequest: () => _requestSinglePermission('storage'),
          ),
          const SizedBox(height: 12),
          const PermissionTile(
            icon: Icons.sensors_rounded,
            title: 'Motion & Sensors',
            subtitle: 'Device orientation for accurate angle guidance.',
            status: PermissionStatus.granted,
            onRequest: null,
          ),
          const Spacer(),
          if (!_allPermissionsGranted) ...[
            ElevatedButton(
              onPressed: _requestAllPermissions,
              child: const Text('Grant All Permissions'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text(
                  'Skip for now — I\'ll grant these later',
                  style: AppTextStyles.buttonSecondary,
                ),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _completeOnboarding,
              child: const Text('Start Coaching →'),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
