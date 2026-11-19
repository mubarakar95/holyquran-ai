import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gemini_toast_event.dart';
import '../models/quran_types.dart';
import 'ar_ml_alignments_service.dart';
import 'offline_audio_service.dart';
import 'quran_data_service.dart';

const List<String> GEMINI_MODELS = [
  'gemini-3.8-flash',
  'gemini-3.5-flash',
  'gemini-flash-latest',
  'gemini-3.5-flash-lite',
];

class GeminiAlignmentService {
  final Dio _dio;
  final QuranDataService _quranDataService;
  final OfflineAudioService _offlineAudioService;
  String _activeModel = GEMINI_MODELS[0];
  DateTime? _quotaExceededUntil;

  bool get isQuotaExceeded =>
      _quotaExceededUntil != null && DateTime.now().isBefore(_quotaExceededUntil!);

  GeminiAlignmentService(
    this._quranDataService,
    this._offlineAudioService, [
    Dio? dio,
  ]) : _dio = dio ?? Dio();

  String resolveApiKey(String? userKey) {
    if (userKey != null && userKey.trim().isNotEmpty) {
      return userKey.trim();
    }
    return '';
  }

  bool hasApiKey(String? userKey) => resolveApiKey(userKey).isNotEmpty;

  /// Extracts phrase alignments between Arabic words and Malayalam translation using Gemini
  Future<List<PhraseAlignment>?> generatePhraseAlignments({
    required int surahNumber,
    required int ayahNumber,
    required String apiKey,
    void Function(GeminiToastEvent)? onToast,
  }) async {
    if (isQuotaExceeded) return null;
    final effectiveKey = resolveApiKey(apiKey);
    if (effectiveKey.isEmpty) return null;
    final vk = '$surahNumber:$ayahNumber';

    // 1. Get Arabic text for this ayah
    String arabicText = '';
    try {
      arabicText = await _quranDataService.getAyahArabicText(surahNumber, ayahNumber) ?? '';
    } catch (_) {}

    if (arabicText.isEmpty) return null;

    // 2. Get Malayalam translation
    String mlText = '';
    try {
      final res = await _dio.get(
        'https://api.alquran.cloud/v1/ayah/$vk/ml.karakunnu',
        options: Options(headers: {"User-Agent": "QuranEasyMalayalam/1.0"}),
      );
      if (res.statusCode == 200 && res.data != null) {
        mlText = res.data['data']?['text'] ?? '';
      }
    } catch (_) {}

    if (mlText.isEmpty) return null;

    final arabicWordList = arabicText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final numberedArabic = arabicWordList.asMap().entries.map((e) => '${e.key + 1}: ${e.value}').join(', ');

    final prompt = '''You are an expert Quran linguist in Arabic and Malayalam.
Given the numbered Arabic words of Surah $surahNumber, Ayah $ayahNumber and its complete Malayalam translation:

Arabic Words:
$numberedArabic

Malayalam Translation:
$mlText

Segment the Malayalam translation into ordered phrases that match the Arabic words.
Return ONLY valid JSON matching this schema:
{
  "phrases": [
    {
      "phrase": "exact Malayalam substring from the translation",
      "arabicPositions": [1, 2, 3]
    }
  ]
}

Rules:
1. Concatenating all phrases in order MUST reconstruct the exact Malayalam translation text without losing words.
2. arabicPositions MUST contain 1-based indices corresponding to the Arabic words above.
3. Every Arabic word position (from 1 to ${arabicWordList.length}) must be mapped.''';

    onToast?.call(GeminiToastEvent(
      id: 'gemini-align-$vk',
      title: 'Gemini Aligning',
      message: 'Extracting Arabic-Malayalam phrase alignment for $vk...',
      status: GeminiToastStatus.loading,
      model: _activeModel,
    ));

    final modelsToTry = [_activeModel, ...GEMINI_MODELS.where((m) => m != _activeModel)];

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: effectiveKey,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text == null || text.trim().isEmpty) continue;

