import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/vocabulary_models.dart';
import '../core/models/qcf4_models.dart';
import 'service_providers.dart';

const Map<int, int> JUZ_START_PAGES = {
  1: 1, 2: 22, 3: 42, 4: 62, 5: 82, 6: 102, 7: 122, 8: 142, 9: 162, 10: 182,
  11: 202, 12: 222, 13: 242, 14: 262, 15: 282, 16: 302, 17: 322, 18: 342, 19: 362, 20: 382,
  21: 402, 22: 422, 23: 442, 24: 462, 25: 482, 26: 502, 27: 522, 28: 542, 29: 562, 30: 582,
};

List<VocabularyWord> filterWordsByScope(
  List<VocabularyWord> words,
  ScopeType scopeType,
  int scopeValue,
  Map<String, int> versePageMap,
) {
  if (scopeType == ScopeType.all || scopeValue == 0) {
    return words.where((w) => w.verses.isNotEmpty).toList();
  }

  return words.where((w) {
    if (w.verses.isEmpty) return false;
    return w.verses.any((vk) {
      final page = versePageMap[vk];
      if (page == null) return false;

      if (scopeType == ScopeType.page) {
        return page == scopeValue;
      }
      if (scopeType == ScopeType.juz) {
        final start = JUZ_START_PAGES[scopeValue] ?? 1;
        final nextStart = JUZ_START_PAGES[scopeValue + 1] ?? 605;
        return page >= start && page < nextStart;
      }
      if (scopeType == ScopeType.surah) {
        final surah = int.tryParse(vk.split(':')[0]);
        return surah == scopeValue;
      }
      return false;
    });
  }).toList();
}

class VocabularyStats {
  final int total;
  final int mastered;
  final int learned;
  final int learning;
  final int newWords;

  const VocabularyStats({
    this.total = 0,
    this.mastered = 0,
    this.learned = 0,
    this.learning = 0,
    this.newWords = 0,
  });
}

class VocabularyState {
  final bool isLoading;
  final ScopeType scopeType;
  final int scopeValue;
  final List<VocabularyWord> allWords;
  final List<VocabularyWord> filteredWords;
  final Map<String, WordProgress> progress;
  final List<String> repetitionList;
  final VocabularyStats stats;
  final List<SurahMastery> surahMastery;

  const VocabularyState({
    required this.isLoading,
    required this.scopeType,
    required this.scopeValue,
    required this.allWords,
    required this.filteredWords,
    required this.progress,
    required this.repetitionList,
    required this.stats,
    required this.surahMastery,
  });
}

class VocabularyNotifier extends StateNotifier<VocabularyState> {
  final Ref _ref;
  Map<String, int> _versePageMap = {};

  VocabularyNotifier(this._ref)
      : super(const VocabularyState(
          isLoading: true,
          scopeType: ScopeType.surah,
          scopeValue: 1,
          allWords: [],
          filteredWords: [],
          progress: {},
          repetitionList: [],
          stats: VocabularyStats(),
          surahMastery: [],
        )) {
    _init();
  }

