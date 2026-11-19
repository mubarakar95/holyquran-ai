import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quran_types.dart';
import '../../core/models/qvp_models.dart';
import '../../core/models/quran_dressing_catalog.dart';
import '../../core/models/qvp_dress.dart';
import '../../core/models/qcf4_models.dart';
import '../../core/utils/wbw_bundle_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/quran_page_provider.dart';
import '../../providers/settings_provider.dart';
import 'madani_frame_widget.dart';

class MushafPageView extends ConsumerStatefulWidget {
  final int pageNumber;
  final bool isSinglePage;

  const MushafPageView({
    super.key,
    required this.pageNumber,
    this.isSinglePage = true,
  });

  @override
  ConsumerState<MushafPageView> createState() => _MushafPageViewState();
}

class _FloatingMeaningData {
  final Offset screenWordCenter;
  final String meaning;
  final int hoverFontSize;

  const _FloatingMeaningData({
    required this.screenWordCenter,
    required this.meaning,
    required this.hoverFontSize,
  });
}

class _FloatingMeaningOverlay extends StatelessWidget {
  final ValueNotifier<_FloatingMeaningData?> dataNotifier;
  final VoidCallback onDismiss;

  const _FloatingMeaningOverlay({
    required this.dataNotifier,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_FloatingMeaningData?>(
      valueListenable: dataNotifier,
      builder: (context, data, _) {
        if (data == null || data.meaning.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        final screenSize = MediaQuery.of(context).size;
        final topPadding = MediaQuery.of(context).padding.top;
        final double screenW = screenSize.width;
        final double screenH = screenSize.height;

        final maxTooltipWidth = (screenW - 32.0).clamp(100.0, 480.0);

        final tp = TextPainter(
          text: TextSpan(
            text: data.meaning,
            style: TextStyle(
              fontSize: data.hoverFontSize.toDouble(),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxTooltipWidth - 28.0);

        final estimatedWidth = tp.width + 32.0;
        final double left = (data.screenWordCenter.dx - estimatedWidth / 2.0).clamp(
          16.0,
          math.max(16.0, screenW - estimatedWidth - 16.0),
        );

        final double tooltipHeight = tp.height + 16.0;
        final double extraMultilineClearance =
            tp.height > 24.0 ? (tp.height - 20.0) * 0.9 + 10.0 : 0.0;
        final double idealTopAbove =
            data.screenWordCenter.dy - tooltipHeight - 48.0 - extraMultilineClearance;

        final bool isNearTop = idealTopAbove < (topPadding + 14.0);
        final double top = isNearTop
            ? (data.screenWordCenter.dy + 38.0)
            : idealTopAbove.clamp(topPadding + 10.0, screenH - tooltipHeight - 16.0);

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: math.max(120.0, screenW - left - 16.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      data.meaning,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: data.hoverFontSize.toDouble(),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MushafPageViewState extends ConsumerState<MushafPageView> {
  OverlayEntry? _tooltipOverlay;
  final ValueNotifier<_FloatingMeaningData?> _tooltipNotifier =
      ValueNotifier<_FloatingMeaningData?>(null);
  final ValueNotifier<HighlightWord?> _selectedWordNotifier =
      ValueNotifier<HighlightWord?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureOverlayMounted();
    });
  }

  void _ensureOverlayMounted() {
    if (_tooltipOverlay == null && mounted) {
      final overlay = Overlay.of(context);
      _tooltipOverlay = OverlayEntry(
        builder: (context) => _FloatingMeaningOverlay(
          dataNotifier: _tooltipNotifier,
          onDismiss: () => _dismissTooltip(clearSelection: true),
        ),
      );
      overlay.insert(_tooltipOverlay!);
    }
  }

  void _dismissTooltip({bool clearSelection = true}) {
    // Keep OverlayEntry permanently mounted for 0ms synchronous latency on subsequent taps.
    // Simply set notifier to null so it renders SizedBox.shrink().
    _tooltipNotifier.value = null;
    if (clearSelection) {
      _selectedWordNotifier.value = null;
      ref.read(quranPageProvider.notifier).setSelectedWord(null);
    }
  }

  void _onWordSelected(
    HighlightWord? highlightWord,
    Offset screenCenter,
    String meaning,
    int hoverFontSize,
  ) {
    _selectedWordNotifier.value = highlightWord;
    ref.read(quranPageProvider.notifier).setSelectedWord(highlightWord);
    _showWordTooltipAt(
      screenCenter,
      meaning,
      hoverFontSize,
    );
  }

  void _showWordTooltipAt(
    Offset screenWordCenter,
    String meaning,
    int hoverFontSize,
  ) {
    if (!mounted) return;
    if (meaning.trim().isEmpty) {
      _tooltipNotifier.value = null;
      return;
    }

    final data = _FloatingMeaningData(
      screenWordCenter: screenWordCenter,
      meaning: meaning,
      hoverFontSize: hoverFontSize,
    );

    _ensureOverlayMounted();
    _tooltipNotifier.value = data;
  }

  @override
  void didUpdateWidget(covariant MushafPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _tooltipNotifier.value = null;
      _selectedWordNotifier.value = null;
      Future.microtask(() {
        if (mounted) {
          ref.read(quranPageProvider.notifier).setSelectedWord(null);
        }
      });
    }
  }

  @override
  void dispose() {
    _tooltipNotifier.value = null;
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
    _tooltipNotifier.dispose();
    _selectedWordNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTranslation = ref.watch(quranPageProvider.select((s) => s.showTranslation));
    final showWordByWord = ref.watch(quranPageProvider.select((s) => s.showWordByWord));
    final twoPageMode = ref.watch(quranPageProvider.select((s) => s.twoPageMode));
    final simpleMode = ref.watch(quranPageProvider.select((s) => s.simpleMode));
    final highlightVerseKey = ref.watch(quranPageProvider.select((s) => s.highlightVerseKey));
    final highlightWord = ref.watch(quranPageProvider.select((s) => s.highlightWord));
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    final pageState = QuranPageState(
      currentPage: widget.pageNumber,
      showTranslation: showTranslation,
      showWordByWord: showWordByWord,
      twoPageMode: twoPageMode,
      simpleMode: simpleMode,
      highlightVerseKey: highlightVerseKey,
      highlightWord: highlightWord,
      selectedWord: _selectedWordNotifier.value,
    );

    final qvpAsync = ref.watch(qvpPageProvider(widget.pageNumber));
    final ayahDressAsync = ref.watch(ayahDressProvider);
    final dress = ayahDressAsync.value;
    final surahHeaderDressAsync = ref.watch(surahHeaderDressProvider);
    final surahHeaderDress = surahHeaderDressAsync.value;
    final frameDressAsync = ref.watch(frameDressProvider);
    final frameDressData = frameDressAsync.value;
    final wbwAsync = ref.watch(wbwDataProvider);
    final uthmaniAsync = ref.watch(uthmaniPageProvider(widget.pageNumber));
    final translationAsync = ref.watch(translationPageProvider(widget.pageNumber));

    return qvpAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFC59B27), strokeWidth: 2),
      ),
      error: (err, stack) {
        debugPrint('QVP MushafPageView error for page ${widget.pageNumber}: $err\n$stack');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Failed to load Quran page ${widget.pageNumber}: $err',
              style: TextStyle(color: colors.muted),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      data: (pageData) {
        final int surahNum = pageData.words.isNotEmpty
            ? pageData.words.first.surah
            : (pageData.decorations.isNotEmpty ? pageData.decorations.first.surah : 1);
        final surahTitle = getVocalizedSurahTitle(surahNum);

        final juzObj = JUZ_DATA.reversed.firstWhere(
          (j) => widget.pageNumber >= j.startPage,
          orElse: () => JUZ_DATA.first,
        );
        final juzTitle = juzObj.name;

        final wbwMap = wbwAsync.value ?? {};
        final translationMap = translationAsync.value ?? {};

        // If Ayah-by-Ayah Translation mode is active
        if (pageState.showTranslation && !pageState.showWordByWord && uthmaniAsync.hasValue) {
          return _buildAyahByAyahView(
            context,
            uthmaniAsync.value!,
            translationMap,
            wbwMap,
            pageState,
            settings,
            colors,
          );
        }

        return MadaniFrameWidget(
          pageNumber: widget.pageNumber,
          surahTitle: surahTitle,
          juzTitle: juzTitle,
          isSinglePage: widget.isSinglePage,
          themeMode: settings.theme,
          frameDress: settings.frameDress,
          frameDressData: frameDressData,
          onBackgroundTap: () => _dismissTooltip(clearSelection: true),
          builder: (context, frameWidth, frameHeight) {
              final frameMeta = QuranDressingCatalog.getFrameMeta(settings.frameDress);
              final double slotWidth = frameWidth *
                  (1.0 - frameMeta.slotInsetLeftRatio - frameMeta.slotInsetRightRatio);
              final double slotHeight = frameHeight *
                  (1.0 - frameMeta.slotInsetTopRatio - frameMeta.slotInsetBottomRatio);

              return SizedBox(
                width: slotWidth,
                height: slotHeight,
                child: _QvpMushafCanvas(
                  page: pageData,
                  dress: dress,
                  surahHeaderDress: surahHeaderDress,
                  pageState: pageState,
                  selectedWordNotifier: _selectedWordNotifier,
                  settings: settings,
                  colors: colors,
                  wbwMap: wbwMap,
                  isPlaying: ref.watch(audioPlayerProvider.select((s) => s.isPlaying)),
                  activePlayingVerseKey: ref.watch(audioPlayerProvider.select((s) => s.currentVerseKey)) ?? pageState.highlightVerseKey,
                  onWordSelect: (highlightWord, screenCenter, meaning) {
                    _onWordSelected(
                      highlightWord,
                      screenCenter,
                      meaning,
                      settings.hoverFontSize,
                    );
                  },
                  onPageSwipe: (isNext) {
                    _dismissTooltip(clearSelection: true);
                    if (isNext) {
                      ref.read(quranPageProvider.notifier).nextPage();
                    } else {
                      ref.read(quranPageProvider.notifier).prevPage();
                    }
                  },
                  onWordDoubleTap: (verseKey, wordIndex) {
                    _dismissTooltip(clearSelection: true);
                    ref.read(audioPlayerProvider.notifier).seekToWord(verseKey, wordIndex);
                  },
                  onWordSeek: (verseKey, wordIndex) {
                    ref.read(audioPlayerProvider.notifier).seekToWord(verseKey, wordIndex);
                  },
                  onAyahMarkerDoubleTap: (verseKey) {
                    _dismissTooltip(clearSelection: true);
                    ref.read(audioPlayerProvider.notifier).seekToWord(verseKey, 0);
                  },
                  onFullScreenToggle: () {
                    _dismissTooltip(clearSelection: true);
                    ref.read(quranPageProvider.notifier).toggleFullScreen();
                  },
                  onEmptyTap: () {
                    _dismissTooltip(clearSelection: true);
                  },
                  onWordLongPress: (word) {
                    ref.read(quranPageProvider.notifier).openAyahSheet(word.verseKey);
                  },
                  onAyahMarkerTap: (verseKey) {
                    _dismissTooltip(clearSelection: true);
                    final isPlaying = ref.read(audioPlayerProvider).isPlaying;
                    final currentPlaying = ref.read(audioPlayerProvider).currentVerseKey;
                    final highlightedKey = ref.read(quranPageProvider).highlightVerseKey;
                    if (isPlaying && (currentPlaying == verseKey || highlightedKey == verseKey)) {
                      ref.read(audioPlayerProvider.notifier).pause();
                      ref.read(quranPageProvider.notifier).setHighlightVerseKey(null);
                    } else {
                      ref.read(quranPageProvider.notifier).setHighlightVerseKey(verseKey);
                      ref.read(audioPlayerProvider.notifier).playAyah(verseKey);
                    }
                  },
                ),
              );
            },
          );
        },
    );
  }

  Widget _buildAyahByAyahView(
    BuildContext context,
    PageData uthmani,
    Map<String, String> translationMap,
    Map<String, List<String>> wbwMap,
    QuranPageState pageState,
    SettingsState settings,
    AppColors colors,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: uthmani.ayahs.length,
      separatorBuilder: (_, __) => Divider(color: colors.border, height: 24),
      itemBuilder: (context, idx) {
        final ayah = uthmani.ayahs[idx];
        final translation = translationMap[ayah.verseKey] ?? '';
        final isHighlighted = pageState.highlightVerseKey == ayah.verseKey;

        return InkWell(
          onTap: () {
            ref.read(quranPageProvider.notifier).openAyahSheet(ayah.verseKey);
          },
          onDoubleTap: () {
            final isPlaying = ref.read(audioPlayerProvider).isPlaying;
            final activeVerse = ref.read(audioPlayerProvider).currentVerseKey ??
                ref.read(quranPageProvider).highlightVerseKey;
            if (isPlaying && activeVerse == ayah.verseKey) {
              ref.read(audioPlayerProvider.notifier).seekToWord(ayah.verseKey, 0);
            } else {
              ref.read(quranPageProvider.notifier).toggleFullScreen();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? const Color(0xFFFDE68A).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        ayah.verseKey,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.muted,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      color: colors.muted,
                      onPressed: () {
                        ref.read(quranPageProvider.notifier).openAyahSheet(ayah.verseKey);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ayah.text,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: (22 * (settings.arFontSize / 100)),
                    color: colors.foreground,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                if (translation.isNotEmpty)
                  Text(
                    translation,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: (14 * (settings.mlFontSize / 100)),
                      color: colors.foreground.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QvpMushafCanvas extends StatefulWidget {
  final QvpDecodedPage page;
  final QvpAyahDress? dress;
  final QvpSurahHeaderDress? surahHeaderDress;
  final QuranPageState pageState;
  final ValueNotifier<HighlightWord?> selectedWordNotifier;
  final SettingsState settings;
  final AppColors colors;
  final Map<String, List<String>> wbwMap;
  final bool isPlaying;
  final String? activePlayingVerseKey;
  final void Function(HighlightWord highlightWord, Offset screenCenter, String meaning) onWordSelect;
  final void Function(String verseKey, int wordIndex)? onWordDoubleTap;
  final void Function(String verseKey, int wordIndex)? onWordSeek;
  final void Function(String verseKey)? onAyahMarkerDoubleTap;
  final VoidCallback? onFullScreenToggle;
  final void Function(QvpWordData word) onWordLongPress;
  final void Function(String verseKey) onAyahMarkerTap;
  final VoidCallback? onEmptyTap;
  final void Function(bool isNext)? onPageSwipe;

  const _QvpMushafCanvas({
    required this.page,
    this.dress,
    this.surahHeaderDress,
    required this.pageState,
    required this.selectedWordNotifier,
    required this.settings,
    required this.colors,
    required this.wbwMap,
    this.isPlaying = false,
    this.activePlayingVerseKey,
    required this.onWordSelect,
    this.onWordDoubleTap,
    this.onWordSeek,
    this.onAyahMarkerDoubleTap,
    this.onFullScreenToggle,
    required this.onWordLongPress,
    required this.onAyahMarkerTap,
    this.onEmptyTap,
    this.onPageSwipe,
  });

  @override
  State<_QvpMushafCanvas> createState() => _QvpMushafCanvasState();
}

class _QvpMushafCanvasState extends State<_QvpMushafCanvas> {
  Rect? _activeHighlightRect;
  bool _isDraggingHighlight = false;
  bool _wasAlreadySelectedOnDown = false;
  String? _tappedAyahMarkerKey;
  QvpWordData? _pendingTappedWord;
  WbwBundle? _pendingBundle;
  QvpWordData? _lastSelectedWord;
  Offset? _downPos;
  Offset? _lastTapPos;
  DateTime? _lastTapTime;
  Timer? _longPressTimer;

  @override
  void didUpdateWidget(covariant _QvpMushafCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _activeHighlightRect = null;
      _lastSelectedWord = null;
      _isDraggingHighlight = false;
      _longPressTimer?.cancel();
      _longPressTimer = null;
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    super.dispose();
  }

  Rect? _calculateHighlightRect(
    HighlightWord hlWord,
    double offsetX,
    double offsetY,
    double scale,
    double shiftX,
  ) {
    final indices = hlWord.wordIndices ?? [hlWord.wordIndex];
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    bool found = false;
    for (final w in widget.page.words) {
      if (w.verseKey == hlWord.verseKey && indices.contains(w.word - 1)) {
        found = true;
        if (w.x0 < minX) minX = w.x0;
        if (w.x1 > maxX) maxX = w.x1;
        if (w.y0 < minY) minY = w.y0;
        if (w.y1 > maxY) maxY = w.y1;
      }
    }

    if (!found) return null;

    final left = (minX - 1.8 + shiftX) * scale + offsetX;
    final right = (maxX + 1.8 + shiftX) * scale + offsetX;
    final top = (minY - 1.5) * scale + offsetY;
    final bottom = (maxY + 1.5) * scale + offsetY;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _isInsideHighlight(Offset local, Rect? highlightRect) {
    if (highlightRect == null) return false;
    return highlightRect.inflate(18.0).contains(local);
  }

  void _selectWordAt(
    QvpWordData word,
    WbwBundle bundle,
    RenderBox box,
    double offsetX,
    double offsetY,
    double scale,
    double shiftX,
  ) {
    _lastSelectedWord = word;

    final origin = box.localToGlobal(Offset.zero);

    // Find all words in this bundle present on the current page
    final bundleWords = widget.page.words
        .where((w) =>
            w.verseKey == word.verseKey &&
            bundle.wordIndices.contains(w.word - 1))
        .toList();

    // Group by the word's lineIndex for accurate horizontal centering
    final sameLineWords =
        bundleWords.where((w) => w.lineIndex == word.lineIndex).toList();
    final wordsToCenter = sameLineWords.isNotEmpty
        ? sameLineWords
        : (bundleWords.isNotEmpty ? bundleWords : [word]);

    double minX = wordsToCenter.first.x0;
    double maxX = wordsToCenter.first.x1;
    for (final bw in wordsToCenter) {
      if (bw.x0 < minX) minX = bw.x0;
      if (bw.x1 > maxX) maxX = bw.x1;
    }
    final bundleCenterX = (minX + maxX) / 2.0;
    final bundleCenterY = word.centerY;

    final screenCenter = Offset(
      origin.dx + offsetX + (bundleCenterX + shiftX) * scale,
      origin.dy + offsetY + bundleCenterY * scale,
    );

    final hl = HighlightWord(
      verseKey: word.verseKey,
      wordIndex: bundle.headIndex,
      wordIndices: bundle.wordIndices,
      bundle: bundle.isBundle,
    );

    _activeHighlightRect = _calculateHighlightRect(hl, offsetX, offsetY, scale, shiftX);

    widget.onWordSelect(
      hl,
      screenCenter,
      bundle.meaning,
    );
  }

  void _onPointerDown(
    PointerDownEvent event,
    RenderBox box,
    double offsetX,
    double offsetY,
    double scale,
    double shiftX,
  ) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _pendingTappedWord = null;
    _pendingBundle = null;

    final local = event.localPosition;
    _downPos = local;

    final px = (local.dx - (offsetX + shiftX * scale)) / scale;
    final py = (local.dy - offsetY) / scale;

    // 1. Check if touching the active highlighted box
    final isTouchOnHighlight = _isInsideHighlight(local, _activeHighlightRect);

    // 2. Check ayah marker
    final dec = widget.page.hitTestDecoration(px, py);
    if (dec != null && dec.ayah > 0) {
      _tappedAyahMarkerKey = '${dec.surah}:${dec.ayah}';
      _isDraggingHighlight = false;
      return;
    }
    _tappedAyahMarkerKey = null;

    if (isTouchOnHighlight) {
      // User touched the highlighted box directly -> allow dragging that box!
      _isDraggingHighlight = true;
      _wasAlreadySelectedOnDown = true;
      return;
    }

    _isDraggingHighlight = false;

    // 3. Check word hit test
    final word = widget.page.hitTestWord(px, py);
    if (word != null) {
      final wbwList = widget.wbwMap[word.verseKey];
      final tappedIndex = word.word - 1;
      final bundle = WbwBundleHelper.resolveBundle(wbwList, tappedIndex);

      final current = widget.selectedWordNotifier.value;
      final isSame = current != null &&
          current.verseKey == word.verseKey &&
          (current.wordIndex == bundle.headIndex ||
              (current.wordIndices != null &&
                  current.wordIndices!.contains(word.word - 1)));

      _wasAlreadySelectedOnDown = isSame;
      _pendingTappedWord = word;
      _pendingBundle = bundle;

      _longPressTimer = Timer(const Duration(milliseconds: 550), () {
        if (mounted && _downPos != null) {
          widget.onWordLongPress(word);
        }
      });
    } else {
      // Empty space touched
      _wasAlreadySelectedOnDown = false;
    }
  }

  void _onPointerMove(
    PointerMoveEvent event,
    RenderBox box,
    double offsetX,
    double offsetY,
    double scale,
    double shiftX,
  ) {
    final local = event.localPosition;
    if (_downPos != null && (local - _downPos!).distance > 8.0) {
      _longPressTimer?.cancel();
      _longPressTimer = null;
    }

    if (!_isDraggingHighlight) {
      // User is not dragging an active highlighted box.
      // Swipe/drag across screen will be treated as page turn in pointer up.
      // Do NOT scrub words.
      return;
    }

    final px = (local.dx - (offsetX + shiftX * scale)) / scale;
    final py = (local.dy - offsetY) / scale;

    final word = widget.page.hitTestWordForDrag(px, py);
    if (word != null) {
      final wbwList = widget.wbwMap[word.verseKey];
      final tappedIndex = word.word - 1;
      final bundle = WbwBundleHelper.resolveBundle(wbwList, tappedIndex);

      final current = widget.selectedWordNotifier.value;
      final isSame = current != null &&
          current.verseKey == word.verseKey &&
          (current.wordIndex == bundle.headIndex ||
              (current.wordIndices != null &&
                  current.wordIndices!.contains(word.word - 1)));

      if (!isSame) {
        _selectWordAt(word, bundle, box, offsetX, offsetY, scale, shiftX);
      }
    }
  }

  void _onPointerUp(
    PointerUpEvent event,
    RenderBox box,
    double offsetX,
    double offsetY,
    double scale,
    double shiftX,
  ) {
    _longPressTimer?.cancel();
    _longPressTimer = null;

    final local = event.localPosition;
    final downPos = _downPos ?? local;
    final delta = local - downPos;
    final isDrag = delta.distance >= 12.0;

    if (_isDraggingHighlight) {
      _isDraggingHighlight = false;
      if (!isDrag) {
        _handleTapRelease(box, offsetX, offsetY, scale, shiftX, local, isTappedWord: true);
      }
      return;
    }

    // Gesture did NOT start on highlighted box
    if (isDrag) {
      final dx = delta.dx;
      if (dx.abs() >= 40.0) {
        // RTL Mushaf navigation:
        // Dragging Left (dx < 0, finger moves right to left): flip forward to nextPage
        // Dragging Right (dx > 0, finger moves left to right): flip back to prevPage
        widget.onPageSwipe?.call(dx < 0);
      }
      _pendingTappedWord = null;
      _pendingBundle = null;
    } else {
      _handleTapRelease(box, offsetX, offsetY, scale, shiftX, local, isTappedWord: _pendingTappedWord != null);
    }
  }

  void _handleTapRelease(
    RenderBox box,
    double offsetX,
    double offsetY,
    double scale,
    double shiftX,
    Offset local, {
    required bool isTappedWord,
  }) {
    final now = DateTime.now();
    final isDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350) &&
        _lastTapPos != null &&
        (local - _lastTapPos!).distance < 36.0;

    if (isDoubleTap) {
      _lastTapTime = null;
      _lastTapPos = null;

      final isPlaying = widget.isPlaying;
      final activeVerse = widget.activePlayingVerseKey;

      if (_tappedAyahMarkerKey != null) {
        if (isPlaying && activeVerse != null && _tappedAyahMarkerKey == activeVerse) {
          widget.onAyahMarkerDoubleTap?.call(_tappedAyahMarkerKey!);
        } else {
          widget.onFullScreenToggle?.call();
        }
      } else if (_lastSelectedWord != null && isTappedWord) {
        if (isPlaying && activeVerse != null && _lastSelectedWord!.verseKey == activeVerse) {
          widget.onWordDoubleTap?.call(
            _lastSelectedWord!.verseKey,
            _lastSelectedWord!.word - 1,
          );
        } else {
          widget.onFullScreenToggle?.call();
        }
      } else {
        widget.onFullScreenToggle?.call();
      }
      _tappedAyahMarkerKey = null;
      _pendingTappedWord = null;
      _pendingBundle = null;
      return;
    }

    _lastTapTime = now;
    _lastTapPos = local;

    if (_tappedAyahMarkerKey != null) {
      widget.onAyahMarkerTap(_tappedAyahMarkerKey!);
      _tappedAyahMarkerKey = null;
      _pendingTappedWord = null;
      _pendingBundle = null;
      return;
    }

    if (isTappedWord && _pendingTappedWord != null && _pendingBundle != null) {
      final word = _pendingTappedWord!;
      final bundle = _pendingBundle!;

      if (_wasAlreadySelectedOnDown) {
        // Tapped already selected word without dragging -> toggle off
        _activeHighlightRect = null;
        widget.onEmptyTap?.call();
      } else {
        // Select word and show tooltip
        _selectWordAt(word, bundle, box, offsetX, offsetY, scale, shiftX);

        // If audio is currently playing -> seek audio immediately to this word!
        if (widget.isPlaying) {
          widget.onWordSeek?.call(word.verseKey, word.word - 1);
        }
      }
      _pendingTappedWord = null;
      _pendingBundle = null;
    } else {
      // Tapped empty space -> dismiss selection
      _activeHighlightRect = null;
      widget.onEmptyTap?.call();
      _pendingTappedWord = null;
      _pendingBundle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Snug inner alignment with the inner rule lines of the ornate frame (maximizes font scale)
        const double gapX = 0.5;
        const double gapY = 0.8;
        final double targetW = widget.page.width + 2 * gapX;
        final double targetH = widget.page.height + 2 * gapY;

        final scaleX = constraints.maxWidth / targetW;
        final scaleY = constraints.maxHeight / targetH;
        final scale = math.min(scaleX, scaleY);

        final offsetX = (constraints.maxWidth - widget.page.width * scale) / 2.0;
        final offsetY = (constraints.maxHeight - widget.page.height * scale) / 2.0;

        // Optical centering shift: ensures equal side paddings on left and right
        final double shiftX = (widget.page.lines.length >= 12)
            ? ((widget.page.width / 2.0) - widget.page.inkCenterX).clamp(-3.0, 3.0)
            : 0.0;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              _onPointerDown(event, box, offsetX, offsetY, scale, shiftX);
            }
          },
          onPointerMove: (event) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              _onPointerMove(event, box, offsetX, offsetY, scale, shiftX);
            }
          },
          onPointerUp: (event) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              _onPointerUp(event, box, offsetX, offsetY, scale, shiftX);
            }
          },
          onPointerCancel: (event) {
            _longPressTimer?.cancel();
            _longPressTimer = null;
            _isDraggingHighlight = false;
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _QvpPagePainter(
              page: widget.page,
              dress: widget.dress,
              surahHeaderDress: widget.surahHeaderDress,
              pageState: widget.pageState,
              selectedWordListenable: widget.selectedWordNotifier,
              settings: widget.settings,
              colors: widget.colors,
              wbwMap: widget.wbwMap,
              shiftX: shiftX,
            ),
          ),
        );
      },
    );
  }
}

class _QvpPagePainter extends CustomPainter {
  final QvpDecodedPage page;
  final QvpAyahDress? dress;
  final QvpSurahHeaderDress? surahHeaderDress;
  final QuranPageState pageState;
  final ValueNotifier<HighlightWord?>? selectedWordListenable;
  final SettingsState settings;
  final AppColors colors;
  final Map<String, List<String>> wbwMap;
  final double shiftX;

