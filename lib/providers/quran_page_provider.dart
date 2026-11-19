import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/quran_types.dart';
import '../core/models/qcf4_models.dart';
import '../core/models/qvp_models.dart';
import '../core/models/qvp_dress.dart';
import '../core/services/ar_ml_alignments_service.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

class QuranPageState {
  final int currentPage;
  final bool showWordByWord;
  final bool showSwipeWBW;
  final bool showTranslation;
  final bool twoPageMode;
  final bool simpleMode;
  final String? highlightVerseKey;
  final HighlightWord? highlightWord;
  final HighlightWord? selectedWord;
  final String? activeAyahSheetKey;
  final bool isFullScreen;

  const QuranPageState({
    required this.currentPage,
    required this.showWordByWord,
    this.showSwipeWBW = false,
    required this.showTranslation,
    required this.twoPageMode,
    required this.simpleMode,
    this.highlightVerseKey,
    this.highlightWord,
    this.selectedWord,
    this.activeAyahSheetKey,
    this.isFullScreen = false,
  });

  QuranPageState copyWith({
    int? currentPage,
    bool? showWordByWord,
    bool? showSwipeWBW,
    bool? showTranslation,
    bool? twoPageMode,
    bool? simpleMode,
    String? Function()? highlightVerseKey,
    HighlightWord? Function()? highlightWord,
    HighlightWord? Function()? selectedWord,
    String? Function()? activeAyahSheetKey,
    bool? isFullScreen,
  }) {
    return QuranPageState(
      currentPage: currentPage ?? this.currentPage,
      showWordByWord: showWordByWord ?? this.showWordByWord,
      showSwipeWBW: showSwipeWBW ?? this.showSwipeWBW,
      showTranslation: showTranslation ?? this.showTranslation,
      twoPageMode: twoPageMode ?? this.twoPageMode,
      simpleMode: simpleMode ?? this.simpleMode,
      highlightVerseKey: highlightVerseKey != null ? highlightVerseKey() : this.highlightVerseKey,
      highlightWord: highlightWord != null ? highlightWord() : this.highlightWord,
      selectedWord: selectedWord != null ? selectedWord() : this.selectedWord,
      activeAyahSheetKey: activeAyahSheetKey != null ? activeAyahSheetKey() : this.activeAyahSheetKey,
      isFullScreen: isFullScreen ?? this.isFullScreen,
    );
  }
}

class QuranPageNotifier extends StateNotifier<QuranPageState> {
  final Ref _ref;

  QuranPageNotifier(this._ref)
      : super(QuranPageState(
          currentPage: _ref.read(localStorageServiceProvider).currentPage,
          showWordByWord: _ref.read(localStorageServiceProvider).showWordByWord,
          showSwipeWBW: _ref.read(localStorageServiceProvider).showSwipeWBW,
          showTranslation: _ref.read(localStorageServiceProvider).showTranslation,
          twoPageMode: _ref.read(localStorageServiceProvider).twoPageMode,
          simpleMode: false,
        ));

  void goToPage(int page) {
    if (page < 1 || page > TOTAL_PAGES) return;
    int target = page;
    if (state.twoPageMode && target % 2 == 0) {
      target = target - 1;
    }
    state = state.copyWith(
      currentPage: target,
      highlightVerseKey: () => null,
      highlightWord: () => null,
      selectedWord: () => null,
    );
    _ref.read(localStorageServiceProvider).currentPage = target;
    _ref.read(qvpPageServiceProvider).preloadNeighborPages(target);
    _ref.read(qcf4FontServiceProvider).preloadNeighborPages(target);
  }

  void nextPage() {
    final step = state.twoPageMode ? 2 : 1;
    if (state.currentPage + step <= TOTAL_PAGES) {
      goToPage(state.currentPage + step);
    }
  }

  void prevPage() {
    final step = state.twoPageMode ? 2 : 1;
    if (state.currentPage - step >= 1) {
      goToPage(state.currentPage - step);
    }
  }

  void toggleWordByWord() {
    final next = !state.showWordByWord;
    state = state.copyWith(
      showWordByWord: next,
      showSwipeWBW: next ? false : state.showSwipeWBW,
    );
    _ref.read(localStorageServiceProvider).showWordByWord = next;
    if (next) {
      _ref.read(localStorageServiceProvider).showSwipeWBW = false;
    }
  }