        String cleaned = text.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '').replaceAll('```', '').trim();
        final startIdx = cleaned.indexOf('{');
        final endIdx = cleaned.lastIndexOf('}');
        if (startIdx != -1 && endIdx != -1) {
          cleaned = cleaned.substring(startIdx, endIdx + 1);
        }

        final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
        final rawPhrases = decoded['phrases'] as List<dynamic>?;
        if (rawPhrases == null || rawPhrases.isEmpty) continue;

        final phrases = rawPhrases.map((e) => PhraseAlignment.fromJson(Map<String, dynamic>.from(e as Map))).toList();

        _activeModel = modelName;

        // Save to Supabase for all users
        try {
          final client = Supabase.instance.client;
          await client.from('ar_ml_alignments').upsert({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'alignment': phrases.map((p) => p.toJson()).toList(),
          }, onConflict: 'surah_number,ayah_number');
          debugPrint('[GeminiAlignmentService] Successfully cached $vk alignment to Supabase');
        } catch (e) {
          debugPrint('[GeminiAlignmentService] Failed to cache alignment in Supabase: $e');
        }

        onToast?.call(GeminiToastEvent(
          id: 'gemini-align-$vk',
          title: 'Gemini Alignment Active',
          message: 'Phrases aligned with Arabic words ($modelName)',
          status: GeminiToastStatus.success,
          model: modelName,
        ));

        return phrases;
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('quota') || errStr.contains('429') || errStr.contains('exceeded') || errStr.contains('rate-limit')) {
          _quotaExceededUntil = DateTime.now().add(const Duration(minutes: 30));
          debugPrint('[GeminiAlignmentService] Quota exceeded. Cooldown active for 30 minutes.');
          break;
        }
        debugPrint('[GeminiAlignmentService] Model $modelName failed for phrase alignment: $e');
      }
    }

    onToast?.call(GeminiToastEvent(
      id: 'gemini-align-$vk',
      title: 'Default Timing Used',
      message: 'AI alignment unavailable. Using standard timing.',
      status: GeminiToastStatus.fallback,
    ));

    return null;
  }

  /// Analyzes spoken Malayalam audio and extracts clause timestamps aligned to Arabic words
  Future<List<AyahClause>?> extractAudioClauseTimestamps({
    required int surahNumber,
    required int ayahNumber,
    required String apiKey,
    void Function(GeminiToastEvent)? onToast,
  }) async {
    if (isQuotaExceeded) return null;
    final effectiveKey = resolveApiKey(apiKey);
    if (effectiveKey.isEmpty) return null;
    final vk = '$surahNumber:$ayahNumber';

    // 1. Get Arabic text for word indices
    String arabicText = '';
    try {
      arabicText = await _quranDataService.getAyahArabicText(surahNumber, ayahNumber) ?? '';
    } catch (_) {}

    final arabicWords = arabicText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (arabicWords.isEmpty) return null;

    // 2. Get Malayalam translation text
    String mlText = '';
    try {
      final res = await _dio.get(
        'https://api.alquran.cloud/v1/ayah/$vk/ml.karakunnu',
        options: Options(headers: {"User-Agent": "QuranEasyMalayalam/1.0"}),
      );
      if (res.statusCode == 200 && res.data != null) {
        mlText = res.data['data']?['text'] ?? '';
      }
    } catch (_) {}

    // 3. Obtain audio bytes (check local downloaded file first, else fetch network)
    Uint8List? audioBytes;
    final localPath = await _offlineAudioService.getLocalAudioPathIfExists('malayalam', surahNumber, ayahNumber);
    if (localPath != null) {
      try {
        final f = await _offlineAudioService.getAudioFile('malayalam', surahNumber, ayahNumber);
        audioBytes = await f.readAsBytes();
      } catch (_) {}
    }

    if (audioBytes == null || audioBytes.isEmpty) {
      try {
        final url = getRemoteMalayalamAudioUrl(surahNumber, ayahNumber);
        final res = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
          ),
        );
        if (res.statusCode == 200 && res.data != null) {
          audioBytes = Uint8List.fromList(res.data!);
        }
      } catch (_) {}
    }

    if (audioBytes == null || audioBytes.isEmpty) return null;

    final wordList = arabicWords.asMap().entries.map((e) => '${e.key}: ${e.value}').join('\n');

    final prompt = '''You are analyzing Malayalam translation audio (Lalithasaram narration) for the Holy Quran.
Ayah: $surahNumber:$ayahNumber (${arabicWords.length} Arabic words)
Malayalam translation text (as spoken in narration):
$mlText

Arabic words (0-indexed):
$wordList

The narrator speaks in natural Malayalam clauses/sentences according to meaning-completion stops.
Your task: listen carefully to the Malayalam audio and segment it into sequential clauses.
For each spoken clause, provide:
- "startMs": integer millisecond timestamp when narrator starts speaking this clause
- "endMs": integer millisecond timestamp when narrator finishes speaking this clause
- "wordIndices": array of contiguous 0-based Arabic word indices that correspond to the meaning of this spoken clause.

CRITICAL RULES:
- The "wordIndices" for each clause MUST be contiguous sequential slices of the verse covering from 0 to ${arabicWords.length - 1} in order (e.g. Clause 1 covers [0, 1, 2], Clause 2 covers [3, 4, 5], etc.) so that Arabic recitation can play sequentially for each clause.
- All Arabic words from 0 to ${arabicWords.length - 1} must be covered across the clauses.
- startMs and endMs must be integers (no decimals).
- Return ONLY a valid JSON array of clause objects with "startMs", "endMs", and "wordIndices". No explanation, no markdown backticks.

Example output:
[
  { "startMs": 0, "endMs": 6270, "wordIndices": [0, 1, 2, 3] },
  { "startMs": 6270, "endMs": 13750, "wordIndices": [4, 5, 6, 7] }
]''';

    onToast?.call(GeminiToastEvent(
      id: 'gemini-timing-$vk',
      title: 'Gemini Audio Analysis',
      message: 'Listening to Malayalam audio for Ayah $vk ($arabicWords words)...',
      status: GeminiToastStatus.loading,
      model: _activeModel,
    ));

    final modelsToTry = [_activeModel, ...GEMINI_MODELS.where((m) => m != _activeModel)];

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: effectiveKey,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );

        final response = await model.generateContent([
          Content.multi([
            DataPart('audio/mp3', audioBytes),
            TextPart(prompt),
          ]),
        ]);

        final text = response.text;
        if (text == null || text.trim().isEmpty) continue;

        String cleaned = text.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '').replaceAll('```', '').trim();
        final startIdx = cleaned.indexOf('[');
        final endIdx = cleaned.lastIndexOf(']');
        if (startIdx != -1 && endIdx != -1) {
          cleaned = cleaned.substring(startIdx, endIdx + 1);
        }

        final decoded = jsonDecode(cleaned) as List<dynamic>;
        if (decoded.isEmpty) continue;

        final clauses = <AyahClause>[];
        for (final item in decoded) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final sMs = (m['startMs'] as num?)?.toInt() ?? 0;
            final eMs = (m['endMs'] as num?)?.toInt() ?? 0;
            final wIndices = ((m['wordIndices'] as List<dynamic>?) ?? []).map((x) => (x as num).toInt()).toList();
            clauses.add(AyahClause(startMs: sMs, endMs: eMs, wordIndices: wIndices));
          }
        }

        if (clauses.isEmpty) continue;

        _activeModel = modelName;

        // Save to Supabase for all users
        try {
          final client = Supabase.instance.client;
          await client.from('ml_word_timestamps').upsert({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'segments': {
              'words': [],
              'clauses': clauses.map((c) => c.toJson()).toList(),
            },
          }, onConflict: 'surah_number,ayah_number');
          debugPrint('[GeminiAlignmentService] Successfully cached $vk audio timestamps to Supabase');
        } catch (e) {
          debugPrint('[GeminiAlignmentService] Failed to cache audio timestamps in Supabase: $e');
        }

        onToast?.call(GeminiToastEvent(
          id: 'gemini-timing-$vk',
          title: 'Gemini Timestamps Generated',
          message: 'Audio timestamps extracted successfully ($modelName)',
          status: GeminiToastStatus.success,
          model: modelName,
        ));

        return clauses;
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('quota') || errStr.contains('429') || errStr.contains('exceeded') || errStr.contains('rate-limit')) {
          _quotaExceededUntil = DateTime.now().add(const Duration(minutes: 30));
          debugPrint('[GeminiAlignmentService] Quota exceeded. Cooldown active for 30 minutes.');
          break;
        }
        debugPrint('[GeminiAlignmentService] Model $modelName failed for audio clause timestamps: $e');
      }
    }

    onToast?.call(GeminiToastEvent(
      id: 'gemini-timing-$vk',
      title: 'Default Timing Used',
      message: 'Audio analysis unavailable. Using standard timing.',
      status: GeminiToastStatus.fallback,
    ));

    return null;
  }
}
