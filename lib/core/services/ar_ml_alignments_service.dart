import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gemini_toast_event.dart';
import 'gemini_alignment_service.dart';
import 'quran_data_service.dart';

class PhraseAlignment {
  final String phrase;
  final List<int> arabicPositions;

  const PhraseAlignment({
    required this.phrase,
    required this.arabicPositions,
  });

  factory PhraseAlignment.fromJson(Map<String, dynamic> json) {
    return PhraseAlignment(
      phrase: json['phrase'] as String? ?? '',
      arabicPositions: (json['arabicPositions'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'phrase': phrase,
    'arabicPositions': arabicPositions,
  };
}

class ArMlAlignmentsService {
  final QuranDataService _quranDataService;
  final GeminiAlignmentService? _geminiAlignmentService;
  final Map<String, List<PhraseAlignment>> _cache = {};

  ArMlAlignmentsService(this._quranDataService, [this._geminiAlignmentService]);

  void cacheAlignment(String verseKey, List<PhraseAlignment> list) {
    _cache[verseKey] = list;
  }

  Future<Map<String, List<PhraseAlignment>>> fetchPageAlignments(
    int pageNumber,
    List<String> pageVerseKeys, {
    String? targetVerseKey,
    String? geminiApiKey,
    void Function(GeminiToastEvent)? onToast,
  }) async {
    final result = <String, List<PhraseAlignment>>{};
    final missingKeys = <String>[];

    // 1. Check memory cache
    for (final vk in pageVerseKeys) {
      if (_cache.containsKey(vk)) {
        result[vk] = _cache[vk]!;
      } else {
        missingKeys.add(vk);
      }
    }

    if (missingKeys.isEmpty) return result;

    // 2. Check local bundled alignments JSON
    final localAlignments = await _quranDataService.loadLocalAlignments();
    final stillMissing = <String>[];

    for (final vk in missingKeys) {
      if (localAlignments.containsKey(vk)) {
        final list = (localAlignments[vk] as List<dynamic>)
            .map((e) => PhraseAlignment.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache[vk] = list;
        result[vk] = list;
      } else {
        stillMissing.add(vk);
      }
    }

    if (stillMissing.isEmpty) return result;

    // 3. Check Supabase cache
    try {
      final client = Supabase.instance.client;
      if (targetVerseKey != null && !stillMissing.contains(targetVerseKey)) {
        stillMissing.add(targetVerseKey);
      }
      final surahs = <int>{};
      final ayahs = <int>{};
      for (final vk in stillMissing) {
        final parts = vk.split(':');
        surahs.add(int.parse(parts[0]));
        ayahs.add(int.parse(parts[1]));
      }

      final rows = await client
          .from('ar_ml_alignments')
          .select('surah_number, ayah_number, alignment')
          .inFilter('surah_number', surahs.toList())
          .inFilter('ayah_number', ayahs.toList());

      for (final row in rows) {
        final vk = '${row['surah_number']}:${row['ayah_number']}';
        if (!stillMissing.contains(vk)) continue;
        final raw = row['alignment'] ?? row['alignments'];
        if (raw is List) {
          final list = raw
              .map((e) => PhraseAlignment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _cache[vk] = list;
          result[vk] = list;
        }
      }
    } catch (e) {
      debugPrint('[ArMlAlignmentsService] Error fetching alignments from Supabase: $e');
    }

    // 4. On-demand Gemini AI generation: ONLY if a specific targetVerseKey was requested and missing
    final gemini = _geminiAlignmentService;
    if (gemini != null && targetVerseKey != null && !result.containsKey(targetVerseKey)) {
      final parts = targetVerseKey.split(':');
      final s = int.tryParse(parts[0]) ?? 0;
      final a = int.tryParse(parts[1]) ?? 0;
      if (s > 0 && a > 0) {
        try {
          final phrases = await gemini.generatePhraseAlignments(
            surahNumber: s,
            ayahNumber: a,
            apiKey: geminiApiKey ?? '',
            onToast: onToast,
          );
          if (phrases != null && phrases.isNotEmpty) {
            _cache[targetVerseKey] = phrases;
            result[targetVerseKey] = phrases;
          }
        } catch (_) {}
      }
    }

    return result;
  }
}