  void toggleSwipeWBW() {
    final next = !state.showSwipeWBW;
    state = state.copyWith(
      showSwipeWBW: next,
      showWordByWord: next ? false : state.showWordByWord,
    );
    _ref.read(localStorageServiceProvider).showSwipeWBW = next;
    if (next) {
      _ref.read(localStorageServiceProvider).showWordByWord = false;
    }
  }

  void toggleTranslation() {
    final next = !state.showTranslation;
    state = state.copyWith(showTranslation: next);
    _ref.read(localStorageServiceProvider).showTranslation = next;
  }

  void toggleTwoPageMode() {
    final next = !state.twoPageMode;
    int page = state.currentPage;
    if (next && page % 2 == 0) page = page - 1;
    state = state.copyWith(twoPageMode: next, currentPage: page);
    _ref.read(localStorageServiceProvider).twoPageMode = next;
    _ref.read(localStorageServiceProvider).currentPage = page;
  }

  void toggleSimpleMode() {
    state = state.copyWith(simpleMode: !state.simpleMode);
  }

  void setHighlightVerseKey(String? key) {
    state = state.copyWith(highlightVerseKey: () => key);
  }

  void setHighlightWord(HighlightWord? word) {
    state = state.copyWith(highlightWord: () => word);
  }

  void setSelectedWord(HighlightWord? word) {
    state = state.copyWith(selectedWord: () => word);
  }

  void openAyahSheet(String? key) {
    state = state.copyWith(activeAyahSheetKey: () => key);
  }

  void toggleFullScreen() {
    final next = !state.isFullScreen;
    state = state.copyWith(isFullScreen: next);
    if (next) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void setFullScreen(bool value) {
    if (state.isFullScreen == value) return;
    state = state.copyWith(isFullScreen: value);
    if (value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}

final quranPageProvider = StateNotifierProvider<QuranPageNotifier, QuranPageState>((ref) {
  return QuranPageNotifier(ref);
});

// ── Data Providers ──────────────────────────────────────────────────────────
final wbwDataProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  return ref.watch(quranDataServiceProvider).loadMalayalamWBW();
});

final qvpPageProvider = FutureProvider.family<QvpDecodedPage, int>((ref, page) async {
  return ref.watch(qvpPageServiceProvider).getPage(page);
});

final qcf4PageProvider = FutureProvider.family<PageData2, int>((ref, page) async {
  return ref.watch(qcf4FontServiceProvider).fetchPageData(page);
});

final uthmaniPageProvider = FutureProvider.family<PageData, int>((ref, page) async {
  return ref.watch(quranDataServiceProvider).fetchUthmaniPage(page);
});

final translationPageProvider = FutureProvider.family<Map<String, String>, int>((ref, page) async {
  return ref.watch(quranDataServiceProvider).fetchTranslationPage(page);
});

final pageAlignmentsProvider = FutureProvider.family<Map<String, List<PhraseAlignment>>, int>((ref, page) async {
  try {
    final uthmani = await ref.watch(uthmaniPageProvider(page).future);
    final vks = uthmani.ayahs.map((a) => a.verseKey).toList();
    if (vks.isEmpty) return <String, List<PhraseAlignment>>{};
    return await ref.watch(arMlAlignmentsServiceProvider).fetchPageAlignments(page, vks);
  } catch (_) {
    return <String, List<PhraseAlignment>>{};
  }
});

final ayahDressProvider = FutureProvider<QvpAyahDress?>((ref) async {
  final dressSetting = ref.watch(settingsProvider.select((s) => s.ayahDress));
  try {
    return await QvpAyahDress.load(dressSetting);
  } catch (e) {
    return null;
  }
});

final surahHeaderDressProvider = FutureProvider<QvpSurahHeaderDress?>((ref) async {
  final headerSetting = ref.watch(settingsProvider.select((s) => s.surahHeaderDress));
  try {
    return await QvpSurahHeaderDress.load(headerSetting);
  } catch (e) {
    return null;
  }
});

final frameDressProvider = FutureProvider<QvpFrameDress?>((ref) async {
  final frameSetting = ref.watch(settingsProvider.select((s) => s.frameDress));
  try {
    return await QvpFrameDress.load(frameSetting);
  } catch (e) {
    return null;
  }
});
