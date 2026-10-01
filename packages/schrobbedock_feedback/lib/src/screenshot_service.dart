import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ScreenshotService {
  /// Probeert een screenshot te maken van de huidige view via de dichtstbijzijnde RenderRepaintBoundary
  static Future<Uint8List?> captureContext(BuildContext context) async {
    try {
      RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null) return null;

      // Zoek omhoog in de render tree naar de RenderRepaintBoundary
      while (renderObject != null && renderObject is! RenderRepaintBoundary) {
        renderObject = renderObject.parent;
      }

      if (renderObject is RenderRepaintBoundary) {
        if (renderObject.debugNeedsPaint) {
          return null;
        }
        // Vermijd vastlopen in headless testomgevingen zonder rasterizer
        if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
          return null;
        }
        final ui.Image image = await renderObject.toImage(pixelRatio: 1.25);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('[SchrobbeDockFeedback] Screenshot capture warning: $e');
    }
    return null;
  }
}