  Future<void> _init() async {
    final qds = _ref.read(quranDataServiceProvider);
    final storage = _ref.read(localStorageServiceProvider);

    final results = await Future.wait([
      qds.loadVocabulary(),
      qds.loadVersePageMap(),
    ]);

    final vocabData = results[0] as VocabularyData;
    _versePageMap = results[1] as Map<String, int>;

    final rawProg = storage.vocabProgress;
    final progress = <String, WordProgress>{};
    for (final entry in rawProg.entries) {
      if (entry.value is Map<String, dynamic>) {
        progress[entry.key] = WordProgress.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    final repList = storage.vocabRepetitionList;

    state = VocabularyState(
      isLoading: false,
      scopeType: state.scopeType,
      scopeValue: state.scopeValue,
      allWords: vocabData.words,
      filteredWords: [],
      progress: progress,
      repetitionList: repList,
      stats: const VocabularyStats(),
      surahMastery: [],
    );

    _recompute();
  }

  void setScope(ScopeType type, int value) {
    state = VocabularyState(
      isLoading: state.isLoading,
      scopeType: type,
      scopeValue: value,
      allWords: state.allWords,
      filteredWords: state.filteredWords,
      progress: state.progress,
      repetitionList: state.repetitionList,
      stats: state.stats,
      surahMastery: state.surahMastery,
    );
    _recompute();
  }

  void recordAnswer(String arabicWord, bool isKnown) {
    final curProg = state.progress[arabicWord] ?? WordProgress.initial();
    final updated = curProg.copyWith(
      status: isKnown ? WordStatus.learned : WordStatus.learning,
      correct: isKnown ? curProg.correct + 1 : curProg.correct,
      wrong: isKnown ? curProg.wrong : curProg.wrong + 1,
      lastReviewed: DateTime.now().millisecondsSinceEpoch,
    );

    final newProg = Map<String, WordProgress>.from(state.progress)..[arabicWord] = updated;

    final newRep = List<String>.from(state.repetitionList);
    if (isKnown) {
      newRep.remove(arabicWord);
    } else {
      if (!newRep.contains(arabicWord)) newRep.add(arabicWord);
    }

    state = VocabularyState(
      isLoading: state.isLoading,
      scopeType: state.scopeType,
      scopeValue: state.scopeValue,
      allWords: state.allWords,
      filteredWords: state.filteredWords,
      progress: newProg,
      repetitionList: newRep,
      stats: state.stats,
      surahMastery: state.surahMastery,
    );

    _saveProgress(newProg, newRep);
    _recompute();
  }

  void markMastered(String arabicWord) {
    final curProg = state.progress[arabicWord] ?? WordProgress.initial();
    final updated = curProg.copyWith(
      status: WordStatus.mastered,
      correct: curProg.correct + 1,
      lastReviewed: DateTime.now().millisecondsSinceEpoch,
    );

    final newProg = Map<String, WordProgress>.from(state.progress)..[arabicWord] = updated;
    final newRep = List<String>.from(state.repetitionList)..remove(arabicWord);

    state = VocabularyState(
      isLoading: state.isLoading,
      scopeType: state.scopeType,
      scopeValue: state.scopeValue,
      allWords: state.allWords,
      filteredWords: state.filteredWords,
      progress: newProg,
      repetitionList: newRep,
      stats: state.stats,
      surahMastery: state.surahMastery,
    );

    _saveProgress(newProg, newRep);
    _recompute();
  }

  void _saveProgress(Map<String, WordProgress> prog, List<String> rep) {
    final storage = _ref.read(localStorageServiceProvider);
    storage.vocabProgress = prog.map((k, v) => MapEntry(k, v.toJson()));
    storage.vocabRepetitionList = rep;

    // Background sync to Supabase if logged in
    final user = _ref.read(supabaseServiceProvider).currentUser;
    if (user != null) {
      _ref.read(supabaseServiceProvider).syncWordProgress(user.id, prog);
    }
  }

  void _recompute() {
    final filtered = filterWordsByScope(state.allWords, state.scopeType, state.scopeValue, _versePageMap);

    int mastered = 0;
    int learned = 0;
    int learning = 0;

    for (final w in filtered) {
      final p = state.progress[w.arabic];
      if (p != null) {
        if (p.status == WordStatus.mastered) {
          mastered++;
        } else if (p.status == WordStatus.learned) {
          learned++;
        } else if (p.status == WordStatus.learning) {
          learning++;
        }
      }
    }

    final stats = VocabularyStats(
      total: filtered.length,
      mastered: mastered,
      learned: learned,
      learning: learning,
      newWords: max(0, filtered.length - mastered - learned - learning),
    );

    // Compute Surah Mastery
    final surahMap = <int, Map<String, int>>{};
    for (int s = 1; s <= 114; s++) {
      surahMap[s] = {'total': 0, 'mastered': 0, 'learned': 0, 'learning': 0};
    }

    for (final w in state.allWords) {
      if (w.verses.isEmpty) continue;
      final surahs = <int>{};
      for (final vk in w.verses) {
        final s = int.tryParse(vk.split(':')[0]);
        if (s != null) surahs.add(s);
      }
      final p = state.progress[w.arabic];
      for (final s in surahs) {
        final data = surahMap[s]!;
        data['total'] = data['total']! + 1;
        if (p != null) {
          if (p.status == WordStatus.mastered) {
            data['mastered'] = data['mastered']! + 1;
          } else if (p.status == WordStatus.learned) {
            data['learned'] = data['learned']! + 1;
          } else if (p.status == WordStatus.learning) {
            data['learning'] = data['learning']! + 1;
          }
        }
      }
    }

    final mastery = <SurahMastery>[];
    for (int s = 1; s <= 114; s++) {
      final d = surahMap[s]!;
      final info = SURAH_NAMES[s];
      mastery.add(SurahMastery(
        number: s,
        name: info?.name ?? '',
        englishName: info?.englishName ?? '',
        total: d['total']!,
        mastered: d['mastered']!,
        learned: d['learned']!,
        learning: d['learning']!,
      ));
    }

    state = VocabularyState(
      isLoading: state.isLoading,
      scopeType: state.scopeType,
      scopeValue: state.scopeValue,
      allWords: state.allWords,
      filteredWords: filtered,
      progress: state.progress,
      repetitionList: state.repetitionList,
      stats: stats,
      surahMastery: mastery,
    );
  }
}

final vocabularyProvider = StateNotifierProvider<VocabularyNotifier, VocabularyState>((ref) {
  return VocabularyNotifier(ref);
});
