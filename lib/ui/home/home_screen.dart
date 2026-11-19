import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quran_types.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/gemini_toast_provider.dart';
import '../../providers/quran_page_provider.dart';
import '../../providers/settings_provider.dart';
import '../audio/audio_player_widget.dart';
import '../mushaf/mushaf_page_view.dart';
import '../mushaf/ayah_sheet_widget.dart';
import '../mushaf/page_flip_book_widget.dart';
import '../mushaf/swipe_wbw_view.dart';
import '../mushaf/mushaf_page_side_icon.dart';
import '../common/gemini_toast_widget.dart';
import '../common/shortcut_legend_widget.dart';
import '../sidebar/sidebar_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final audio = ref.read(audioPlayerProvider);
      final audioNotifier = ref.read(audioPlayerProvider.notifier);

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        ref.read(quranPageProvider.notifier).nextPage();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        ref.read(quranPageProvider.notifier).prevPage();
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        if (audio.isPlaying) {
          audioNotifier.pause();
        } else {
          audioNotifier.resume();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.arrowDown) {
        audioNotifier.nextAyah();
      } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.arrowUp) {
        audioNotifier.prevAyah();
      } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
        final nextRepeat = audio.repeatMode == QuranRepeatMode.none
            ? QuranRepeatMode.ayah
            : audio.repeatMode == QuranRepeatMode.ayah
                ? QuranRepeatMode.page
                : QuranRepeatMode.none;
        audioNotifier.setRepeatMode(nextRepeat);
      } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
        const speeds = [1.0, 1.25, 1.5, 2.0];
        final currentSpeed = audio.audioMode == AudioMode.malayalam
            ? audio.malayalamPlaybackRate
            : audio.arabicPlaybackRate;
        final idx = speeds.indexOf(currentSpeed);
        final nextSpeed = speeds[(idx + 1) % speeds.length];
        if (audio.audioMode == AudioMode.malayalam) {
          audioNotifier.setMalayalamSpeed(nextSpeed);
        } else {
          audioNotifier.setArabicSpeed(nextSpeed);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
        const modes = [AudioMode.arabic, AudioMode.malayalam, AudioMode.both];
        final idx = modes.indexOf(audio.audioMode);
        final nextMode = modes[(idx + 1) % modes.length];
        audioNotifier.setAudioMode(nextMode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(quranPageProvider.select((s) => s.currentPage));
    final isFullScreen = ref.watch(quranPageProvider.select((s) => s.isFullScreen));
    final showSwipeWBW = ref.watch(quranPageProvider.select((s) => s.showSwipeWBW));
    final twoPageMode = ref.watch(quranPageProvider.select((s) => s.twoPageMode));
    final activeAyahSheetKey = ref.watch(quranPageProvider.select((s) => s.activeAyahSheetKey));

    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);
    final audioState = ref.watch(audioPlayerProvider);

    final uthmaniAsync = ref.watch(uthmaniPageProvider(currentPage));
    final qvpAsync = ref.watch(qvpPageProvider(currentPage));

    // Instant local QVP page ayahs for offline audio player availability (deduplicated by verseKey)
    qvpAsync.whenData((pageData) {
      final seen = <String>{};
      final ayahs = <AyahInfo>[];
      for (final a in pageData.ayahs) {
        final vk = '${a.surah}:${a.ayah}';
        if (seen.add(vk)) {
          ayahs.add(AyahInfo(
            number: a.ayah,
            text: '',
            numberInSurah: a.ayah,
            juz: 1,
            manzil: 1,
            ruku: 1,
            hizbQuarter: a.rubuAlHizb,
            sajda: false,
            surah: SurahInfo(
              number: a.surah,
              name: '',
              englishName: '',
              englishNameTranslation: '',
              numberOfAyahs: a.ayah,
              revelationType: '',
            ),
          ));
        }
      }
      if (ayahs.isNotEmpty) {
        ref.read(audioPlayerProvider.notifier).setAyahs(ayahs);
      }
    });

    // Also update audio player when online Uthmani data arrives
    uthmaniAsync.whenData((pageData) {
      if (pageData.ayahs.isNotEmpty) {
        ref.read(audioPlayerProvider.notifier).setAyahs(pageData.ayahs);
      }
    });

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: colors.background,
        drawer: const SidebarDrawer(),
        appBar: isFullScreen
            ? null
            : AppBar(
                title: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colors.foreground,
                    ),
                    children: [
                      const TextSpan(text: 'QURAN '),
                      TextSpan(
                        text: 'Easy Malayalam',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                centerTitle: true,
                backgroundColor: colors.background,
                elevation: 0,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    color: colors.muted,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                  // Keyboard Shortcuts Dialog Button
                  IconButton(
                    icon: const Icon(Icons.keyboard_outlined, size: 20),
                    tooltip: 'Keyboard Shortcuts',
                    color: colors.muted,
                    onPressed: () => ShortcutLegendDialog.show(context, colors),
                  ),

                  // Full Screen Mode Toggle Button
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded, size: 22),
                    tooltip: 'Full Screen Mode',
                    color: colors.muted,
                    onPressed: () {
                      ref.read(quranPageProvider.notifier).toggleFullScreen();
                    },
                  ),
                  const SizedBox(width: 4),

                  // Odd/Even Page Mushaf book indicator (Real Mushaf Left/Right spread)
                  MushafPageSideIcon(
                    pageNumber: currentPage,
                    width: 22,
                    height: 16,
                    activeColor: colors.foreground,
                    inactiveColor: colors.muted.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 8),

                  // Theme Toggle Button
                  IconButton(
                    icon: Icon(
                      settings.theme == AppThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : settings.theme == AppThemeMode.creme
                              ? Icons.auto_stories_rounded
                              : Icons.light_mode_rounded,
                      size: 20,
                      color: settings.theme == AppThemeMode.dark
                          ? Colors.amber
                          : settings.theme == AppThemeMode.creme
                              ? Colors.brown
                              : colors.muted,
                    ),
                    tooltip: 'Switch Theme (${settings.theme.value})',
                    onPressed: () {
                      ref.read(settingsProvider.notifier).toggleTheme();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        body: Stack(
          children: [
              // Main Reading Area
              Positioned.fill(
                child: showSwipeWBW
                    ? SwipeWBWView(currentPage: currentPage)
                    : (twoPageMode
                        ? PageFlipBookWidget(currentPage: currentPage)
                        : MushafPageView(pageNumber: currentPage)),
              ),

              // Floating Center-Top Full Screen Bar (Page Side Indicator + Exit)
              if (isFullScreen)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: const Color(0xFF18181B).withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Page Side Indicator (Real Mushaf Left/Right spread)
                            MushafPageSideIcon(
                              pageNumber: currentPage,
                              width: 20,
                              height: 15,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white38,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$currentPage',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 12,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            const SizedBox(width: 10),

                            // Exit Full Screen Button
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                ref.read(quranPageProvider.notifier).setFullScreen(false);
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Exit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Ayah Sheet Modal & Tap-outside Backdrop Scrim
              if (activeAyahSheetKey != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ref.read(quranPageProvider.notifier).openAyahSheet(null);
                    },
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AyahSheetWidget(
                    verseKey: activeAyahSheetKey,
                    onClose: () {
                      ref.read(quranPageProvider.notifier).openAyahSheet(null);
                    },
                  ),
                ),
              ],

              // Real-Time Gemini AI & System Toast Notification
              if (ref.watch(geminiToastProvider) != null)
                const Positioned(
                  bottom: 96,
                  left: 16,
                  right: 16,
                  child: GeminiToastWidget(),
                ),
            ],
          ),
        bottomNavigationBar: isFullScreen
            ? null
            : (audioState.audioVisible
                ? const AudioPlayerWidget()
                : Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                          onPressed: currentPage > 1
                              ? () => ref.read(quranPageProvider.notifier).prevPage()
                              : null,
                        ),
                        Text(
                          '$currentPage / $TOTAL_PAGES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onPressed: currentPage < TOTAL_PAGES
                              ? () => ref.read(quranPageProvider.notifier).nextPage()
                              : null,
                        ),
                      ],
                    ),
                  )),
      ),
    );
  }
}
