import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_easy_native/core/services/local_storage_service.dart';
import 'package:quran_easy_native/core/services/offline_audio_service.dart';
import 'package:quran_easy_native/providers/service_providers.dart';
import 'package:quran_easy_native/ui/downloads/download_manager_screen.dart';

class FakeLocalStorage extends Fake implements LocalStorageService {
  @override
  String get theme => 'light';
  @override
  int get arFontSize => 100;
  @override
  int get mlFontSize => 100;
  @override
  int get lineHeight => 100;
  @override
  int get hoverDelay => 80;
  @override
  int get hoverFontSize => 18;
  @override
  String get geminiApiKey => '';
  @override
  String get ayahDress => 'hafs-adi';
  @override
  set ayahDress(String value) {}
  @override
  String get frameDress => 'madani';
  @override
  set frameDress(String value) {}
  @override
  String get surahHeaderDress => 'madani';
  @override
  set surahHeaderDress(String value) {}
  @override
  int get currentPage => 1;
  @override
  set currentPage(int value) {}
  @override
  bool get showTranslation => false;
  @override
  set showTranslation(bool value) {}
  @override
  String get reciterId => 'ar.alafasy';
  @override
  set reciterId(String value) {}
  @override
  String get repeatMode => 'none';
  @override
  set repeatMode(String value) {}
  @override
  double get arabicPlaybackRate => 1.0;
  @override
  set arabicPlaybackRate(double value) {}
  @override
  double get malayalamPlaybackRate => 1.0;
  @override
  set malayalamPlaybackRate(double value) {}
  @override
  bool get segmentedMode => true;
  @override
  set segmentedMode(bool value) {}
}

class MockOfflineAudioService extends Fake implements OfflineAudioService {
  final Map<String, Map<int, SurahDownloadInfo>> _store = {};

  MockOfflineAudioService() {
    _store['ar.alafasy'] = {
      1: const SurahDownloadInfo(
        surahNumber: 1,
        downloadedCount: 7,
        totalAyahs: 7,
        totalBytes: 1024 * 1024 * 2, // 2MB
      ),
      2: const SurahDownloadInfo(
        surahNumber: 2,
        downloadedCount: 100,
        totalAyahs: 286,
        totalBytes: 1024 * 1024 * 25, // 25MB partial
      ),
    };
    _store['malayalam'] = {
      1: const SurahDownloadInfo(
        surahNumber: 1,
        downloadedCount: 7,
        totalAyahs: 7,
        totalBytes: 1024 * 1024 * 3, // 3MB
      ),
    };
  }

  @override
  Future<Map<int, SurahDownloadInfo>> getAllSurahsDownloadInfo(String reciterKey) async {
    final map = <int, SurahDownloadInfo>{};
    for (int s = 1; s <= 114; s++) {
      final existing = _store[reciterKey]?[s];
      if (existing != null) {
        map[s] = existing;
      } else {
        map[s] = SurahDownloadInfo(
          surahNumber: s,
          downloadedCount: 0,
          totalAyahs: SURAH_AYAH_COUNTS[s - 1],
          totalBytes: 0,
        );
      }
    }
    return map;
  }

  @override
  Future<int> getReciterStorageBytes(String reciterKey) async {
    final surahs = _store[reciterKey] ?? {};
    return surahs.values.fold<int>(0, (sum, info) => sum + info.totalBytes);
  }

  @override
  Future<int> getTotalStorageBytes() async {
    int total = 0;
    for (final r in _store.values) {
      for (final s in r.values) {
        total += s.totalBytes;
      }
    }
    return total;
  }

  @override
  Future<void> deleteSurahAudio(String reciterId, int surahNumber) async {
    _store[reciterId]?.remove(surahNumber);
  }

  @override
  Future<void> deleteReciterAudio(String reciterKey) async {
    _store[reciterKey]?.clear();
  }

  @override
  Future<void> clearAllAudio() async {
    _store.clear();
  }
}

void main() {
  testWidgets('DownloadManagerScreen renders and interacts correctly', (tester) async {
    final mockOffline = MockOfflineAudioService();
    final fakeStorage = FakeLocalStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(fakeStorage),
          offlineAudioServiceProvider.overrideWithValue(mockOffline),
        ],
        child: const MaterialApp(
          home: DownloadManagerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Offline Audio Manager'), findsOneWidget);

    // Verify Storage Overview exists
    expect(find.text('TOTAL AUDIO STORAGE'), findsOneWidget);
    expect(find.text('Arabic Recitation'), findsOneWidget);
    expect(find.text('Malayalam Audio'), findsOneWidget);

    // Surah 1 should be complete ('Offline')
    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('Offline'), findsAtLeastNWidgets(1));

    // Surah 2 is partial (100/286 ayahs) -> should show Resume
    expect(find.text('Resume (100/286)'), findsOneWidget);

    // Search functionality test
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'Ya-Sin');
    await tester.pumpAndSettle();

    // Ya-Sin should appear in the search box and the list item
    expect(find.text('Ya-Sin'), findsNWidgets(2));
    // Al-Fatihah should be filtered out
    expect(find.text('Al-Fatihah'), findsNothing);

    // Clear search
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    // Toggle to Malayalam Audio
    await tester.tap(find.text('Malayalam Audio'));
    await tester.pumpAndSettle();

    // In Malayalam, Surah 1 is complete
    expect(find.text('Al-Fatihah'), findsOneWidget);
  });
}
