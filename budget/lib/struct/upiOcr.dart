import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_ocr/mobile_ocr.dart';
import 'package:path_provider/path_provider.dart';

/// PP-OCR v5 (via mobile_ocr) natively accepts images up to 4096px, but a
/// 2048px normalization keeps recognition fast and consistent on large
/// screenshots, so the image is pre-normalized to this side length before OCR.
const double upiOcrTargetSide = 2048;

/// A single recognized word/symbol with its position and confidence.
class UpiOcrElement {
  const UpiOcrElement({
    required this.text,
    required this.boundingBox,
    this.confidence,
    this.cornerPoints = const [],
  });

  final String text;

  /// Position in the ORIGINAL screenshot coordinate space.
  final ui.Rect boundingBox;

  /// Confidence in [0, 1] when provided by the engine.
  final double? confidence;

  /// Four corners of the recognized element, in original image coordinates.
  final List<math.Point<int>> cornerPoints;

  @override
  String toString() =>
      "UpiOcrElement('$text', $boundingBox, confidence=$confidence)";
}

/// A recognized line of text; groups [UpiOcrElement]s that belong together.
class UpiOcrLine {
  const UpiOcrLine({
    required this.text,
    required this.boundingBox,
    this.confidence,
    this.elements = const [],
  });

  final String text;
  final ui.Rect boundingBox;
  final double? confidence;
  final List<UpiOcrElement> elements;

  UpiOcrElement? findElementContaining(String substring) {
    for (final element in elements) {
      if (element.text.toLowerCase().contains(substring.toLowerCase())) {
        return element;
      }
    }
    return null;
  }

  @override
  String toString() =>
      "UpiOcrLine('$text', $boundingBox, confidence=$confidence)";
}

/// A block of text (usually a paragraph) composed of [UpiOcrLine]s.
class UpiOcrBlock {
  const UpiOcrBlock({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
  });

  final String text;
  final ui.Rect boundingBox;
  final List<UpiOcrLine> lines;

  @override
  String toString() => "UpiOcrBlock('$text', $boundingBox)";
}

/// Structured OCR result: complete raw text plus positional data. Downstream
/// parsers should use [allLines]/[allElements] and their bounding boxes to
/// relate labels to values (e.g. "Amount" directly above "₹1,250") instead of
/// treating the screenshot as a flat text blob.
class UpiOcrResult {
  const UpiOcrResult({
    required this.rawText,
    required this.blocks,
    required this.sourcePath,
    this.preprocessedPath,
    this.adjustments = const [],
    this.scaleApplied = 1,
  });

  /// Complete recognized text, preserving order (use for text parsers).
  final String rawText;

  final List<UpiOcrBlock> blocks;

  /// Original image the screenshot was taken from.
  final String sourcePath;

  /// Preprocessed image that was actually sent to the OCR engine.
  final String? preprocessedPath;

  /// Which preprocessing steps were applied (for debugging).
  final List<String> adjustments;

  /// Factor the image was resized by before OCR.
  final double scaleApplied;

  /// Every line, ordered top-to-bottom then left-to-right.
  List<UpiOcrLine> get allLines {
    final lines = <UpiOcrLine>[];
    for (final block in blocks) {
      lines.addAll(block.lines);
    }
    lines.sort((a, b) {
      final topDiff = a.boundingBox.top.compareTo(b.boundingBox.top);
      return topDiff != 0 ? topDiff : a.boundingBox.left.compareTo(b.boundingBox.left);
    });
    return lines;
  }

  /// Every element, ordered top-to-bottom then left-to-right.
  List<UpiOcrElement> get allElements {
    final elements = <UpiOcrElement>[];
    for (final line in allLines) {
      elements.addAll(line.elements);
    }
    return elements;
  }

  /// First line (in reading order) whose text contains [substring].
  UpiOcrLine? lineContaining(String substring) {
    for (final line in allLines) {
      if (line.text.toLowerCase().contains(substring.toLowerCase())) {
        return line;
      }
    }
    return null;
  }

  @override
  String toString() => "UpiOcrResult(blocks=${blocks.length}, "
      "lines=${allLines.length}, text='${rawText.trim()}'...)";
}

/// Result of validating an image before OCR.
class UpiImageValidation {
  const UpiImageValidation({
    required this.isValid,
    this.errorKey,
    this.width,
    this.height,
  });

  final bool isValid;

  /// i18n key describing why the image was rejected, when invalid.
  final String? errorKey;

  final int? width;
  final int? height;
}

