import 'dart:io';

/// The result of the overlay editor — the corrected mask file plus a flag
/// indicating whether the user actually changed anything from the AI version.
///
/// We carry [aiMaskPath] alongside so the upload service can send both the
/// original AI mask and the corrected one to the backend for model training.
class OverlayMask {
  /// The PNG mask file the user ended up with (may be the original AI mask
  /// if they hit Done without drawing anything).
  final File maskFile;

  /// Path to the AI-generated mask that was shown before the user edited.
  final String aiMaskPath;

  /// True only when the user made at least one brush stroke or erase.
  final bool userEdited;

  const OverlayMask({
    required this.maskFile,
    required this.aiMaskPath,
    required this.userEdited,
  });
}
