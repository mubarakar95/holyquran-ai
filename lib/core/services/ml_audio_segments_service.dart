import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gemini_toast_event.dart';
import '../models/quran_types.dart';
import 'quran_data_service.dart';
import 'ar_ml_alignments_service.dart';
import 'gemini_alignment_service.dart';

final RegExp _waqfRegex = RegExp(r'[\u06D6-\u06DC]');

List<AyahClause> sanitizeClauses(List<AyahClause> clauses, [int? totalAudioDurationMs]) {
  if (clauses.isEmpty) return [];
  if (clauses.length == 1) {
    final end = max(clauses[0].endMs, max(totalAudioDurationMs ?? 0, 1000));
    return [
      AyahClause(
        startMs: 0,
        endMs: end,
        wordIndices: clauses[0].wordIndices,
        phrase: clauses[0].phrase,
      )
    ];
  }

  final result = <AyahClause>[];
  int currentStart = 0;

  for (int i = 0; i < clauses.length; i++) {
    final c = clauses[i];
    final isLast = i == clauses.length - 1;

    final startMs = max(c.startMs, currentStart);
    int endMs = max(c.endMs, startMs + 300);

    if (isLast) {
      if (totalAudioDurationMs != null && totalAudioDurationMs > startMs) {
        endMs = max(endMs, totalAudioDurationMs);
      }
    } else {
      if (totalAudioDurationMs != null && endMs >= totalAudioDurationMs - 500) {
        final remaining = totalAudioDurationMs - startMs;
        final remainingClauses = clauses.length - i;
        endMs = startMs + max(500, (remaining / remainingClauses).round());
      }
    }

    result.add(AyahClause(
      startMs: startMs,
      endMs: endMs,
      wordIndices: c.wordIndices,
      phrase: c.phrase,
    ));

    currentStart = endMs;
  }

  return result;
}

List<AyahClause> extractAyahClauses(
  String verseKey,
  List<WordSegment> segments, {
  String? arabicText,
  List<AyahClause>? existingClauses,
}) {
  final totalMs = segments.isNotEmpty ? segments.map((s) => s.endMs).reduce(max) : 0;
  if (existingClauses != null && existingClauses.isNotEmpty) {
    return sanitizeClauses(existingClauses, totalMs);
  }
  if (segments.isEmpty) return [];

  // Group by distinct timestamps
  final groups = <String, Map<String, dynamic>>{};
  for (final seg in segments) {
    final key = '${seg.startMs}_${seg.endMs}';
    if (!groups.containsKey(key)) {
      groups[key] = {
        'startMs': seg.startMs,
        'endMs': seg.endMs,
        'wordIndices': <int>[],
      };
    }
    (groups[key]!['wordIndices'] as List<int>).add(seg.wordIndex);
  }

  if (groups.length > 1) {
    final reconstructed = groups.values.map((g) {
      return AyahClause(
        startMs: g['startMs'] as int,
        endMs: g['endMs'] as int,
        wordIndices: (g['wordIndices'] as List<int>),
      );
    }).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return sanitizeClauses(reconstructed, totalMs);
  }

  final maxWord = segments.map((s) => s.wordIndex).reduce(max);
  final totalWords = maxWord + 1;

  // Split by Waqf stop marks if present
  if (arabicText != null && arabicText.isNotEmpty) {
    final words = arabicText.trim().split(RegExp(r'\s+'));
    final waqfIndices = <int>[];
    for (int idx = 0; idx < words.length - 1; idx++) {
      if (_waqfRegex.hasMatch(words[idx])) {
        waqfIndices.add(idx);
      }
    }

    if (waqfIndices.isNotEmpty) {
      final clauses = <AyahClause>[];
      int prevStop = -1;
      final allStops = [...waqfIndices, words.length - 1];
      int currentStart = 0;

      for (int sIdx = 0; sIdx < allStops.length; sIdx++) {
        final stopIdx = allStops[sIdx];
        final isLast = sIdx == allStops.length - 1;
        final sliceWords = [for (int w = prevStop + 1; w <= stopIdx; w++) w];
        prevStop = stopIdx;

        int splitMs;
        if (isLast) {
          splitMs = totalMs;
        } else {
          final segsThis = segments.where((s) => sliceWords.contains(s.wordIndex));
          final thisMax = segsThis.isNotEmpty ? segsThis.map((s) => s.endMs).reduce(max) : 0;
          final propMs = (totalMs * ((stopIdx + 1) / totalWords)).round();
          if (thisMax > currentStart && thisMax < totalMs) {
            splitMs = min(max(thisMax, propMs - 1500), propMs + 1500);
          } else {
            splitMs = propMs;
          }
          splitMs = max(currentStart + 1000, min(splitMs, totalMs - 1000));
        }

        clauses.add(AyahClause(
          startMs: currentStart,
          endMs: splitMs,
          wordIndices: sliceWords,
        ));
        currentStart = splitMs;
      }

      if (clauses.length > 1) {
        return sanitizeClauses(clauses, totalMs);
      }
    }
  }

  // Partition long ayahs (>= 7 words)
  if (totalWords >= 7) {
    final partsCount = totalWords >= 20 ? 4 : totalWords >= 12 ? 3 : 2;
    final wordsPerPart = (totalWords / partsCount).ceil();
    final clauses = <AyahClause>[];
    int currentStart = 0;

    for (int p = 0; p < partsCount; p++) {
      final startW = p * wordsPerPart;
      final endW = min(totalWords - 1, (p + 1) * wordsPerPart - 1);
      if (startW > endW) break;

      final words = [for (int w = startW; w <= endW; w++) w];
      final isLast = p == partsCount - 1 || endW == totalWords - 1;

      int splitMs;
      if (isLast) {
        splitMs = totalMs;
      } else {
        final segsThis = segments.where((s) => words.contains(s.wordIndex));
        final thisMax = segsThis.isNotEmpty ? segsThis.map((s) => s.endMs).reduce(max) : 0;
        final propMs = (totalMs * ((endW + 1) / totalWords)).round();
        if (thisMax > currentStart && thisMax < totalMs) {
          splitMs = min(max(thisMax, propMs - 1500), propMs + 1500);
        } else {
          splitMs = propMs;
        }
        splitMs = max(currentStart + 1000, min(splitMs, totalMs - 1000));
      }

      clauses.add(AyahClause(
        startMs: currentStart,
        endMs: splitMs,
        wordIndices: words,
      ));
      currentStart = splitMs;
    }

    if (clauses.length > 1) {
      return sanitizeClauses(clauses, totalMs);
    }
  }

  return sanitizeClauses([
    AyahClause(
      startMs: 0,
      endMs: max(totalMs, 1000),
      wordIndices: segments.map((s) => s.wordIndex).toList(),
    )
  ], totalMs);
}

