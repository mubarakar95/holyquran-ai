import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_easy_native/core/services/quran_data_service.dart';
import 'package:quran_easy_native/core/services/ar_ml_alignments_service.dart';
import 'package:quran_easy_native/core/services/ml_audio_segments_service.dart';
import 'package:quran_easy_native/core/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('Verify Malayalam audio clauses extraction with alignments', () async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseService.initialize();
    final qds = QuranDataService();
    final ams = ArMlAlignmentsService(qds);
    final service = MlAudioSegmentsService(qds, ams);

    final result = await service.fetchPageSegments(3, ['2:6', '2:7']);
    expect(result.containsKey('2:6'), isTrue);

    final seg2_6 = result['2:6']!;
    expect(seg2_6.clauses, isNotNull);
    expect(seg2_6.clauses!.isNotEmpty, isTrue);

    // First clause of 2:6 should cover words [0, 1, 2] (إِنَّ الَّذِينَ كَفَرُوا)
    expect(seg2_6.clauses![0].wordIndices, containsAll([0, 1, 2]));
  });
}
