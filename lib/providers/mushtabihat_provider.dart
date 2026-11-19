import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/mushtabihat_models.dart';
import 'service_providers.dart';

String stripArabicDiacritics(String text) {
  return text
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED\u0610-\u061A]'), '')
      .replaceAll('ٱ', 'ا')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class MushtabihatState {
  final bool isLoading;
  final int startJuz;
  final int endJuz;
  final List<MushtabihatPair> allPairs;
  final List<MushtabihatPair> filteredPairs;
  final List<MushtabihatPair> quizPairs;
  final List<String> bookmarks;
  final List<String> hidden;

  const MushtabihatState({
    required this.isLoading,
    required this.startJuz,
    required this.endJuz,
    required this.allPairs,
    required this.filteredPairs,
    required this.quizPairs,
    required this.bookmarks,
    required this.hidden,
  });

  MushtabihatState copyWith({
    bool? isLoading,
    int? startJuz,
    int? endJuz,
    List<MushtabihatPair>? allPairs,
    List<MushtabihatPair>? filteredPairs,
    List<MushtabihatPair>? quizPairs,
    List<String>? bookmarks,
    List<String>? hidden,
  }) {
    return MushtabihatState(
      isLoading: isLoading ?? this.isLoading,
      startJuz: startJuz ?? this.startJuz,
      endJuz: endJuz ?? this.endJuz,
      allPairs: allPairs ?? this.allPairs,
      filteredPairs: filteredPairs ?? this.filteredPairs,
      quizPairs: quizPairs ?? this.quizPairs,
      bookmarks: bookmarks ?? this.bookmarks,
      hidden: hidden ?? this.hidden,
    );
  }
}

class MushtabihatNotifier extends StateNotifier<MushtabihatState> {
  final Ref _ref;

  MushtabihatNotifier(this._ref)
      : super(const MushtabihatState(
          isLoading: true,
          startJuz: 29,
          endJuz: 30,
          allPairs: [],
          filteredPairs: [],
          quizPairs: [],
          bookmarks: [],
          hidden: [],
        )) {
    _init();
  }

  Future<void> _init() async {
    final qds = _ref.read(quranDataServiceProvider);
    final storage = _ref.read(localStorageServiceProvider);

    final pairs = await qds.loadMushtabihat();
    final bookmarks = storage.mushtabihatBookmarks;
    final hidden = storage.mushtabihatHidden;

    state = MushtabihatState(
      isLoading: false,
      startJuz: 29,
      endJuz: 30,
      allPairs: pairs,
      filteredPairs: [],
      quizPairs: [],
      bookmarks: bookmarks,
      hidden: hidden,
    );

    _applyFilter();
  }

  void setJuzRange(int start, int end) {
    state = state.copyWith(startJuz: start, endJuz: end);
    _applyFilter();
  }

  void toggleBookmark(MushtabihatPair pair) {
    final key = pair.pairKey;
    final newBookmarks = List<String>.from(state.bookmarks);
    if (newBookmarks.contains(key)) {
      newBookmarks.remove(key);
    } else {
      newBookmarks.add(key);
    }

    state = state.copyWith(bookmarks: newBookmarks);
    _ref.read(localStorageServiceProvider).mushtabihatBookmarks = newBookmarks;

    final user = _ref.read(supabaseServiceProvider).currentUser;
    if (user != null) {
      _ref.read(supabaseServiceProvider).syncBookmarks(user.id, newBookmarks);
    }
  }

  void toggleHidden(MushtabihatPair pair) {
    final key = pair.pairKey;
    final newHidden = List<String>.from(state.hidden);
    if (newHidden.contains(key)) {
      newHidden.remove(key);
    } else {
      newHidden.add(key);
    }

    state = state.copyWith(hidden: newHidden);
    _ref.read(localStorageServiceProvider).mushtabihatHidden = newHidden;

    final user = _ref.read(supabaseServiceProvider).currentUser;
    if (user != null) {
      _ref.read(supabaseServiceProvider).syncHidden(user.id, newHidden);
    }

    _applyFilter();
  }

  void startQuiz() {
    final candidates = state.filteredPairs.where((p) => !state.hidden.contains(p.pairKey)).toList();
    candidates.shuffle();
    state = state.copyWith(quizPairs: candidates);
  }

  void _applyFilter() {
    final filtered = state.allPairs.where((p) {
      return p.juz1 >= state.startJuz &&
          p.juz1 <= state.endJuz &&
          p.juz2 >= state.startJuz &&
          p.juz2 <= state.endJuz;
    }).toList();

    state = state.copyWith(filteredPairs: filtered);
  }

  Future<List<Map<String, dynamic>>> searchQuranText(String query) async {
    if (query.trim().isEmpty) return [];
    final qds = _ref.read(quranDataServiceProvider);
    final surahs = await qds.loadQuranText();
    final normalizedQuery = stripArabicDiacritics(query);

    final results = <Map<String, dynamic>>[];
    for (final s in surahs) {
      final sId = s['id'] as int;
      final verses = (s['verses'] as List<dynamic>? ?? []);
      for (final v in verses) {
        final vId = v['id'] as int;
        final rawText = v['text'] as String? ?? '';
        final normText = stripArabicDiacritics(rawText);
        if (normText.contains(normalizedQuery)) {
          results.add({
            'verseKey': '$sId:$vId',
            'text': rawText,
          });
          if (results.length >= 50) return results;
        }
      }
    }
    return results;
  }
}

final mushtabihatProvider = StateNotifierProvider<MushtabihatNotifier, MushtabihatState>((ref) {
  return MushtabihatNotifier(ref);
});
