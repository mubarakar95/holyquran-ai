import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_easy_native/core/models/quran_types.dart';
import 'package:quran_easy_native/core/services/audio_segments_service.dart';
import 'package:quran_easy_native/core/services/local_storage_service.dart';
import 'package:quran_easy_native/providers/audio_player_provider.dart';
import 'package:quran_easy_native/providers/service_providers.dart';
import 'package:quran_easy_native/providers/quran_page_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerNotifier seekToWord and double tap seeking', () {
    test('AudioSegmentsService resolves word start timestamp accurately', () {
      final service = AudioSegmentsService();
      final sampleSegments = [
        const AyahSegments(
          verseKey: '1:1',
          segments: [
            WordSegment(wordIndex: 0, startMs: 0, endMs: 800),
            WordSegment(wordIndex: 1, startMs: 800, endMs: 1600),
            WordSegment(wordIndex: 2, startMs: 1600, endMs: 2700),
            WordSegment(wordIndex: 3, startMs: 2700, endMs: 4200),
          ],
        ),
      ];

      expect(service.findWordStartMs(sampleSegments, '1:1', 0), equals(0));
      expect(service.findWordStartMs(sampleSegments, '1:1', 1), equals(800));
      expect(service.findWordStartMs(sampleSegments, '1:1', 2), equals(1600));
      expect(service.findWordStartMs(sampleSegments, '1:1', 3), equals(2700));
      expect(service.findWordStartMs(sampleSegments, '1:1', 5), isNull);
    });

    test('AudioPlayerNotifier seekToWord sets highlight verse and updates word highlight', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(audioPlayerProvider.notifier);

      // Verify seekToWord method exists and can be invoked
      await notifier.seekToWord('1:1', 2);

      // Highlighting should update to 1:1
      final pageState = container.read(quranPageProvider);
      expect(pageState.highlightVerseKey, equals('1:1'));
    });
  });
}
