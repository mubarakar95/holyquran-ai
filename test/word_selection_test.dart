import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_easy_native/core/models/quran_types.dart';
import 'package:quran_easy_native/core/models/qvp_models.dart';
import 'package:quran_easy_native/core/services/local_storage_service.dart';
import 'package:quran_easy_native/providers/service_providers.dart';
import 'package:quran_easy_native/providers/quran_page_provider.dart';

class _FakeLocalStorage extends Fake implements LocalStorageService {
  @override
  int get currentPage => 1;
  @override
  set currentPage(int val) {}
  @override
  bool get showWordByWord => false;
  @override
  set showWordByWord(bool val) {}
  @override
  bool get showTranslation => false;
  @override
  set showTranslation(bool val) {}
  @override
  bool get twoPageMode => false;
  @override
  set twoPageMode(bool val) {}
  @override
  bool get showSwipeWBW => false;
  @override
  set showSwipeWBW(bool val) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QuranPageNotifier updates and clears selectedWord for WBW selection', () {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
      ],
    );
    addTearDown(container.dispose);

    // Initial state has no selected word
    expect(container.read(quranPageProvider).selectedWord, isNull);

    // 1. Select a word
    const testWord = HighlightWord(verseKey: '2:187', wordIndex: 0);
    container.read(quranPageProvider.notifier).setSelectedWord(testWord);

    expect(container.read(quranPageProvider).selectedWord, isNotNull);
    expect(container.read(quranPageProvider).selectedWord!.verseKey, '2:187');
    expect(container.read(quranPageProvider).selectedWord!.wordIndex, 0);

    // 2. Select another word
    const nextWord = HighlightWord(verseKey: '2:187', wordIndex: 1);
    container.read(quranPageProvider.notifier).setSelectedWord(nextWord);

    expect(container.read(quranPageProvider).selectedWord!.wordIndex, 1);

    // 3. Clear selected word
    container.read(quranPageProvider.notifier).setSelectedWord(null);
    expect(container.read(quranPageProvider).selectedWord, isNull);

    // 4. goToPage clears selected word
    container.read(quranPageProvider.notifier).setSelectedWord(testWord);
    expect(container.read(quranPageProvider).selectedWord, isNotNull);

    container.read(quranPageProvider.notifier).goToPage(28);
    expect(container.read(quranPageProvider).selectedWord, isNull);
  });

  test('Simulated drag across Quran page smoothly highlights consecutive words', () async {
    final assetData = await rootBundle.load('assets/data/qvp/001.qvp');
    final bytes = assetData.buffer.asUint8List();
    final page = QvpDecoder.decode(bytes);

    final lineWords = page.words.where((w) => w.lineIndex == page.words.first.lineIndex).toList();
    expect(lineWords.length, greaterThanOrEqualTo(3));

    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
      ],
    );
    addTearDown(container.dispose);

    // 1. Initial touch down at word 0
    final hit0 = page.hitTestWord(lineWords[0].centerX, lineWords[0].centerY);
    expect(hit0, isNotNull);
    container.read(quranPageProvider.notifier).setSelectedWord(
      HighlightWord(verseKey: hit0!.verseKey, wordIndex: hit0.word - 1),
    );
    expect(container.read(quranPageProvider).selectedWord!.wordIndex, hit0.word - 1);

    // 2. Drag update to word 1
    final hit1 = page.hitTestWord(lineWords[1].centerX, lineWords[1].centerY);
    expect(hit1, isNotNull);
    container.read(quranPageProvider.notifier).setSelectedWord(
      HighlightWord(verseKey: hit1!.verseKey, wordIndex: hit1.word - 1),
    );
    expect(container.read(quranPageProvider).selectedWord!.wordIndex, hit1.word - 1);

    // 3. Drag update to word 2
    final hit2 = page.hitTestWord(lineWords[2].centerX, lineWords[2].centerY);
    expect(hit2, isNotNull);
    container.read(quranPageProvider.notifier).setSelectedWord(
      HighlightWord(verseKey: hit2!.verseKey, wordIndex: hit2.word - 1),
    );
    expect(container.read(quranPageProvider).selectedWord!.wordIndex, hit2.word - 1);
  });

  test('hitTestWordForDrag snaps seamlessly between words and across line boundaries without null dropouts', () async {
    final assetData = await rootBundle.load('assets/data/qvp/001.qvp');
    final bytes = assetData.buffer.asUint8List();
    final page = QvpDecoder.decode(bytes);

    expect(page.words.length, greaterThan(10));

    // Test continuous horizontal drag: 30 sample points along the line
    final firstWord = page.words.first;
    final lastWordOnLine = page.words.where((w) => w.lineIndex == firstWord.lineIndex).last;

    for (int step = 0; step <= 20; step++) {
      final t = step / 20.0;
      final px = firstWord.centerX + (lastWordOnLine.centerX - firstWord.centerX) * t;
      // Slight vertical jitter simulating real human finger movement
      final py = firstWord.centerY + (step % 2 == 0 ? 3.0 : -3.0);

      final word = page.hitTestWordForDrag(px, py);
      expect(word, isNotNull, reason: 'Drag at step $step ($px, $py) should snap to a word');
      expect(word!.lineIndex, firstWord.lineIndex);
    }

    // Test dragging across lines (from line 0 to line 1)
    final line0Word = page.words.firstWhere((w) => w.lineIndex == page.words.first.lineIndex);
    final nextLineWords = page.words.where((w) => w.lineIndex > line0Word.lineIndex).toList();
    if (nextLineWords.isNotEmpty) {
      final line1Word = nextLineWords.first;
      // Midpoint between lines
      final midY = (line0Word.centerY + line1Word.centerY) / 2.0;
      final hitMid = page.hitTestWordForDrag(line0Word.centerX, midY);
      expect(hitMid, isNotNull, reason: 'Dragging through the vertical gap between lines must not return null');
    }
  });

  test('Double tap logic: active playing ayah seeks playhead; other double taps toggle full screen', () {
    const activeVerse = '1:2';
    bool seekCalled = false;
    String? soughtVerse;
    int? soughtWord;
    bool fullScreenToggled = false;

    void handleDoubleTap({
      required bool isPlaying,
      required String? currentPlayingAyah,
      required String? tappedVerse,
      required int tappedWordIndex,
    }) {
      seekCalled = false;
      soughtVerse = null;
      soughtWord = null;
      fullScreenToggled = false;

      if (isPlaying && currentPlayingAyah != null && tappedVerse == currentPlayingAyah) {
        seekCalled = true;
        soughtVerse = currentPlayingAyah;
        soughtWord = tappedWordIndex;
      } else {
        fullScreenToggled = true;
      }
    }

    // 1. While playing, double tap on part of the active playing ayah -> seeks to word & plays
    handleDoubleTap(
      isPlaying: true,
      currentPlayingAyah: activeVerse,
      tappedVerse: '1:2',
      tappedWordIndex: 2,
    );
    expect(seekCalled, isTrue);
    expect(soughtVerse, '1:2');
    expect(soughtWord, 2);
    expect(fullScreenToggled, isFalse);

    // 2. While playing, double tap on a DIFFERENT ayah -> triggers full screen toggle
    handleDoubleTap(
      isPlaying: true,
      currentPlayingAyah: activeVerse,
      tappedVerse: '1:3',
      tappedWordIndex: 0,
    );
    expect(seekCalled, isFalse);
    expect(fullScreenToggled, isTrue);

    // 3. While playing, double tap on empty space / margins -> triggers full screen toggle
    handleDoubleTap(
      isPlaying: true,
      currentPlayingAyah: activeVerse,
      tappedVerse: null,
      tappedWordIndex: 0,
    );
    expect(seekCalled, isFalse);
    expect(fullScreenToggled, isTrue);

    // 4. When audio is NOT playing, double tap anywhere -> triggers full screen toggle
    handleDoubleTap(
      isPlaying: false,
      currentPlayingAyah: null,
      tappedVerse: '1:2',
      tappedWordIndex: 1,
    );
    expect(seekCalled, isFalse);
    expect(fullScreenToggled, isTrue);
  });

  test('Highlighted box dragging vs Screen swiping: Only dragging the highlighted box scrubs words; other drags trigger page swipe', () {
    // Simulated state machine
    Rect? activeHighlightRect = const Rect.fromLTRB(100, 200, 180, 240);
    bool isDraggingHighlight = false;
    bool pageSwipedNext = false;
    bool pageSwipedPrev = false;
    bool wordScrubbed = false;

    bool isInsideHighlight(Offset pos, Rect? rect) {
      if (rect == null) return false;
      return rect.inflate(18.0).contains(pos);
    }

    void handlePointerDown(Offset downPos) {
      pageSwipedNext = false;
      pageSwipedPrev = false;
      wordScrubbed = false;
      if (isInsideHighlight(downPos, activeHighlightRect)) {
        isDraggingHighlight = true;
      } else {
        isDraggingHighlight = false;
      }
    }

    void handlePointerMove(Offset movePos) {
      if (isDraggingHighlight) {
        wordScrubbed = true;
      }
    }

    void handlePointerUp(Offset upPos, Offset downPos) {
      final delta = upPos - downPos;
      if (isDraggingHighlight) {
        isDraggingHighlight = false;
      } else {
        if (delta.dx.abs() >= 40.0) {
          // RTL Mushaf navigation:
          // Left swipe (dx < 0) -> next page
          // Right swipe (dx > 0) -> prev page
          if (delta.dx < 0) {
            pageSwipedNext = true;
          } else {
            pageSwipedPrev = true;
          }
        }
      }
    }

    // Scenario A: User puts finger ON the highlighted box (120, 210) and drags to (300, 210)
    handlePointerDown(const Offset(120, 210));
    expect(isDraggingHighlight, isTrue);
    handlePointerMove(const Offset(180, 210));
    expect(wordScrubbed, isTrue);
    handlePointerUp(const Offset(300, 210), const Offset(120, 210));
    expect(pageSwipedNext, isFalse, reason: 'Dragging highlighted box must NOT trigger page swipe');

    // Scenario B: User puts finger OUTSIDE the highlighted box (e.g. at (350, 400)) and swipes left by -80px (finger moves right-to-left)
    handlePointerDown(const Offset(350, 400));
    expect(isDraggingHighlight, isFalse);
    handlePointerMove(const Offset(310, 400));
    expect(wordScrubbed, isFalse, reason: 'Swiping outside highlighted box must NOT scrub words');
    handlePointerUp(const Offset(270, 400), const Offset(350, 400));
    expect(pageSwipedNext, isTrue, reason: 'Left swipe outside highlighted box must turn to next page in RTL');

    // Scenario C: User swipes right from (250, 400) by +70px (finger moves left-to-right)
    handlePointerDown(const Offset(250, 400));
    expect(isDraggingHighlight, isFalse);
    handlePointerMove(const Offset(290, 400));
    expect(wordScrubbed, isFalse);
    handlePointerUp(const Offset(320, 400), const Offset(250, 400));
    expect(pageSwipedPrev, isTrue, reason: 'Right swipe outside highlighted box must turn to previous page in RTL');
  });
}