/// Result of the preprocessing step.
class UpiImagePreprocessResult {
  const UpiImagePreprocessResult({
    required this.path,
    required this.scale,
    required this.adjustments,
  });

  final String path;
  final double scale;
  final List<String> adjustments;
}

/// Raised when OCR cannot be completed; [message] is an i18n key or message.
class UpiOcrException implements Exception {
  const UpiOcrException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => "UpiOcrException($message)";
}

/// Validates that [imagePath] points to a decodable, usable image.
Future<UpiImageValidation> validateUpiImage(String imagePath) async {
  final file = File(imagePath);
  if (!file.existsSync()) {
    return const UpiImageValidation(isValid: false, errorKey: "upi-image-not-found");
  }
  final size = file.lengthSync();
  // Reject empty files and files too large to be a screenshot.
  if (size <= 0) {
    return const UpiImageValidation(isValid: false, errorKey: "upi-image-invalid");
  }
  if (size > 30 * 1024 * 1024) {
    return const UpiImageValidation(isValid: false, errorKey: "upi-image-too-large");
  }
  try {
    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      return const UpiImageValidation(isValid: false, errorKey: "upi-image-invalid");
    }
    final minSide = math.min(decoded.width, decoded.height);
    if (minSide < 100 || math.max(decoded.width, decoded.height) > 8192) {
      return const UpiImageValidation(isValid: false, errorKey: "upi-image-invalid");
    }
    return UpiImageValidation(
      isValid: true,
      width: decoded.width,
      height: decoded.height,
    );
  } catch (_) {
    return const UpiImageValidation(isValid: false, errorKey: "upi-image-invalid");
  }
}

/// Preprocesses a screenshot so the OCR engine sees the maximum amount of
/// text detail:
///
/// 1. Resize the longest side to [upiOcrTargetSide] (2048px) with cubic
///    interpolation — keeps large screenshots fast and consistent.
/// 2. Convert to grayscale to remove color noise (the engine already works on
///    luminance, so this does not harm glyphs like ₹ / 1 / I / 0).
/// 3. Only if the image is dark or low-contrast (e.g. dark-mode screenshots),
///    apply a linear contrast stretch across the full range.
///
/// Deliberately does NOT threshold/binarize or aggressively sharpen — those
/// destroy the antialiasing that keeps ₹, 1, I, 0 and decimal points
/// distinguishable.
Future<UpiImagePreprocessResult> preprocessUpiImage(String imagePath) async {
  img.Image? image;
  try {
    image = img.decodeImage(File(imagePath).readAsBytesSync());
  } catch (_) {
    // Fall through; a null image raises below.
  }
  if (image == null) {
    throw const UpiOcrException("upi-image-invalid");
  }

  image = img.bakeOrientation(image);
  final adjustments = <String>[];

  final longestSide = math.max(image.width, image.height).toDouble();
  double scale = 1;
  if ((longestSide - upiOcrTargetSide).abs() > 0.5) {
    scale = upiOcrTargetSide / longestSide;
    final newWidth = math.max(1, (image.width * scale).round());
    final newHeight = math.max(1, (image.height * scale).round());
    image = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );
    adjustments.add("scale ${scale.toStringAsFixed(2)}x");
  }

  image = img.grayscale(image);
  adjustments.add("grayscale");

  final stats = _computeLuminanceStats(image);
  // Dark-mode screenshots or washed-out low-contrast images: stretch to full
  // dynamic range so text is clearly separated from the background.
  if (stats.mean < 70 || stats.standardDeviation < 30) {
    image = img.normalize(image, min: 0, max: 255);
    adjustments.add("contrast-stretch");
  }

  final dir = await getTemporaryDirectory();
  final outFile = File(
    '${dir.path}${Platform.pathSeparator}upi_ocr_preprocessed_'
    '${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await outFile.writeAsBytes(img.encodePng(image));

  return UpiImagePreprocessResult(
    path: outFile.path,
    scale: scale,
    adjustments: adjustments,
  );
}

class _LuminanceStats {
  const _LuminanceStats(this.mean, this.standardDeviation);
  final double mean;
  final double standardDeviation;
}

/// Approximates mean luma and standard deviation on a small downsampled copy,
/// so the cost is negligible for any screenshot.
_LuminanceStats _computeLuminanceStats(img.Image image) {
  final sampleSize = 64;
  final sampled = img.copyResize(
    image,
    width: sampleSize,
    height: sampleSize,
    interpolation: img.Interpolation.average,
  );
  int sum = 0;
  int sumSquares = 0;
  final pixelCount = sampled.width * sampled.height;
  for (var y = 0; y < sampled.height; y++) {
    for (var x = 0; x < sampled.width; x++) {
      final luma = sampled.getPixel(x, y).r.toInt();
      sum += luma;
      sumSquares += luma * luma;
    }
  }
  final mean = sum / pixelCount;
  final variance = (sumSquares / pixelCount) - (mean * mean);
  return _LuminanceStats(mean, math.sqrt(math.max(0, variance)));
}

