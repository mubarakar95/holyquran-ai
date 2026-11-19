import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/models/quran_types.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/quran_page_provider.dart';
import '../../providers/settings_provider.dart';

class WordGroup {
  final List<String> arabicWords;
  final String? meaning;
  final List<int> wordIndices;

  const WordGroup({
    required this.arabicWords,
    this.meaning,
    required this.wordIndices,
  });
}

final RegExp _quranAnnotationRegex = RegExp(r'^[\u0656-\u065C\u06D6-\u06ED]+$');

List<WordGroup> groupAyahWords(String arabicText, List<String> meanings) {
  final tokens = arabicText.trim().split(RegExp(r'\s+'));
  final groups = <WordGroup>[];
  int meaningIdx = 0;

  for (int tokenIdx = 0; tokenIdx < tokens.length; tokenIdx++) {
    final token = tokens[tokenIdx];
    if (_quranAnnotationRegex.hasMatch(token)) {
      if (groups.isNotEmpty) {
        final last = groups.last;
        groups[groups.length - 1] = WordGroup(
          arabicWords: [...last.arabicWords, token],
          meaning: last.meaning,
          wordIndices: [...last.wordIndices, tokenIdx],
        );
      } else {
        groups.add(WordGroup(
          arabicWords: [token],
          meaning: null,
          wordIndices: [tokenIdx],
        ));
      }
      continue;
    }

    final meaning = meaningIdx < meanings.length ? meanings[meaningIdx] : null;
    meaningIdx++;

    if (meaning != null && meaning.isNotEmpty) {
      groups.add(WordGroup(
        arabicWords: [token],
        meaning: meaning,
        wordIndices: [tokenIdx],
      ));
    } else {
      if (groups.isNotEmpty) {
        final last = groups.last;
        groups[groups.length - 1] = WordGroup(
          arabicWords: [...last.arabicWords, token],
          meaning: last.meaning,
          wordIndices: [...last.wordIndices, tokenIdx],
        );
      } else {
        groups.add(WordGroup(
          arabicWords: [token],
          meaning: null,
          wordIndices: [tokenIdx],
        ));
      }
    }
  }

  return groups;
}

class SwipeWBWView extends ConsumerStatefulWidget {
  final int currentPage;

  const SwipeWBWView({
    super.key,
    required this.currentPage,
  });

  @override
  ConsumerState<SwipeWBWView> createState() => _SwipeWBWViewState();
}

class _SwipeWBWViewState extends ConsumerState<SwipeWBWView> {
  late PageController _pageController;
  int _currentAyahIndex = 0;
  final FlutterTts _flutterTts = FlutterTts();
  bool _minimapPinned = false;
  bool _minimapVisible = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("ml-IN");
      await _flutterTts.setSpeechRate(0.85);
      await _flutterTts.setVolume(1.0);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant SwipeWBWView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _currentAyahIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakMalayalam(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  void _showMinimapTemporarily() {
    setState(() => _minimapVisible = true);
    if (!_minimapPinned) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_minimapPinned) {
          setState(() => _minimapVisible = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);
    final quranState = ref.watch(quranPageProvider);

    final uthmaniAsync = ref.watch(uthmaniPageProvider(widget.currentPage));
    final qvpAsync = ref.watch(qvpPageProvider(widget.currentPage));
    final wbwAsync = ref.watch(wbwDataProvider);
    final translationAsync = ref.watch(translationPageProvider(widget.currentPage));

    final pageData = uthmaniAsync.value;
    final ayahs = pageData?.ayahs ?? [];
    final wbwMap = wbwAsync.value ?? {};
    final translationMap = translationAsync.value ?? {};
    final qvpPage = qvpAsync.value;

    if (ayahs.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: colors.accent),
      );
    }

    final currentAyah = ayahs[_currentAyahIndex.clamp(0, ayahs.length - 1)];
    final verseKey = currentAyah.verseKey;

    // Calculate line span for minimap
    final activeLines = <int>{};
    if (qvpPage != null) {
      for (final w in qvpPage.words) {
        if (w.verseKey == verseKey) {
          activeLines.add(w.lineIndex);
        }
      }
    }

