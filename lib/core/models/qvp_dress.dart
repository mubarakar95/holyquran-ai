import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'quran_dressing_catalog.dart';

/// Helper to load a vector picture with blazing-fast binary [.vec] format first (<1ms),
/// gracefully falling back to standard [.svg] if [.vec] is not present.
Future<PictureInfo> _loadVectorPicture(String folder, String normalized) async {
  try {
    return await vg.loadPicture(
      AssetBytesLoader('assets/ornaments/$folder/$normalized.svg.vec'),
      null,
    );
  } catch (_) {
    return await vg.loadPicture(
      SvgAssetLoader('assets/ornaments/$folder/$normalized.svg'),
      null,
    );
  }
}

/// Represents a custom ornamental dress (e.g. illuminated ayah marker)
/// extracted from traditional mushaf manuscripts (quran-assets).
class QvpAyahDress {
  final String id;
  final String name;
  final double slotX;
  final double slotY;
  final double slotWidth;
  final double slotHeight;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double scaleMultiplier;
  final ui.Picture? picture;

  const QvpAyahDress({
    required this.id,
    required this.name,
    required this.slotX,
    required this.slotY,
    required this.slotWidth,
    required this.slotHeight,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    this.scaleMultiplier = 1.28,
    this.picture,
  });

  double get slotCenterX => slotX + slotWidth / 2.0;
  double get slotCenterY => slotY + slotHeight / 2.0;

  /// Loads and compiles the vector Ayah marker asset for the given [styleId] into a GPU-backed [ui.Picture].
  static Future<QvpAyahDress?> load(String styleId) async {
    if (styleId == 'classic' || styleId == 'none') {
      return null;
    }
    final normalized = QuranDressingCatalog.normalizeAyahId(styleId);
    final meta = QuranDressingCatalog.getAyahMarkerMeta(normalized);

    final info = await _loadVectorPicture('ayah-markers', normalized);

    return QvpAyahDress(
      id: meta.id,
      name: meta.name,
      slotX: meta.slotX,
      slotY: meta.slotY,
      slotWidth: meta.slotWidth,
      slotHeight: meta.slotHeight,
      viewBoxWidth: meta.viewBoxWidth,
      viewBoxHeight: meta.viewBoxHeight,
      scaleMultiplier: meta.scaleMultiplier,
      picture: info.picture,
    );
  }

  /// Draws the ornament centered on the given coordinates `(cx, cy)`,
  /// aligned so that the numeral fits precisely within the internal slot.
  void draw({
    required ui.Canvas canvas,
    required double cx,
    required double cy,
    required double ringHeight,
  }) {
    if (picture == null) return;
    final markerScale = (ringHeight * scaleMultiplier) / viewBoxHeight;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(markerScale, markerScale);
    canvas.translate(-slotCenterX, -slotCenterY);
    canvas.drawPicture(picture!);
    canvas.restore();
  }
}

/// Represents the ornate surah title cartouche / header ornament
/// extracted from traditional mushaf manuscripts (quran-assets).
class QvpSurahHeaderDress {
  final String id;
  final String name;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double slotX;
  final double slotY;
  final double slotWidth;
  final double slotHeight;
  final ui.Picture picture;

  static const double standardColumnWidth = 328.0;

  const QvpSurahHeaderDress({
    required this.id,
    required this.name,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.slotX,
    required this.slotY,
    required this.slotWidth,
    required this.slotHeight,
    required this.picture,
  });

  double get slotCenterX => slotX + slotWidth / 2.0;
  double get slotCenterY => slotY + slotHeight / 2.0;

  /// Loads and precompiles the Surah header vector asset into a GPU-backed [ui.Picture].
  static Future<QvpSurahHeaderDress?> load(String styleId) async {
    if (styleId == 'classic' || styleId == 'none') {
      return null;
    }
    final normalized = QuranDressingCatalog.normalizeHeaderId(styleId);
    final meta = QuranDressingCatalog.getSurahHeaderMeta(normalized);

    final info = await _loadVectorPicture('surah-headers', normalized);

    return QvpSurahHeaderDress(
      id: meta.id,
      name: meta.name,
      viewBoxWidth: meta.viewBoxWidth,
      viewBoxHeight: meta.viewBoxHeight,
      slotX: meta.slotX,
      slotY: meta.slotY,
      slotWidth: meta.slotWidth,
      slotHeight: meta.slotHeight,
      picture: info.picture,
    );
  }

