import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_easy_native/core/models/quran_dressing_catalog.dart';
import 'package:quran_easy_native/core/models/qvp_dress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QuranDressingCatalog contains exactly 8 authentic mushaf styles with metadata', () {
    expect(QuranDressingCatalog.mushafStyles.length, equals(8));
    expect(QuranDressingCatalog.frames.length, equals(8));
    expect(QuranDressingCatalog.surahHeaders.length, equals(8));
    expect(QuranDressingCatalog.ayahMarkers.length, equals(8));

    // Verify default hafs-adi metadata
    final hafsAdiMeta = QuranDressingCatalog.getFrameMeta('mushaf-hafs-adi');
    expect(hafsAdiMeta.viewBoxWidth, closeTo(64.419, 0.01));
    expect(hafsAdiMeta.viewBoxHeight, closeTo(100.0, 0.01));
    expect(hafsAdiMeta.slotX, closeTo(4.2763, 0.001));
    expect(hafsAdiMeta.slotY, closeTo(5.0439, 0.001));

    // Verify normalization from legacy IDs
    expect(QuranDressingCatalog.normalizeFrameId('madani'), equals('mushaf-hafs-adi'));
    expect(QuranDressingCatalog.normalizeHeaderId('madani'), equals('mushaf-hafs-adi'));
    expect(QuranDressingCatalog.normalizeAyahId('hafs-adi'), equals('mushaf-hafs-adi'));
  });

  test('QvpAyahDress.load loads authentic mushaf ayah markers and draws without error', () async {
    final dress = await QvpAyahDress.load('mushaf-hafs-adi');
    expect(dress, isNotNull);
    expect(dress!.id, equals('mushaf-hafs-adi'));
    expect(dress.picture, isNotNull);

    // Verify drawing on canvas runs without throwing
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 100, 100));
    dress.draw(canvas: canvas, cx: 50, cy: 50, ringHeight: 20);
    final picture = recorder.endRecording();
    expect(picture, isNotNull);

    // Classic / none returns null
    expect(await QvpAyahDress.load('classic'), isNull);
    expect(await QvpAyahDress.load('none'), isNull);
  });

  test('QvpSurahHeaderDress.load loads authentic cartouches and draws without error', () async {
    final headerDress = await QvpSurahHeaderDress.load('mushaf-hafs-adi');
    expect(headerDress, isNotNull);
    expect(headerDress!.picture, isNotNull);

    // Test drawing both light and dark modes
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 345, 550));
    headerDress.draw(canvas: canvas, titleCenterY: 147.15, isDark: false);
    headerDress.draw(canvas: canvas, titleCenterY: 147.15, isDark: true);
    final pic = recorder.endRecording();
    expect(pic, isNotNull);

    // Classic / none returns null
    expect(await QvpSurahHeaderDress.load('classic'), isNull);
    expect(await QvpSurahHeaderDress.load('none'), isNull);
  });

  test('QvpFrameDress.load loads authentic manuscript frames and draws without error', () async {
    final frameDress = await QvpFrameDress.load('mushaf-hafs-adi');
    expect(frameDress, isNotNull);
    expect(frameDress!.picture, isNotNull);
    expect(QvpFrameDress.getCached('mushaf-hafs-adi'), equals(frameDress));
    expect(QvpFrameDress.getCached('madani'), equals(frameDress));

    // Test drawing on canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 360, 600));
    frameDress.draw(canvas: canvas, size: const Size(360, 600), isDark: false);
    frameDress.draw(canvas: canvas, size: const Size(360, 600), isDark: true);
    final pic = recorder.endRecording();
    expect(pic, isNotNull);

    // Minimal / none returns null
    expect(await QvpFrameDress.load('minimal'), isNull);
    expect(await QvpFrameDress.load('none'), isNull);
  });
}
