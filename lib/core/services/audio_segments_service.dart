import 'dart:math';
import 'package:dio/dio.dart';
import '../models/quran_types.dart';

class AudioSegmentsService {
  final Dio _dio;
  final Map<String, List<AyahSegments>> _cache = {};

  AudioSegmentsService([Dio? dio]) : _dio = dio ?? Dio();

  String _cacheKey(int quranComId, int chapterNumber) => '$quranComId:$chapterNumber';

  List<AyahSegments>? getCachedSegments(int quranComId, int chapterNumber) {
    return _cache[_cacheKey(quranComId, chapterNumber)];
  }

  Future<List<AyahSegments>> fetchChapterSegments(int quranComId, int chapterNumber) async {
    final key = _cacheKey(quranComId, chapterNumber);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final url = 'https://api.quran.com/api/v4/quran/recitations/$quranComId?chapter_number=$chapterNumber&fields=segments';
    final res = await _dio.get(url);

    if (res.statusCode == 200 && res.data != null) {
      final audioFiles = res.data['audio_files'] as List<dynamic>? ?? [];
      final result = <AyahSegments>[];

      for (final af in audioFiles) {
        final verseKey = af['verse_key'] as String;
        final rawSegments = af['segments'] as List<dynamic>? ?? [];
        final parsed = _parseSegments(rawSegments);
        result.add(AyahSegments(verseKey: verseKey, segments: parsed));
      }

      _cache[key] = result;
      return result;
    }

    throw Exception('Failed to fetch segments for recitation $quranComId, chapter $chapterNumber');
  }

  List<WordSegment> _parseSegments(List<dynamic> raw) {
    final result = <WordSegment>[];
    for (final seg in raw) {
      if (seg is! List || seg.length < 4) continue;
      final fromIdx = seg[0] is int ? seg[0] as int : int.tryParse(seg[0].toString()) ?? 0;
      final toIdx = seg[1] is int ? seg[1] as int : int.tryParse(seg[1].toString()) ?? 0;
      final startMs = seg[2] is int ? seg[2] as int : int.tryParse(seg[2].toString()) ?? 0;
      final endMs = seg[3] is int ? seg[3] as int : int.tryParse(seg[3].toString()) ?? 0;

      if (toIdx > fromIdx) {
        for (int w = fromIdx; w < toIdx; w++) {
          result.add(WordSegment(wordIndex: w, startMs: startMs, endMs: endMs));
        }
      } else {
        result.add(WordSegment(wordIndex: fromIdx, startMs: startMs, endMs: endMs));
      }
    }
    return result;
  }

  int? findWordAtTime(List<AyahSegments> segments, String verseKey, int currentTimeMs) {
    final ayahSegments = segments.where((s) => s.verseKey == verseKey).firstOrNull;
    if (ayahSegments == null) return null;

    for (final seg in ayahSegments.segments) {
      if (currentTimeMs >= seg.startMs && currentTimeMs < seg.endMs) {
        return seg.wordIndex;
      }
    }
    return null;
  }

  List<int> findWordsAtTime(List<AyahSegments> segments, String verseKey, int currentTimeMs) {
    final ayahSegments = segments.where((s) => s.verseKey == verseKey).firstOrNull;
    if (ayahSegments == null) return [];

    final set = <int>{};
    for (final seg in ayahSegments.segments) {
      if (currentTimeMs >= seg.startMs && currentTimeMs < seg.endMs) {
        set.add(seg.wordIndex);
      }
    }
    return set.toList();
  }

  int? findWordStartMs(List<AyahSegments> segments, String verseKey, int wordIndex) {
    final ayahSegments = segments.where((s) => s.verseKey == verseKey).firstOrNull;
    if (ayahSegments == null || ayahSegments.segments.isEmpty) return null;

    final seg = ayahSegments.segments.where((s) => s.wordIndex == wordIndex || s.wordIndex == wordIndex + 1).firstOrNull;
    return seg?.startMs;
  }

  ({int arStartMs, int arEndMs}) getArabicClauseTimings({
    required String verseKey,
    required List<int> wordIndices,
    required List<AyahSegments> reciterSegments,
    required double arabicAudioDurationSec,
    required int totalWordsInAyah,
  }) {
    if (wordIndices.isEmpty) {
      return (
        arStartMs: 0,
        arEndMs: ((arabicAudioDurationSec > 0 ? arabicAudioDurationSec : 5) * 1000).round(),
      );
    }

    final minWord = wordIndices.reduce(min);
    final maxWord = wordIndices.reduce(max);

    final ayahSegs = reciterSegments.where((s) => s.verseKey == verseKey).firstOrNull;
    if (ayahSegs != null && ayahSegs.segments.isNotEmpty) {
      final segMin = ayahSegs.segments.where(
        (s) => s.wordIndex == minWord || s.wordIndex == minWord + 1,
      ).firstOrNull;
      final reversed = ayahSegs.segments.reversed;
      final segMax = reversed.where(
        (s) => s.wordIndex == maxWord || s.wordIndex == maxWord + 1,
      ).firstOrNull;

      if (segMin != null && segMax != null) {
        return (
          arStartMs: segMin.startMs,
          arEndMs: max(segMax.endMs, segMin.startMs + 500),
        );
      }
    }

    // Fallback: Proportional calculation
    final totalW = max(totalWordsInAyah, max(maxWord + 1, 1));
    final totalMs = ((arabicAudioDurationSec > 0 ? arabicAudioDurationSec : 6) * 1000).round();
    final arStartMs = ((minWord / totalW) * totalMs).round();
    final arEndMs = (((maxWord + 1) / totalW) * totalMs).round();

    return (
      arStartMs: arStartMs,
      arEndMs: max(arEndMs, arStartMs + 500),
    );
  }
}