  /// Draws the illuminated Surah header cartouche centered horizontally on the page
  /// and aligned vertically with the calligraphy title [titleCenterY].
  void draw({
    required ui.Canvas canvas,
    required double titleCenterY,
    required bool isDark,
    double columnWidth = standardColumnWidth,
    double pageWidth = 345.0,
  }) {
    final scale = columnWidth / viewBoxWidth;
    final x = (pageWidth - columnWidth) / 2.0;
    final y = titleCenterY - (slotCenterY * scale);

    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale, scale);
    if (isDark) {
      final paint = ui.Paint()
        ..colorFilter = const ui.ColorFilter.mode(
          ui.Color(0xFFE2E8F0),
          ui.BlendMode.modulate,
        );
      canvas.saveLayer(null, paint);
      canvas.drawPicture(picture);
      canvas.restore();
    } else {
      canvas.drawPicture(picture);
    }
    canvas.restore();
  }
}

/// Represents the authentic ornate manuscript page border/frame
/// extracted from traditional mushaf manuscripts (quran-assets).
class QvpFrameDress {
  final String id;
  final String name;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double slotX;
  final double slotY;
  final double slotWidth;
  final double slotHeight;
  final ui.Picture? picture;

  const QvpFrameDress({
    required this.id,
    required this.name,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.slotX,
    required this.slotY,
    required this.slotWidth,
    required this.slotHeight,
    this.picture,
  });

  static final Map<String, QvpFrameDress> _cache = {};

  /// Synchronously returns a pre-cached dress if already compiled, or null.
  static QvpFrameDress? getCached(String styleId) {
    if (styleId == 'minimal' || styleId == 'none') {
      return null;
    }
    final normalized = QuranDressingCatalog.normalizeFrameId(styleId);
    return _cache[normalized];
  }

  /// Loads and precompiles the page frame vector asset into a GPU-backed [ui.Picture].
  /// Cached persistently in memory so all page turns and screen transitions render instantaneously in 0ms.
  static Future<QvpFrameDress?> load(String styleId) async {
    if (styleId == 'minimal' || styleId == 'none') {
      return null;
    }
    final normalized = QuranDressingCatalog.normalizeFrameId(styleId);
    if (_cache.containsKey(normalized)) {
      return _cache[normalized];
    }
    final meta = QuranDressingCatalog.getFrameMeta(normalized);

    final info = await _loadVectorPicture('page-frames', normalized);

    final dress = QvpFrameDress(
      id: meta.id,
      name: meta.name,
      viewBoxWidth: meta.viewBoxWidth,
      viewBoxHeight: meta.viewBoxHeight,
      slotX: meta.slotX,
      slotY: meta.slotY,
      slotWidth: meta.slotWidth,
      slotHeight: meta.slotHeight,
      picture: info.picture,
    );
    _cache[normalized] = dress;
    return dress;
  }

  /// Draws the precompiled ornate border scaled to the given size.
  void draw({
    required ui.Canvas canvas,
    required ui.Size size,
    bool isDark = false,
  }) {
    if (picture == null || size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.scale(size.width / viewBoxWidth, size.height / viewBoxHeight);
    canvas.drawPicture(picture!);
    canvas.restore();
  }
}

/// A GPU-accelerated painter that draws a precompiled [QvpFrameDress] instantaneously.
class QvpFramePainter extends CustomPainter {
  final QvpFrameDress dress;

  const QvpFramePainter({required this.dress});

  @override
  void paint(Canvas canvas, Size size) {
    dress.draw(canvas: canvas, size: size);
  }

  @override
  bool shouldRepaint(covariant QvpFramePainter oldDelegate) {
    return oldDelegate.dress != dress;
  }
}

