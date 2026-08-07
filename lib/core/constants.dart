/// App-wide constants for CameraCoach.
class AppConstants {
  AppConstants._();

  // How closely the live pose must match the reference before we auto-capture.
  static const double poseMatchThreshold = 0.97;
  // Analyse every 4th camera frame to keep the UI smooth on mid-range phones.
  static const int frameSkip = 4;
  // ML Kit returns up to 33 body landmarks per person.
  static const int maxKeypoints = 33;

  // Key used to remember whether the user has completed onboarding.
  static const String onboardingDoneKey = 'onboarding_done';

  // On-device TFLite model used as the silhouette-generation fallback.
  static const String poseModelPath = 'models/pose_landmark_full.tflite';

  // Number of pages in the first-launch walkthrough.
  static const int totalOnboardingPages = 3;

  // Camera presets shown in PRO mode — kept here so they stay in sync
  // between the live screen and the photo-quality analyser.
  static const List<int> isoPresets = [50, 100, 200, 400, 800];
  static const List<String> shutterPresets = [
    '1/4000', '1/2000', '1/1000', '1/500', '1/125', '1/60', '1/15',
    '1s', '4s', '8s', '30s',
  ];
  static const List<String> whiteBalancePresets = [
    'AWB', '2300K', '3200K', '5500K', '6500K', '8000K',
  ];
}

/// Thresholds used by PhotoQualityAnalyzer to rate each captured shot.
class ProThresholds {
  ProThresholds._();

  // Face luminance range — anything below severeUnderExposed looks muddy.
  static const double severeUnderExposed = 85.0;
  static const double slightlyDark = 105.0;
  static const double highlightClipping = 215.0;

  // Depth-of-field ratio between face sharpness and background sharpness.
  static const double shallowPro = 8.0;
  static const double deepLimit = 3.0;

  // Pixel brightness spread — higher means the shot holds detail in both
  // shadows and highlights.
  static const double excellentHdr = 180.0;

  // b* axis of the CIELAB colour space used as a warm/cool proxy.
  static const double warmLimit = 145.0;
  static const double coolLimit = 110.0;
}