  _QvpPagePainter({
    required this.page,
    this.dress,
    this.surahHeaderDress,
    required this.pageState,
    this.selectedWordListenable,
    required this.settings,
    required this.colors,
    required this.wbwMap,
    this.shiftX = 0.0,
  }) : super(repaint: selectedWordListenable);

  @override
  void paint(Canvas canvas, Size size) {
    if (page.width <= 0 || page.height <= 0) return;

    const double gapX = 0.5;
    const double gapY = 0.8;
    final double targetW = page.width + 2 * gapX;
    final double targetH = page.height + 2 * gapY;

    final scaleX = size.width / targetW;
    final scaleY = size.height / targetH;
    final scale = math.min(scaleX, scaleY);
    final offsetX = (size.width - page.width * scale) / 2.0;
    final offsetY = (size.height - page.height * scale) / 2.0;

    canvas.save();
    canvas.translate(offsetX + shiftX * scale, offsetY);
    canvas.scale(scale, scale);

    // Build a map of line vertical bounds: lineIndex -> (minY, maxY)
    // Ensures all words on the same line have the exact same highlight height disregarding individual glyph shape
    final lineBounds = <int, ({double minY, double maxY})>{};
    for (final w in page.words) {
      final existing = lineBounds[w.lineIndex];
      if (existing == null) {
        lineBounds[w.lineIndex] = (minY: w.y0, maxY: w.y1);
      } else {
        lineBounds[w.lineIndex] = (
          minY: math.min(existing.minY, w.y0),
          maxY: math.max(existing.maxY, w.y1),
        );
      }
    }

    // 1. Ayah Highlight Background
    final hlVerse = pageState.highlightVerseKey;
    if (hlVerse != null) {
      final ayahHighlightPaint = Paint()
        ..color = settings.theme == AppThemeMode.dark
            ? const Color(0xFFFDE68A).withValues(alpha: 0.20)
            : const Color(0xFFFDE68A).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;

      for (final word in page.words) {
        if (word.verseKey == hlVerse) {
          final bounds = lineBounds[word.lineIndex];
          final minY = bounds?.minY ?? word.y0;
          final maxY = bounds?.maxY ?? word.y1;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(word.x0 - 1.0, minY - 1.2, word.x1 + 1.0, maxY + 1.2),
              const Radius.circular(2.5),
            ),
            ayahHighlightPaint,
          );
        }
      }
    }

