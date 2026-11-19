import 'package:flutter_test/flutter_test.dart';
import 'package:quran_easy_native/core/models/qvp_models.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Decodes bundled QVP Page 1 (Al-Fatiha)', () async {
    final assetData = await rootBundle.load('assets/data/qvp/001.qvp');
    final bytes = assetData.buffer.asUint8List();
    final page = QvpDecoder.decode(bytes);

    expect(page.pageNumber, 1);
    expect(page.width, 345.0);
    expect(page.height, 550.0);
    expect(page.words.length, 29);
    expect(page.lines.length, 8);
    expect(page.paths.isNotEmpty, true);

    // Test first word
    final firstWord = page.words.first;
    expect(firstWord.surah, 1);
    expect(firstWord.ayah, 1);
    expect(firstWord.word, 1);
    expect(firstWord.text, 'بِسْمِ');

    // Test hit test inside first word
    final hit = page.hitTestWord(firstWord.centerX, firstWord.centerY);
    expect(hit, isNotNull);
    expect(hit!.verseKey, '1:1');
    expect(hit.word, 1);

    // Test tap slightly above letters (e.g. harakah / tashkeel touch)
    final hitAbove = page.hitTestWord(firstWord.centerX, firstWord.y0 - 2.5);
    expect(hitAbove, isNotNull);
    expect(hitAbove!.verseKey, '1:1');
    expect(hitAbove.word, 1);

    // Test tap slightly below letters
    final hitBelow = page.hitTestWord(firstWord.centerX, firstWord.y1 + 2.5);
    expect(hitBelow, isNotNull);
    expect(hitBelow!.verseKey, '1:1');
    expect(hitBelow.word, 1);

    // Test tap in whitespace gap between words on line 1: must hit a line 1 word, never line 2
    final word2 = page.words[1];
    final gapX = (firstWord.x0 + word2.x1) / 2.0;
    final hitGap = page.hitTestWord(gapX, firstWord.centerY);
    expect(hitGap, isNotNull);
    expect(hitGap!.lineIndex, firstWord.lineIndex);

    // Test tap far away in outer margins returns null
    final hitOutside = page.hitTestWord(-50.0, -50.0);
    expect(hitOutside, isNull);
  });

  test('Decodes bundled QVP Page 2 (Al-Baqarah start)', () async {
    final assetData = await rootBundle.load('assets/data/qvp/002.qvp');
    final bytes = assetData.buffer.asUint8List();
    final page = QvpDecoder.decode(bytes);

    expect(page.pageNumber, 2);
    expect(page.words.isNotEmpty, true);
    expect(page.words.first.surah, 2);
    expect(page.words.first.ayah, 1);
  });
}
