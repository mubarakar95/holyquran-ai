import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../models/quran_types.dart';
import '../models/vocabulary_models.dart';
import '../models/mushtabihat_models.dart';

class QuranDataService {
  final Dio _dio;

  Map<String, List<String>>? _wbwData;
  VocabularyData? _vocabData;
  Map<String, int>? _versePageMap;
  List<MushtabihatPair>? _mushtabihatPairs;
  List<Map<String, dynamic>>? _quranText;
  Map<String, dynamic>? _arMlAlignmentsLocal;

  final Map<int, PageData> _uthmaniPageCache = {};
  final Map<int, Map<String, String>> _translationPageCache = {};

  QuranDataService([Dio? dio]) : _dio = dio ?? Dio();

  // ── Word-by-Word Malayalam dictionary ─────────────────────────────────────
  Future<Map<String, List<String>>> loadMalayalamWBW() async {
    if (_wbwData != null) return _wbwData!;
    final str = await rootBundle.loadString('assets/data/malayalam-wbw.json');
    final map = jsonDecode(str) as Map<String, dynamic>;
    final result = <String, List<String>>{};
    for (final entry in map.entries) {
      if (entry.value is List) {
        result[entry.key] = (entry.value as List).map((e) => e?.toString() ?? '').toList();
      }
    }
    _wbwData = result;
    return result;
  }

  // ── Vocabulary dataset ───────────────────────────────────────────────────
  Future<VocabularyData> loadVocabulary() async {
    if (_vocabData != null) return _vocabData!;
    final str = await rootBundle.loadString('assets/data/vocabulary.json');
    final map = jsonDecode(str) as Map<String, dynamic>;
    _vocabData = VocabularyData.fromJson(map);
    return _vocabData!;
  }

  // ── Verse to Page map ────────────────────────────────────────────────────
  Future<Map<String, int>> loadVersePageMap() async {
    if (_versePageMap != null) return _versePageMap!;
    final str = await rootBundle.loadString('assets/data/verse-page-map.json');
    final map = jsonDecode(str) as Map<String, dynamic>;
    final result = <String, int>{};
    for (final entry in map.entries) {
      result[entry.key] = (entry.value as num).toInt();
    }
    _versePageMap = result;
    return result;
  }

  // ── Mushtabihat dataset ──────────────────────────────────────────────────
  Future<List<MushtabihatPair>> loadMushtabihat() async {
    if (_mushtabihatPairs != null) return _mushtabihatPairs!;
    final str = await rootBundle.loadString('assets/data/mushtabihat.json');
    final map = jsonDecode(str) as Map<String, dynamic>;
    final list = (map['pairs'] as List<dynamic>? ?? [])
        .map((e) => MushtabihatPair.fromJson(e as Map<String, dynamic>))
        .toList();
    _mushtabihatPairs = list;
    return list;
  }

  // ── Full Quran Arabic Text ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> loadQuranText() async {
    if (_quranText != null) return _quranText!;
    final str = await rootBundle.loadString('assets/data/quran-text.json');
    final list = jsonDecode(str) as List<dynamic>;
    _quranText = list.cast<Map<String, dynamic>>();
    return _quranText!;
  }

  Future<String?> getAyahArabicText(int surahNumber, int ayahNumber) async {
    final list = await loadQuranText();
    final surah = list.where((s) => s['id'] == surahNumber).firstOrNull;
    if (surah != null && surah['verses'] is List) {
      final verses = surah['verses'] as List;
      final verse = verses.where((v) => v['id'] == ayahNumber).firstOrNull;
      if (verse != null && verse['text'] != null) {
        return verse['text'] as String;
      }
    }
    return null;
  }

  // ── Local Arabic-Malayalam alignments cache ──────────────────────────────
  Future<Map<String, dynamic>> loadLocalAlignments() async {
    if (_arMlAlignmentsLocal != null) return _arMlAlignmentsLocal!;
    try {
      final str = await rootBundle.loadString('assets/data/ar_ml_alignments.json');
      _arMlAlignmentsLocal = jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      _arMlAlignmentsLocal = {};
    }
    return _arMlAlignmentsLocal!;
  }

  // ── Fetch Uthmani page data ──────────────────────────────────────────────
  Future<PageData> fetchUthmaniPage(int page) async {
    if (_uthmaniPageCache.containsKey(page)) {
      return _uthmaniPageCache[page]!;
    }

    try {
      final res = await _dio.get(
        'https://api.alquran.cloud/v1/page/$page/quran-uthmani',
        options: Options(
          headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'] as Map<String, dynamic>;
        final pageData = PageData.fromJson(data);
        _uthmaniPageCache[page] = pageData;
        return pageData;
      }
    } catch (e) {
      debugPrint('Error fetching uthmani page $page: $e');
    }
    return PageData(number: page, ayahs: []);
  }

  // ── Fetch Malayalam translation page ─────────────────────────────────────
  Future<Map<String, String>> fetchTranslationPage(int page) async {
    if (_translationPageCache.containsKey(page)) {
      return _translationPageCache[page]!;
    }

    try {
      final res = await _dio.get(
        'https://api.alquran.cloud/v1/page/$page/$MALAYALAM_EDITION',
        options: Options(
          headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (res.statusCode == 200 && res.data != null) {
        final ayahs = res.data['data']['ayahs'] as List<dynamic>;
        final map = <String, String>{};
        for (final a in ayahs) {
          final surahNum = a['surah']['number'];
          final ayahInSurah = a['numberInSurah'];
          map['$surahNum:$ayahInSurah'] = a['text'] as String? ?? '';
        }
        _translationPageCache[page] = map;
        return map;
      }
    } catch (e) {
      debugPrint('Error fetching translation page $page: $e');
    }
    return <String, String>{};
  }
}
