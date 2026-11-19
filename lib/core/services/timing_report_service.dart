import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timing_report.dart';
import 'supabase_service.dart';

class TimingReportService {
  static const String _prefKey = 'reported_timing_ayah_keys';

  final SharedPreferences? _prefs;

  TimingReportService([this._prefs]);

  /// Get the set of verse keys (e.g. '2:187') reported locally on this device.
  Set<String> getLocalReportedKeys() {
    if (_prefs == null) return {};
    final list = _prefs.getStringList(_prefKey) ?? [];
    return list.toSet();
  }

  /// Check if a verse key is marked as reported locally.
  bool isVerseReported(String verseKey) {
    return getLocalReportedKeys().contains(verseKey);
  }

  /// Mark a verse key as reported locally.
  Future<void> _markLocalReported(String verseKey) async {
    if (_prefs == null) return;
    final set = getLocalReportedKeys();
    set.add(verseKey);
    await _prefs.setStringList(_prefKey, set.toList());
  }

  /// Submit a timing report for an Ayah to Supabase and cache it locally.
  Future<bool> reportTimingIssue({
    required int surahNumber,
    required int ayahNumber,
    required String issueType,
    String? note,
  }) async {
    final report = TimingReport(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      issueType: issueType,
      note: note,
      status: 'pending',
      reportedAt: DateTime.now(),
    );

    final verseKey = '$surahNumber:$ayahNumber';

    try {
      // 1. Try via Supabase SDK if initialized
      bool sdkSuccess = false;
      try {
        final client = Supabase.instance.client;
        final response = await client
            .from('ml_word_timestamps')
            .select('segments')
            .eq('surah_number', surahNumber)
            .eq('ayah_number', ayahNumber)
            .maybeSingle();

        Map<String, dynamic> segmentsMap = {};
        if (response != null && response['segments'] is Map) {
          segmentsMap = Map<String, dynamic>.from(response['segments'] as Map);
        }
        segmentsMap['report'] = report.toJson();

        await client.from('ml_word_timestamps').upsert({
          'surah_number': surahNumber,
          'ayah_number': ayahNumber,
          'segments': segmentsMap,
          'generated_at': DateTime.now().toUtc().toIso8601String(),
        });
        sdkSuccess = true;
      } catch (e) {
        debugPrint('⚠️ Supabase SDK report failed, attempting direct PostgREST: $e');
      }

      // 2. Direct HTTP PostgREST fallback if SDK wasn't ready or encountered an error
      if (!sdkSuccess) {
        final getUrl = Uri.parse(
          '$SUPABASE_URL/rest/v1/ml_word_timestamps?surah_number=eq.$surahNumber&ayah_number=eq.$ayahNumber',
        );
        final getResp = await http.get(getUrl, headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': 'Bearer $SUPABASE_ANON_KEY',
        });

        Map<String, dynamic> segmentsMap = {};
        if (getResp.statusCode == 200) {
          final list = json.decode(getResp.body) as List;
          if (list.isNotEmpty && list[0]['segments'] is Map) {
            segmentsMap = Map<String, dynamic>.from(list[0]['segments'] as Map);
          }
        }
        segmentsMap['report'] = report.toJson();

        final upsertUrl = Uri.parse(
          '$SUPABASE_URL/rest/v1/ml_word_timestamps?on_conflict=surah_number,ayah_number',
        );
        final postResp = await http.post(
          upsertUrl,
          headers: {
            'apikey': SUPABASE_ANON_KEY,
            'Authorization': 'Bearer $SUPABASE_ANON_KEY',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: json.encode({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'segments': segmentsMap,
            'generated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        if (postResp.statusCode >= 300) {
          debugPrint('❌ PostgREST report failed with code ${postResp.statusCode}: ${postResp.body}');
          return false;
        }
      }

      // 3. Mark in local preferences
      await _markLocalReported(verseKey);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to report timing issue: $e');
      return false;
    }
  }
}
