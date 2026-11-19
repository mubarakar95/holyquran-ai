import 'package:flutter_test/flutter_test.dart';
import 'package:quran_easy_native/core/models/quran_types.dart';
import 'package:quran_easy_native/core/services/offline_audio_service.dart';

void main() {
  group('OfflineAudioService & Audio Helpers', () {
    test('Calculates global ayah number correctly', () {
      // Surah 1 Ayah 1 -> Global Ayah 1
      expect(getGlobalAyahNumber(1, 1), 1);
      // Surah 1 Ayah 7 -> Global Ayah 7
      expect(getGlobalAyahNumber(1, 7), 7);
      // Surah 2 Ayah 1 -> Global Ayah 8
      expect(getGlobalAyahNumber(2, 1), 8);
      // Surah 2 Ayah 286 -> Global Ayah 293
      expect(getGlobalAyahNumber(2, 286), 293);
      // Surah 114 Ayah 6 -> Global Ayah 6236 (total ayahs in Quran)
      expect(getGlobalAyahNumber(114, 6), 6236);
    });

    test('Generates correct remote audio URLs', () {
      final alafasy = RECITERS.firstWhere((r) => r.id == 'ar.alafasy');
      final alafasyUrl = getRemoteAudioUrl(alafasy, 1, 1);
      expect(alafasyUrl, 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3');

      final mlUrl = getRemoteMalayalamAudioUrl(1, 1);
      expect(mlUrl, 'https://lalithasaram.net/audio/qtaud/transl/001_001.mp3');

      final mlUrlBaqarah = getRemoteMalayalamAudioUrl(2, 255);
      expect(mlUrlBaqarah, 'https://lalithasaram.net/audio/qtaud/transl/002_255.mp3');
    });

    test('SurahDownloadInfo progress and completeness calculations', () {
      const empty = SurahDownloadInfo(
        surahNumber: 1,
        downloadedCount: 0,
        totalAyahs: 7,
        totalBytes: 0,
      );
      expect(empty.isComplete, false);
      expect(empty.isPartial, false);
      expect(empty.progress, 0.0);

      const partial = SurahDownloadInfo(
        surahNumber: 1,
        downloadedCount: 3,
        totalAyahs: 7,
        totalBytes: 1024 * 500,
      );
      expect(partial.isComplete, false);
      expect(partial.isPartial, true);
      expect((partial.progress * 100).round(), 43);

      const complete = SurahDownloadInfo(
        surahNumber: 1,
        downloadedCount: 7,
        totalAyahs: 7,
        totalBytes: 1024 * 1200,
      );
      expect(complete.isComplete, true);
      expect(complete.isPartial, false);
      expect(complete.progress, 1.0);
    });
  });
}