    // 2. Active Word Highlight Background (Recitation Audio Sync)
    final hlWord = pageState.highlightWord;
    if (hlWord != null) {
      final isBundle = hlWord.bundle;
      final isDark = settings.theme == AppThemeMode.dark;

      final wordHighlightPaint = Paint()
        ..color = isBundle
            ? (isDark
                ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                : const Color(0xFF3B82F6).withValues(alpha: 0.25))
            : const Color(0xFFF59E0B).withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;

      final wordBorderPaint = isBundle
          ? (Paint()
            ..color = isDark
                ? const Color(0xFF60A5FA).withValues(alpha: 0.65)
                : const Color(0xFF2563EB).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1.2 / scale).clamp(0.6, 1.8))
          : null;

      final indices = hlWord.wordIndices ?? [hlWord.wordIndex];

      final lineGroups = <int, List<QvpWordData>>{};
      for (final w in page.words) {
        if (w.verseKey == hlWord.verseKey && indices.contains(w.word - 1)) {
          lineGroups.putIfAbsent(w.lineIndex, () => []).add(w);
        }
      }

      for (final wordsOnLine in lineGroups.values) {
        double minX = wordsOnLine.first.x0;
        double maxX = wordsOnLine.first.x1;

        for (final w in wordsOnLine) {
          if (w.x0 < minX) minX = w.x0;
          if (w.x1 > maxX) maxX = w.x1;
        }

        final bounds = lineBounds[wordsOnLine.first.lineIndex];
        final minY = bounds?.minY ?? wordsOnLine.first.y0;
        final maxY = bounds?.maxY ?? wordsOnLine.first.y1;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(minX - 1.8, minY - 1.5, maxX + 1.8, maxY + 1.5),
          const Radius.circular(3.5),
        );
        canvas.drawRRect(rrect, wordHighlightPaint);
        if (wordBorderPaint != null) {
          canvas.drawRRect(rrect, wordBorderPaint);
        }
      }
    }

    // 2b. Selected Word Highlight Background (Manual Word-by-Word Selection)
    final selWord = selectedWordListenable?.value ?? pageState.selectedWord;
    if (selWord != null) {
      final isDark = settings.theme == AppThemeMode.dark;
      final selBgPaint = Paint()
        ..color = isDark
            ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
            : const Color(0xFFFDE68A).withValues(alpha: 0.70)
        ..style = PaintingStyle.fill;

      final selBorderPaint = Paint()
        ..color = isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.90)
            : const Color(0xFFD97706).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.2 / scale).clamp(0.6, 2.0);

      final indices = selWord.wordIndices ?? [selWord.wordIndex];
      // Group words by lineIndex so contiguous bundle words on the same line
      // form a unified, continuous golden capsule
      final lineGroups = <int, List<QvpWordData>>{};
      for (final w in page.words) {
        if (w.verseKey == selWord.verseKey && indices.contains(w.word - 1)) {
          lineGroups.putIfAbsent(w.lineIndex, () => []).add(w);
        }
      }

      for (final wordsOnLine in lineGroups.values) {
        double minX = wordsOnLine.first.x0;
        double maxX = wordsOnLine.first.x1;

        for (final w in wordsOnLine) {
          if (w.x0 < minX) minX = w.x0;
          if (w.x1 > maxX) maxX = w.x1;
        }

        // Use line-level vertical bounds so every word on this line has the exact same top & bottom height
        final bounds = lineBounds[wordsOnLine.first.lineIndex];
        final minY = bounds?.minY ?? wordsOnLine.first.y0;
        final maxY = bounds?.maxY ?? wordsOnLine.first.y1;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(minX - 1.8, minY - 1.5, maxX + 1.8, maxY + 1.5),
          const Radius.circular(3.5),
        );
        canvas.drawRRect(rrect, selBgPaint);
        canvas.drawRRect(rrect, selBorderPaint);
      }
    }

    // Identify native ring paths to replace if custom dress is active
    final replacedRingPaths = <int>{};
    if (dress != null && dress!.picture != null) {
      for (final dec in page.decorations) {
        if (dec.decoration == 0 && dec.nPaths >= 2) {
          final p0 = page.paths[dec.firstPath];
          if (p0.kind == 3) {
            replacedRingPaths.add(dec.firstPath);
          }
        }
      }
    }

    // 3. Draw Custom Ayah Marker & Surah Header Dress Ornaments
    if (dress != null && dress!.picture != null) {
      for (final dec in page.decorations) {
        if (dec.decoration == 0 && dec.nPaths >= 2) {
          final ringPath = page.paths[dec.firstPath];
          final numeralPath = page.paths[dec.firstPath + 1];
          final cx = (numeralPath.box[0] + numeralPath.box[2]) / 2.0;
          final cy = (numeralPath.box[1] + numeralPath.box[3]) / 2.0;
          final ringH = ringPath.box[3] - ringPath.box[1];
          dress!.draw(
            canvas: canvas,
            cx: cx,
            cy: cy,
            ringHeight: ringH,
          );
        }
      }
    }

    if (surahHeaderDress != null) {
      for (final dec in page.decorations) {
        if (dec.decoration == 1) { // SURAH_NAME
          final box = dec.box;
          final titleCenterY = box != null
              ? (box[1] + box[3]) / 2.0
              : (page.paths[dec.firstPath].box[1] + page.paths[dec.firstPath].box[3]) / 2.0;
          surahHeaderDress!.draw(
            canvas: canvas,
            titleCenterY: titleCenterY,
            isDark: settings.theme == AppThemeMode.dark,
            pageWidth: page.width,
          );
        }
      }
    }

    // 4. Draw Vector Paths (Ink and Ornaments)
    final inkPaint = Paint()
      ..color = colors.foreground
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final decPaint = Paint()
      ..color = colors.accent
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final decIndices = page.decorationPathIndices;
    final surahTitlePaths = <int>{};
    final basmalahPaths = <int>{};
    for (final dec in page.decorations) {
      if (dec.decoration == 1) { // SURAH_NAME
        for (var pi = dec.firstPath; pi < dec.firstPath + dec.nPaths; pi++) {
          surahTitlePaths.add(pi);
        }
      } else if (dec.decoration == 2) { // BASMALAH
        for (var pi = dec.firstPath; pi < dec.firstPath + dec.nPaths; pi++) {
          basmalahPaths.add(pi);
        }
      }
    }

    final uiPaths = page.getUiPaths();
    for (var i = 0; i < uiPaths.length; i++) {
      if (replacedRingPaths.contains(i)) {
        // Skip native ring replaced by custom dress ornament
        continue;
      }
      if (decIndices.contains(i)) {
        if (page.paths[i].kind == 2 && dress != null) {
          // Ayah numeral inside the custom rosette slot:
          // Always use crisp foreground ink for optimal contrast on white slot
          canvas.drawPath(uiPaths[i], inkPaint);
        } else if (surahTitlePaths.contains(i) && surahHeaderDress != null) {
          // Surah title calligraphy inside the illuminated header cartouche:
          // Always use crisp foreground ink for optimal contrast on cartouche slot
          canvas.drawPath(uiPaths[i], inkPaint);
        } else if (basmalahPaths.contains(i)) {
          // Sacred Basmalah calligraphy: always draw with crisp foreground ink (black in light mode)!
          canvas.drawPath(uiPaths[i], inkPaint);
        } else {
          canvas.drawPath(uiPaths[i], decPaint);
        }
      } else {
        canvas.drawPath(uiPaths[i], inkPaint);
      }
    }

    // 5. Word-by-Word Malayalam text overlay if enabled
    if (pageState.showWordByWord) {
      final double fontSizeInPageUnits = (5.0 * (settings.mlFontSize / 100.0)).clamp(4.0, 7.5);
      final isDark = settings.theme == AppThemeMode.dark;
      final textStyle = TextStyle(
        color: colors.muted,
        fontSize: fontSizeInPageUnits,
        fontWeight: FontWeight.w500,
        height: 1.0,
      );
      final selectedTextStyle = TextStyle(
        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        fontSize: fontSizeInPageUnits,
        fontWeight: FontWeight.bold,
        height: 1.0,
      );

      for (final word in page.words) {
        final list = wbwMap[word.verseKey];
        if (list != null && word.word - 1 < list.length) {
          final meaning = list[word.word - 1];
          if (meaning.isNotEmpty) {
            final isSelected = selWord != null &&
                word.verseKey == selWord.verseKey &&
                (selWord.wordIndices?.contains(word.word - 1) ??
                    (word.word - 1) == selWord.wordIndex);

            final tp = TextPainter(
              text: TextSpan(text: meaning, style: isSelected ? selectedTextStyle : textStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            );
            tp.layout();
            final textX = word.centerX - tp.width / 2.0;
            final textY = word.y1 + 0.6;

            if (isSelected) {
              final pillRect = Rect.fromLTRB(
                textX - 1.5,
                textY - 0.5,
                textX + tp.width + 1.5,
                textY + tp.height + 0.5,
              );
              canvas.drawRRect(
                RRect.fromRectAndRadius(pillRect, const Radius.circular(2.0)),
                Paint()
                  ..color = (isDark ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A))
                      .withValues(alpha: 0.35)
                  ..style = PaintingStyle.fill,
              );
            }

            tp.paint(canvas, Offset(textX, textY));
          }
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _QvpPagePainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.dress != dress ||
        oldDelegate.surahHeaderDress != surahHeaderDress ||
        oldDelegate.shiftX != shiftX ||
        oldDelegate.pageState.highlightVerseKey != pageState.highlightVerseKey ||
        oldDelegate.pageState.highlightWord != pageState.highlightWord ||
        oldDelegate.pageState.selectedWord != pageState.selectedWord ||
        oldDelegate.pageState.showWordByWord != pageState.showWordByWord ||
        oldDelegate.settings.theme != settings.theme ||
        oldDelegate.settings.ayahDress != settings.ayahDress ||
        oldDelegate.settings.frameDress != settings.frameDress ||
        oldDelegate.settings.surahHeaderDress != settings.surahHeaderDress ||
        oldDelegate.settings.mlFontSize != settings.mlFontSize;
  }
}