/// Maps the mobile_ocr (PP-OCR v5) [TextBlock]s onto the structured
/// [UpiOcrResult], converting bounding boxes back into the original image's
/// coordinate space. The blocks arrive as individual text lines (detector
/// regions), so each becomes one [UpiOcrLine] with a single element.
UpiOcrResult mapTextDetectionResult(
  List<TextBlock> blocks, {
  required String sourcePath,
  String? preprocessedPath,
  List<String> adjustments = const [],
  double scaleApplied = 1,
}) {
  final coordScale = 1 / scaleApplied;
  final lines = <UpiOcrLine>[];
  for (final block in blocks) {
    final text = block.text.trim();
    if (text.isEmpty) continue;
    final cornerPoints = block.points
        .map((p) => math.Point<int>(
              (p.dx * coordScale).round(),
              (p.dy * coordScale).round(),
            ))
        .toList();
    final element = UpiOcrElement(
      text: text,
      boundingBox: _scaleRect(block.boundingBox, coordScale),
      confidence: block.confidence,
      cornerPoints: cornerPoints,
    );
    lines.add(
      UpiOcrLine(
        text: text,
        boundingBox: _scaleRect(block.boundingBox, coordScale),
        confidence: block.confidence,
        elements: [element],
      ),
    );
  }
  lines.sort(_compareTopLeft);
  final upiBlocks = <UpiOcrBlock>[
    for (final line in lines)
      UpiOcrBlock(
        text: line.text,
        boundingBox: line.boundingBox,
        lines: [line],
      ),
  ];
  return UpiOcrResult(
    rawText: lines.map((line) => line.text).join("\n"),
    blocks: upiBlocks,
    sourcePath: sourcePath,
    preprocessedPath: preprocessedPath,
    adjustments: adjustments,
    scaleApplied: scaleApplied,
  );
}

int _compareTopLeft(UpiOcrLine a, UpiOcrLine b) {
  final topDiff = a.boundingBox.top.compareTo(b.boundingBox.top);
  return topDiff != 0
      ? topDiff
      : a.boundingBox.left.compareTo(b.boundingBox.left);
}

ui.Rect _scaleRect(ui.Rect rect, double factor) {
  return ui.Rect.fromLTRB(
    rect.left * factor,
    rect.top * factor,
    rect.right * factor,
    rect.bottom * factor,
  );
}

/// mobile_ocr (PP-OCR v5) caches its ONNX models under
/// `<filesDir>/assets/mobile_ocr/` and validates them by SHA-256 before use.
/// These constants mirror the plugin's ModelManager so the bundled assets are
/// accepted as already-present and never re-downloaded.
const List<String> _upiOcrModelNames = [
  "det.onnx",
  "rec.onnx",
  "cls.onnx",
  "ppocrv5_dict.txt",
];
const String _upiOcrModelVersion = "pp-ocrv5-202410";
const String _upiOcrModelVersionFile = ".model_version";

Future<void>? _upiOcrModelInit;

/// Copies the bundled PP-OCR v5 models from the Flutter asset bundle into the
/// cache directory the plugin expects, then warms up the ONNX sessions. After
/// the first successful run this is a cheap no-op, so all OCR calls work
/// entirely offline with no downloads.
Future<void> ensureUpiOcrModels() {
  final existing = _upiOcrModelInit;
  if (existing != null) return existing;
  final future = _initUpiOcrModels();
  _upiOcrModelInit = future;
  future.catchError((Object _) {
    _upiOcrModelInit = null;
  });
  return future;
}

