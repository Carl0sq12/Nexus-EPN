import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utilities for rejecting images that are too blurry to verify.
abstract final class ImageSharpness {
  static const double defaultThreshold = 100;

  static Future<double> laplacianVariance(File file) async {
    final bytes = await file.readAsBytes();
    return Isolate.run(() => _laplacianVariance(bytes));
  }

  static Future<bool> isSharp(
    File file, {
    double threshold = defaultThreshold,
  }) async {
    return await laplacianVariance(file) >= threshold;
  }
}

double _laplacianVariance(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null || image.width < 3 || image.height < 3) return 0;

  var count = 0;
  var mean = 0.0;
  var squaredDifferenceSum = 0.0;

  for (var y = 1; y < image.height - 1; y++) {
    for (var x = 1; x < image.width - 1; x++) {
      final center = _luminance(image.getPixel(x, y));
      final laplacian =
          4 * center -
          _luminance(image.getPixel(x - 1, y)) -
          _luminance(image.getPixel(x + 1, y)) -
          _luminance(image.getPixel(x, y - 1)) -
          _luminance(image.getPixel(x, y + 1));

      count++;
      final delta = laplacian - mean;
      mean += delta / count;
      squaredDifferenceSum += delta * (laplacian - mean);
    }
  }

  return count > 1 ? squaredDifferenceSum / (count - 1) : 0;
}

double _luminance(img.Pixel pixel) {
  return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
}