class MlAudioSegmentsService {
  final QuranDataService _quranDataService;
  final ArMlAlignmentsService? _arMlAlignmentsService;
  final GeminiAlignmentService? _geminiAlignmentService;
  final Map<String, AyahSegments> _cache = {};

  MlAudioSegmentsService(
    this._quranDataService, [
    this._arMlAlignmentsService,
    this._geminiAlignmentService,
  ]);

  Future<Map<String, AyahSegments>> fetchPageSegments(
    int pageNumber,
    List<String> pageVerseKeys, {
    String? targetVerseKey,
    String? geminiApiKey,
    void Function(GeminiToastEvent)? onToast,
  }) async {
    final result = <String, AyahSegments>{};

    List<String> effectiveKeys = pageVerseKeys;
    if (effectiveKeys.isEmpty) {
      try {
        final map = await _quranDataService.loadVersePageMap();
        effectiveKeys = map.entries.where((e) => e.value == pageNumber).map((e) => e.key).toList();
      } catch (_) {}
    }

    final missingKeys = <String>[];
    for (final vk in effectiveKeys) {
      if (_cache.containsKey(vk)) {
        result[vk] = _cache[vk]!;
      } else {
        missingKeys.add(vk);
      }
    }

    if (missingKeys.isEmpty) return result;

    // 1. Load phrase alignments (local cache + Supabase)
    final localAlignments = await _quranDataService.loadLocalAlignments();
    Map<String, List<PhraseAlignment>> pageAlignments = {};
    final alignmentService = _arMlAlignmentsService;
    if (alignmentService != null) {
      try {
        pageAlignments = await alignmentService.fetchPageAlignments(
          pageNumber,
          effectiveKeys,
          targetVerseKey: targetVerseKey,
          geminiApiKey: geminiApiKey,
          onToast: onToast,
        );
      } catch (e) {
        debugPrint('[MlAudioSegmentsService] Error loading page alignments: $e');
      }
    }

    // 2. Query Supabase for ml_word_timestamps
    try {
      final client = Supabase.instance.client;
      final surahs = <int>{};
      final ayahs = <int>{};
      for (final vk in missingKeys) {
        final parts = vk.split(':');
        surahs.add(int.parse(parts[0]));
        ayahs.add(int.parse(parts[1]));
      }

      final rows = await client
          .from('ml_word_timestamps')
          .select('surah_number, ayah_number, segments')
          .inFilter('surah_number', surahs.toList())
          .inFilter('ayah_number', ayahs.toList());

      for (final row in rows) {
        final vk = '${row['surah_number']}:${row['ayah_number']}';
        if (!missingKeys.contains(vk)) continue;
        final raw = row['segments'];
        List<WordSegment> wordSegs = [];
        List<AyahClause>? clauses;

        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          if (m['words'] is List) {
            wordSegs = (m['words'] as List)
                .map((e) => WordSegment.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
          if (m['clauses'] is List) {
            clauses = (m['clauses'] as List)
                .map((e) => AyahClause.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
        } else if (raw is List) {
          wordSegs = raw
              .map((e) => WordSegment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

        // Find phrase alignments for this verse
        List<PhraseAlignment>? paList = pageAlignments[vk];
        if (paList == null && localAlignments.containsKey(vk)) {
          final rawPa = localAlignments[vk];
          if (rawPa is List) {
            paList = rawPa
                .map((e) => PhraseAlignment.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
        }

        // Build fully enriched clauses (connecting audio timestamps with full Arabic clause words)
        clauses = _buildClausesForAyah(vk, wordSegs, paList, clauses);

        final ayahSegs = AyahSegments(verseKey: vk, segments: wordSegs, clauses: clauses);
        _cache[vk] = ayahSegs;
        result[vk] = ayahSegs;
      }
    } catch (e) {
      debugPrint('[MlAudioSegmentsService] Error querying Supabase ml_word_timestamps: $e');
    }

    // 3. Fallback for any verses missing from Supabase ml_word_timestamps
    for (final vk in missingKeys) {
      if (!result.containsKey(vk)) {
        List<PhraseAlignment>? paList = pageAlignments[vk];
        if (paList == null && localAlignments.containsKey(vk)) {
          final rawPa = localAlignments[vk];
          if (rawPa is List) {
            paList = rawPa
                .map((e) => PhraseAlignment.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
        }

        // If alignments are missing, query Gemini ONLY if this is the active targetVerseKey and key is present
        if (vk == targetVerseKey) {
          final gemini = _geminiAlignmentService;
          if (gemini != null && gemini.hasApiKey(geminiApiKey)) {
            final parts = vk.split(':');
            final surah = int.tryParse(parts[0]) ?? 0;
            final ayah = int.tryParse(parts[1]) ?? 0;
            if (surah > 0 && ayah > 0) {
              try {
                final geminiClauses = await gemini.extractAudioClauseTimestamps(
                  surahNumber: surah,
                  ayahNumber: ayah,
                  apiKey: geminiApiKey ?? '',
                  onToast: onToast,
                );
                if (geminiClauses != null && geminiClauses.isNotEmpty) {
                  final ayahSegs = AyahSegments(verseKey: vk, segments: const [], clauses: geminiClauses);
                  _cache[vk] = ayahSegs;
                  result[vk] = ayahSegs;
                  continue;
                }

                paList = await gemini.generatePhraseAlignments(
                  surahNumber: surah,
                  ayahNumber: ayah,
                  apiKey: geminiApiKey ?? '',
                  onToast: onToast,
                );
                if (paList != null && paList.isNotEmpty) {
                  _arMlAlignmentsService?.cacheAlignment(vk, paList);
                }
              } catch (e) {
                debugPrint('[MlAudioSegmentsService] Gemini extraction error for $vk: $e');
              }
            }
          }
        }

        // When no acoustic speech timestamps exist, use a clean unsegmented verse clause.
        // Never invent fake proportional word durations.
        final defaultClauses = [AyahClause(startMs: 0, endMs: 999999, wordIndices: const [])];
        final ayahSegs = AyahSegments(verseKey: vk, segments: const [], clauses: defaultClauses);
        _cache[vk] = ayahSegs;
        result[vk] = ayahSegs;
      }
    }

    return result;
  }

  List<AyahClause> _buildClausesForAyah(
    String verseKey,
    List<WordSegment> wordSegs,
    List<PhraseAlignment>? phraseAlignments,
    List<AyahClause>? existingClauses,
  ) {
    if (existingClauses != null && existingClauses.isNotEmpty) {
      return sanitizeClauses(existingClauses);
    }

    if (wordSegs.isEmpty) {
      return [AyahClause(startMs: 0, endMs: 999999, wordIndices: const [])];
    }

    final totalMs = wordSegs.map((s) => s.endMs).reduce(max);

    if (phraseAlignments != null && phraseAlignments.isNotEmpty) {
      final clauses = <AyahClause>[];

      for (int i = 0; i < phraseAlignments.length; i++) {
        final pa = phraseAlignments[i];
        final zeroIndexedWords = pa.arabicPositions.map((p) => p - 1).toList();

        // Try to find segments whose wordIndex matches any word in this phrase
        final matchingSegs = wordSegs.where((s) => zeroIndexedWords.contains(s.wordIndex)).toList();

        int startMs;
        int endMs;

        if (matchingSegs.isNotEmpty) {
          startMs = matchingSegs.map((s) => s.startMs).reduce(min);
          endMs = matchingSegs.map((s) => s.endMs).reduce(max);
        } else if (i < wordSegs.length) {
          startMs = wordSegs[i].startMs;
          endMs = wordSegs[i].endMs;
        } else {
          continue;
        }

        clauses.add(AyahClause(
          startMs: startMs,
          endMs: endMs,
          wordIndices: zeroIndexedWords,
          phrase: pa.phrase,
        ));
      }

      if (clauses.isNotEmpty) {
        return sanitizeClauses(clauses, totalMs > 0 ? totalMs : null);
      }
    }

    return extractAyahClauses(verseKey, wordSegs);
  }
}