Future<void> _initUpiOcrModels() async {
  final cacheDir = Directory(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}mobile_ocr',
  );
  final versionFile =
      File('${cacheDir.path}${Platform.pathSeparator}$_upiOcrModelVersionFile');

  final versionMatches =
      versionFile.existsSync() &&
      versionFile.readAsStringSync().trim() == _upiOcrModelVersion;
  final allPresent = _upiOcrModelNames.every(
    (name) => File('${cacheDir.path}${Platform.pathSeparator}$name').existsSync(),
  );

  if (!versionMatches || !allPresent) {
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    for (final name in _upiOcrModelNames) {
      final data = await rootBundle.load('assets/ppocr/$name');
      final file = File('${cacheDir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    await versionFile.writeAsString(_upiOcrModelVersion, flush: true);
  }

  await MobileOcr().prepareModels();
}

/// Result returned by the background isolate: validation + preprocessing.
class _PreprocessResult {
  const _PreprocessResult({
    required this.isValid,
    this.errorKey,
    this.preprocessedBytes,
    this.scale = 1,
    this.adjustments = const [],
  });

  final bool isValid;
  final String? errorKey;
  final Uint8List? preprocessedBytes;
  final double scale;
  final List<String> adjustments;
}

/// Heavy image work that runs in a background isolate via [compute].
///
/// Decodes, validates, resizes, converts to grayscale, and optionally applies
/// contrast stretch. Returns the processed PNG bytes (or null on error).
_PreprocessResult _validateAndPreprocessInIsolate(List<dynamic> args) {
  final Uint8List imageBytes = args[0];
  final double targetSide = args[1];

  try {
    if (imageBytes.isEmpty) {
      return const _PreprocessResult(isValid: false, errorKey: "upi-image-invalid");
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return const _PreprocessResult(isValid: false, errorKey: "upi-image-invalid");
    }
    final minSide = math.min(decoded.width, decoded.height);
    if (minSide < 100 || math.max(decoded.width, decoded.height) > 8192) {
      return const _PreprocessResult(isValid: false, errorKey: "upi-image-invalid");
    }

    img.Image image = img.bakeOrientation(decoded);
    final adjustments = <String>[];

    final longestSide = math.max(image.width, image.height).toDouble();
    double scale = 1;
    if ((longestSide - targetSide).abs() > 0.5) {
      scale = targetSide / longestSide;
      final newWidth = math.max(1, (image.width * scale).round());
      final newHeight = math.max(1, (image.height * scale).round());
      image = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );
      adjustments.add("scale ${scale.toStringAsFixed(2)}x");
    }

    image = img.grayscale(image);
    adjustments.add("grayscale");

    // Quick luminance stats on a downsampled copy.
    final sampleSize = 64;
    final sampled = img.copyResize(
      image,
      width: sampleSize,
      height: sampleSize,
      interpolation: img.Interpolation.average,
    );
    int sum = 0;
    int sumSquares = 0;
    final pixelCount = sampled.width * sampled.height;
    for (var y = 0; y < sampled.height; y++) {
      for (var x = 0; x < sampled.width; x++) {
        final luma = sampled.getPixel(x, y).r.toInt();
        sum += luma;
        sumSquares += luma * luma;
      }
    }
    final mean = sum / pixelCount;
    final variance = (sumSquares / pixelCount) - (mean * mean);
    final stdDev = math.sqrt(math.max(0, variance));

    if (mean < 70 || stdDev < 30) {
      image = img.normalize(image, min: 0, max: 255);
      adjustments.add("contrast-stretch");
    }

    final pngBytes = Uint8List.fromList(img.encodePng(image));
    return _PreprocessResult(
      isValid: true,
      preprocessedBytes: pngBytes,
      scale: scale,
      adjustments: adjustments,
    );
  } catch (_) {
    return const _PreprocessResult(isValid: false, errorKey: "upi-image-invalid");
  }
}

/// Runs the full OCR pipeline on a screenshot:
///
/// PP-OCR v5 (mobile_ocr) → structured result.
///
/// Dart-side preprocessing is intentionally skipped — the native plugin uses
/// Android's hardware-accelerated BitmapFactory with inSampleSize downsampling,
/// which is faster than Dart's `image` package decode + resize + PNG encode.
/// This eliminates a redundant decode/encode cycle (~1-2 s savings).
Future<UpiOcrResult> recognizeUpiScreenshot(String imagePath) async {
  final sw = Stopwatch()..start();

  try {
    await ensureUpiOcrModels();
    print("[UpiScan] ensureUpiOcrModels: ${sw.elapsedMilliseconds}ms");
    final modelReady = sw.elapsedMilliseconds;

    final result = await MobileOcr().detectText(
      imagePath: imagePath,
      includeAllConfidenceScores: true,
    );
    print("[UpiScan] detectText: ${sw.elapsedMilliseconds - modelReady}ms "
        "(total ${sw.elapsedMilliseconds}ms)");
    sw.stop();

    return mapTextDetectionResult(
      result.blocks,
      sourcePath: imagePath,
    );
  } on PlatformException catch (e) {
    throw UpiOcrException("upi-ocr-error", e);
  } on OcrException catch (e) {
    throw UpiOcrException("upi-ocr-error", e);
  }
}