    return Stack(
      children: [
        Column(
          children: [
            // 1. Ayah Navigation & Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous Ayah button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                    color: _currentAyahIndex > 0 ? colors.foreground : colors.muted.withValues(alpha: 0.3),
                    onPressed: _currentAyahIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                            _showMinimapTemporarily();
                          }
                        : null,
                  ),

                  // Surah Name & Ayah Number
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentAyah.surah.name,
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${currentAyah.surah.englishName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Ayah ${currentAyah.numberInSurah}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Next Ayah button
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    color: _currentAyahIndex < ayahs.length - 1
                        ? colors.foreground
                        : colors.muted.withValues(alpha: 0.3),
                    onPressed: _currentAyahIndex < ayahs.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                            _showMinimapTemporarily();
                          }
                        : null,
                  ),
                ],
              ),
            ),

            // 2. Swipeable Ayahs Viewport
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: ayahs.length,
                onPageChanged: (idx) {
                  setState(() => _currentAyahIndex = idx);
                  final a = ayahs[idx];
                  ref.read(quranPageProvider.notifier).setHighlightVerseKey(a.verseKey);
                  _showMinimapTemporarily();
                },
                itemBuilder: (context, idx) {
                  final a = ayahs[idx];
                  final vk = a.verseKey;
                  final meanings = wbwMap[vk] ?? [];
                  final fullTranslation = translationMap[vk] ?? '';
                  final groups = groupAyahWords(a.text, meanings);

                  return _buildAyahCard(
                    context,
                    ayah: a,
                    groups: groups,
                    fullTranslation: fullTranslation,
                    colors: colors,
                    settings: settings,
                    quranState: quranState,
                  );
                },
              ),
            ),

            // 3. Bottom Ayah Indicator Dots & Page info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(ayahs.length, (i) {
                        final isSel = i == _currentAyahIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                            width: isSel ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSel ? colors.accent : colors.muted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Page ${widget.currentPage}  •  ${ayahs.length} ayahs',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // 4. Interactive 15-Line Mushaf Minimap
        if (_minimapPinned || _minimapVisible)
          Positioned(
            right: 14,
            bottom: 74,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (settings.theme == AppThemeMode.dark
                          ? const Color(0xFF18181B)
                          : const Color(0xFFFFFFFF))
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'P${widget.currentPage}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(15, (lineIdx) {
                      final isActive = activeLines.contains(lineIdx);
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        width: 32,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.accent
                              : colors.muted.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

        // Minimap Pin Button
        Positioned(
          right: 14,
          bottom: 40,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _minimapPinned = !_minimapPinned);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  _minimapPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                  color: _minimapPinned ? colors.accent : colors.muted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAyahCard(
    BuildContext context, {
    required AyahInfo ayah,
    required List<WordGroup> groups,
    required String fullTranslation,
    required AppColors colors,
    required SettingsState settings,
    required QuranPageState quranState,
  }) {
    final vk = ayah.verseKey;
    final hlVerse = quranState.highlightVerseKey;
    final hlWord = quranState.highlightWord;
    final isDark = settings.theme == AppThemeMode.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Full Ayah Translation Card at top
        if (fullTranslation.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hlVerse == vk ? colors.accent.withValues(alpha: 0.5) : colors.border,
                width: hlVerse == vk ? 1.5 : 1.0,
              ),
              boxShadow: [
                if (hlVerse == vk)
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.muted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vk,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      tooltip: 'Listen to translation',
                      color: colors.accent,
                      onPressed: () => _speakMalayalam(fullTranslation),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  fullTranslation,
                  style: TextStyle(
                    fontSize: 13.5 * (settings.mlFontSize / 100.0),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),

        // Word-by-Word Breakdown Rows
        Text(
          'WORD BY WORD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 8),

        ...groups.map((grp) {
          final isGrpActive = hlVerse == vk &&
              hlWord != null &&
              hlWord.verseKey == vk &&
              ((hlWord.wordIndices != null &&
                      hlWord.wordIndices!.any((idx) => grp.wordIndices.contains(idx))) ||
                  grp.wordIndices.contains(hlWord.wordIndex));

          return GestureDetector(
            onDoubleTap: () {
              final firstIdx = grp.wordIndices.isNotEmpty ? grp.wordIndices.first : 0;
              ref.read(audioPlayerProvider.notifier).seekToWord(vk, firstIdx);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isGrpActive
                    ? (hlWord.bundle
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.45) : const Color(0xFFDBEAFE))
                        : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.45) : const Color(0xFFFEF3C7)))
                    : colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isGrpActive
                      ? (hlWord.bundle
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFF59E0B))
                      : colors.border,
                  width: isGrpActive ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Malayalam Meaning + Speaker Button
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        if (grp.meaning != null && grp.meaning!.isNotEmpty)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: Icon(
                              Icons.volume_up_rounded,
                              size: 16,
                              color: isGrpActive ? colors.accent : colors.muted,
                            ),
                            onPressed: () => _speakMalayalam(grp.meaning!),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            grp.meaning ?? '',
                            style: TextStyle(
                              fontSize: 13.0 * (settings.mlFontSize / 100.0),
                              fontWeight: isGrpActive ? FontWeight.bold : FontWeight.w500,
                              color: isGrpActive
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : colors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Column divider
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: colors.border,
                  ),

                  // Arabic Word(s) in RTL
                  Expanded(
                    flex: 5,
                    child: Text(
                      grp.arabicWords.join(' '),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 20 * (settings.arFontSize / 100.0),
                        fontWeight: isGrpActive ? FontWeight.bold : FontWeight.w600,
                        color: isGrpActive
                            ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                            : colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
