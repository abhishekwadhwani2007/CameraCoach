import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/constants.dart';
import '../services/local_storage_service.dart';
import '../utils/logger.dart';

/// Generates on-device silhouette overlays using the TFLite pose landmark model.
class SilhouetteGenerator {
  static Interpreter? _interpreter;

  static Future<void> _loadModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/${AppConstants.poseModelPath}',
      );
    } catch (e) {
      AppLogger.error('Error loading silhouette model: $e');
    }
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

  static Future<String?> generate({
    required String imagePath,
    Map<String, dynamic>? landmarks,
  }) async {
    await _loadModel();
    if (_interpreter == null) return null;

    final bytes = await File(imagePath).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return null;

    final width = original.width;
    final height = original.height;

    // Step 1: run TFLite to extract the per-pixel segmentation mask.
    const ts = 256; // 256×256 is the model's fixed input resolution
    final resized = img.copyResize(original, width: ts, height: ts);

    final inputFlat = Float32List(ts * ts * 3);
    int idx = 0;
    for (int y = 0; y < ts; y++) {
      for (int x = 0; x < ts; x++) {
        final p = resized.getPixel(x, y);
        inputFlat[idx++] = p.r.toDouble() / 255.0;
        inputFlat[idx++] = p.g.toDouble() / 255.0;
        inputFlat[idx++] = p.b.toDouble() / 255.0;
      }
    }

    // Model outputs shape [1, 256, 256, 1].
    final maskOut = List.generate(
        1,
        (_) => List.generate(
            ts, (_) => List.generate(ts, (_) => List.filled(1, 0.0))));

    try {
      _interpreter!.allocateTensors();
      _interpreter!.getInputTensor(0).setTo(inputFlat);
      _interpreter!.invoke();
      _interpreter!.getOutputTensor(2).copyTo(maskOut);
    } catch (e) {
      AppLogger.error('Silhouette inference error: $e');
      _interpreter?.close();
      _interpreter = null;
      return null;
    }

    // Step 2: build a boolean mask, then augment it with skeleton lines.
    final mask = List.generate(ts, (_) => List.filled(ts, false));
    for (int y = 0; y < ts; y++) {
      for (int x = 0; x < ts; x++) {
        mask[y][x] = _sigmoid(maskOut[0][y][x][0]) > 0.5;
      }
    }

    if (landmarks != null && landmarks.isNotEmpty) {
      _augmentMaskWithSkeleton(mask, landmarks, width, height, ts);
    }

    // Step 3: smooth the mask edges with morphological dilation and erosion.
    var processed = _dilate(mask, 3);
    processed = _erode(processed, 3);

    final dilated = _dilate(processed, 2);

    var maskFloat = List.generate(
        ts,
        (y) => Float64List.fromList(
            List.generate(ts, (x) => dilated[y][x] ? 1.0 : 0.0)));
    maskFloat = _blur(maskFloat, ts, ts, 4.0);

    final smoothed = List.generate(
        ts, (y) => List.generate(ts, (x) => maskFloat[y][x] > 0.45));

    final edgeDilated = _dilate(smoothed, 2);
    final edgeEroded = _erode(smoothed, 2);

    final edges = List.generate(ts, (_) => Float64List(ts));
    for (int y = 0; y < ts; y++) {
      for (int x = 0; x < ts; x++) {
        if (edgeDilated[y][x] && !edgeEroded[y][x]) {
          edges[y][x] = 1.0;
        }
      }
    }

    // Step 4: render the neon glow in a background isolate so the UI stays smooth.
    final pngBytes = await compute(_renderNeonGlow, edges);

    // Step 5: write the overlay to the scoped temp directory.
    final scopedPath = await LocalStorageService.getScopedTempPath();
    final out = File(
      '$scopedPath/reference_overlay_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await out.writeAsBytes(pngBytes, flush: true);
    return out.path;
  }

  /// Heavy pixel work — runs in a separate isolate via compute().
  static Uint8List _renderNeonGlow(List<Float64List> edges) {
    const ts = 256;
    // Render at a small size — Flutter upscales smoothly since everything is soft glow.
    const cw = 270;
    const ch = 480;

    // Bilinear upscale the edges from 256×256 to the canvas size.
    final edgeUp = List.generate(ch, (_) => Float64List(cw));
    const sxr = ts / cw;
    const syr = ts / ch;
    for (int y = 0; y < ch; y++) {
      for (int x = 0; x < cw; x++) {
        final sx = x * sxr;
        final sy = y * syr;
        final x0 = sx.floor().clamp(0, ts - 2);
        final y0 = sy.floor().clamp(0, ts - 2);
        final fx = sx - x0;
        final fy = sy - y0;
        edgeUp[y][x] = edges[y0][x0] * (1 - fx) * (1 - fy) +
            edges[y0][x0 + 1] * fx * (1 - fy) +
            edges[y0 + 1][x0] * (1 - fx) * fy +
            edges[y0 + 1][x0 + 1] * fx * fy;
      }
    }

    // Three additive glow layers (outer spread → mid glow → inner core).
    const layers = [
      (12.0, 0.12, 170, 235, 130), // outer: warm green glow
      (5.0, 0.45, 110, 230, 55), // mid: brighter green
      (1.5, 0.85, 205, 245, 185), // inner: warm white core
    ];

    final alpha = List.generate(ch, (_) => Float64List(cw));
    final colR = List.generate(ch, (_) => Float64List(cw));
    final colG = List.generate(ch, (_) => Float64List(cw));
    final colB = List.generate(ch, (_) => Float64List(cw));

    for (final (rawR, intensity, r, g, b) in layers) {
      final sigma = max(0.8, rawR * ch / 1400.0);
      final blurred = _blur(edgeUp, cw, ch, sigma);
      for (int y = 0; y < ch; y++) {
        for (int x = 0; x < cw; x++) {
          final v = (blurred[y][x] * intensity * 2.5).clamp(0.0, 1.0);
          if (v > alpha[y][x]) alpha[y][x] = v;
          colR[y][x] += v * r / 255.0;
          colG[y][x] += v * g / 255.0;
          colB[y][x] += v * b / 255.0;
        }
      }
    }

    // Tight white core on top of the coloured glow.
    final core = _blur(edgeUp, cw, ch, 0.5);
    for (int y = 0; y < ch; y++) {
      for (int x = 0; x < cw; x++) {
        final v = (core[y][x] * 0.95).clamp(0.0, 1.0);
        colR[y][x] += v * 205 / 255.0;
        colG[y][x] += v * 245 / 255.0;
        colB[y][x] += v * 185 / 255.0;
        alpha[y][x] = (alpha[y][x] + v).clamp(0.0, 1.0);
      }
    }

    // Write every pixel to the RGBA canvas.
    final canvas = img.Image(width: cw, height: ch, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    for (int y = 0; y < ch; y++) {
      for (int x = 0; x < cw; x++) {
        final a = alpha[y][x];
        if (a < 0.004) continue;
        final inv = 1.0 / max(a, 1e-6);
        canvas.setPixelRgba(
          x,
          y,
          (colR[y][x] * inv * 255).clamp(0, 255).toInt(),
          (colG[y][x] * inv * 255).clamp(0, 255).toInt(),
          (colB[y][x] * inv * 255).clamp(0, 255).toInt(),
          (a * 255).clamp(0, 255).toInt(),
        );
      }
    }

    return Uint8List.fromList(img.encodePng(canvas));
  }

  /// 2-pass separable Gaussian blur.
  static List<Float64List> _blur(
      List<Float64List> src, int w, int h, double sigma) {
    final r = (sigma * 3).ceil();
    final ks = r * 2 + 1;
    final k = Float64List(ks);
    double s = 0;
    for (int i = 0; i < ks; i++) {
      final d = (i - r).toDouble();
      k[i] = exp(-0.5 * d * d / (sigma * sigma));
      s += k[i];
    }
    for (int i = 0; i < ks; i++) {
      k[i] /= s;
    }

    final tmp = List.generate(h, (_) => Float64List(w));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double v = 0;
        for (int j = -r; j <= r; j++) {
          v += src[y][(x + j).clamp(0, w - 1)] * k[j + r];
        }
        tmp[y][x] = v;
      }
    }

    final dst = List.generate(h, (_) => Float64List(w));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double v = 0;
        for (int j = -r; j <= r; j++) {
          v += tmp[(y + j).clamp(0, h - 1)][x] * k[j + r];
        }
        dst[y][x] = v;
      }
    }
    return dst;
  }

  /// Draw skeleton lines and joints onto the boolean mask.
  static void _augmentMaskWithSkeleton(
    List<List<bool>> mask,
    Map<String, dynamic> lm,
    int imgW,
    int imgH,
    int ts,
  ) {
    double bodyScale = 100.0;
    final lSh = lm['leftShoulder'], rSh = lm['rightShoulder'];
    if (lSh != null && rSh != null) {
      final d = sqrt(pow((lSh['x'] as num) - (rSh['x'] as num), 2) +
          pow((lSh['y'] as num) - (rSh['y'] as num), 2));
      if (d > 20) bodyScale = d.toDouble();
    }

    Offset? pt(String key) {
      final p = lm[key];
      if (p == null) return null;
      if ((p['lh'] as num).toDouble() < 0.25) return null;
      return Offset(
        ((p['x'] as num).toDouble() / imgW) * ts,
        ((p['y'] as num).toDouble() / imgH) * ts,
      );
    }

    void line(String a, String b, double wr) {
      final pa = pt(a), pb = pt(b);
      if (pa == null || pb == null) return;
      final thick = max(3.0, (bodyScale * wr / imgW) * ts);
      final dx = pb.dx - pa.dx, dy = pb.dy - pa.dy;
      final lenSq = dx * dx + dy * dy;
      final minX = (min(pa.dx, pb.dx) - thick).clamp(0, ts - 1).toInt();
      final maxX = (max(pa.dx, pb.dx) + thick).clamp(0, ts - 1).toInt();
      final minY = (min(pa.dy, pb.dy) - thick).clamp(0, ts - 1).toInt();
      final maxY = (max(pa.dy, pb.dy) + thick).clamp(0, ts - 1).toInt();
      for (int y = minY; y <= maxY; y++) {
        for (int x = minX; x <= maxX; x++) {
          double t =
              lenSq > 0 ? ((x - pa.dx) * dx + (y - pa.dy) * dy) / lenSq : 0;
          t = t.clamp(0.0, 1.0);
          final px = pa.dx + t * dx, py = pa.dy + t * dy;
          if ((x - px) * (x - px) + (y - py) * (y - py) <= thick * thick) {
            mask[y][x] = true;
          }
        }
      }
    }

    void circle(String key, double rr) {
      final p = pt(key);
      if (p == null) return;
      final r = max(2.5, (bodyScale * rr / imgW) * ts);
      final minX = (p.dx - r).clamp(0, ts - 1).toInt();
      final maxX = (p.dx + r).clamp(0, ts - 1).toInt();
      final minY = (p.dy - r).clamp(0, ts - 1).toInt();
      final maxY = (p.dy + r).clamp(0, ts - 1).toInt();
      for (int y = minY; y <= maxY; y++) {
        for (int x = minX; x <= maxX; x++) {
          if ((x - p.dx) * (x - p.dx) + (y - p.dy) * (y - p.dy) <= r * r) {
            mask[y][x] = true;
          }
        }
      }
    }

    // Body limb segments
    line('leftShoulder', 'rightShoulder', 0.35);
    line('leftShoulder', 'leftHip', 0.22);
    line('rightShoulder', 'rightHip', 0.22);
    line('leftHip', 'rightHip', 0.22);
    line('leftShoulder', 'leftElbow', 0.27);
    line('leftElbow', 'leftWrist', 0.23);
    line('rightShoulder', 'rightElbow', 0.27);
    line('rightElbow', 'rightWrist', 0.23);
    line('leftHip', 'leftKnee', 0.18);
    line('leftKnee', 'leftAnkle', 0.14);
    line('rightHip', 'rightKnee', 0.18);
    line('rightKnee', 'rightAnkle', 0.14);

    // Key joints
    for (final (k, r) in [
      ('nose', 0.15),
      ('leftEar', 0.12),
      ('rightEar', 0.12),
      ('leftShoulder', 0.13),
      ('rightShoulder', 0.13),
      ('leftWrist', 0.20),
      ('rightWrist', 0.20),
      ('leftAnkle', 0.12),
      ('rightAnkle', 0.12),
    ]) {
      circle(k, r);
    }
  }

  /// Square-kernel morphological dilation on a boolean grid.
  static List<List<bool>> _dilate(List<List<bool>> src, int radius) {
    final ts = src.length;
    final dst = List.generate(ts, (_) => List.filled(ts, false));
    for (int y = 0; y < ts; y++) {
      for (int x = 0; x < ts; x++) {
        if (src[y][x]) {
          final minY = max(0, y - radius);
          final maxY = min(ts - 1, y + radius);
          final minX = max(0, x - radius);
          final maxX = min(ts - 1, x + radius);
          for (int dy = minY; dy <= maxY; dy++) {
            for (int dx = minX; dx <= maxX; dx++) {
              dst[dy][dx] = true;
            }
          }
        }
      }
    }
    return dst;
  }

  /// Square-kernel morphological erosion on a boolean grid.
  static List<List<bool>> _erode(List<List<bool>> src, int radius) {
    final ts = src.length;
    final dst = List.generate(ts, (_) => List.filled(ts, true));
    for (int y = 0; y < ts; y++) {
      for (int x = 0; x < ts; x++) {
        if (!src[y][x]) {
          final minY = max(0, y - radius);
          final maxY = min(ts - 1, y + radius);
          final minX = max(0, x - radius);
          final maxX = min(ts - 1, x + radius);
          for (int dy = minY; dy <= maxY; dy++) {
            for (int dx = minX; dx <= maxX; dx++) {
              dst[dy][dx] = false;
            }
          }
        }
      }
    }
    return dst;
  }
}
