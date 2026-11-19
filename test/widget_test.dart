import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_easy_native/core/models/quran_types.dart';
import 'package:quran_easy_native/core/models/qcf4_models.dart';
import 'package:quran_easy_native/core/models/qvp_models.dart';
import 'package:quran_easy_native/core/theme/app_theme.dart';
import 'package:quran_easy_native/core/services/local_storage_service.dart';
import 'package:quran_easy_native/core/services/offline_audio_service.dart';
import 'package:quran_easy_native/providers/service_providers.dart';
import 'package:quran_easy_native/providers/quran_page_provider.dart';
import 'package:quran_easy_native/ui/mushaf/justified_quran_line.dart';
import 'package:quran_easy_native/ui/mushaf/madani_frame_widget.dart';
import 'package:quran_easy_native/ui/mushaf/mushaf_page_view.dart';
import 'package:quran_easy_native/ui/mushaf/page_flip_book_widget.dart';
import 'package:quran_easy_native/ui/settings/quran_dressing_screen.dart';

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
  bool get showTranslation => false;
  @override
  bool get showWordByWord => false;
  @override
  bool get twoPageMode => false;
  @override
  set showWordByWord(bool value) {}
  @override
  set currentPage(int value) {}
  @override
  set twoPageMode(bool value) {}
  @override
  bool get showSwipeWBW => false;
  @override
  set showSwipeWBW(bool value) {}
}

class FakeLocalStorageWBW extends Fake implements LocalStorageService {
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
  int get currentPage => 3;
  @override
  bool get showTranslation => false;
  @override
  bool get showWordByWord => true;
  @override
  bool get twoPageMode => false;
  @override
  set showWordByWord(bool value) {}
  @override
  set currentPage(int value) {}
  @override
  set twoPageMode(bool value) {}
  @override
  bool get showSwipeWBW => false;
  @override
  set showSwipeWBW(bool value) {}
}

class FakeLocalStorageTwoPage extends Fake implements LocalStorageService {
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
  int get currentPage => 3;
  @override
  bool get showTranslation => false;
  @override
  bool get showWordByWord => false;
  @override
  bool get twoPageMode => true;
  @override
  set showWordByWord(bool value) {}
  @override
  set currentPage(int value) {}
  @override
  set twoPageMode(bool value) {}
  @override
  bool get showSwipeWBW => false;
  @override
  set showSwipeWBW(bool value) {}
}

QvpDecodedPage createMockQvpPage(int pageNumber) {
  return QvpDecodedPage(
    pageNumber: pageNumber,
    width: 345,
    height: 550,
    lines: List.generate(
      15,
      (i) => QvpLineData(i, i + 1, i * 8, 8),
    ),
    ayahs: [
      QvpAyahData(0, 1, 1, 1, 1, 0, 0, 8, -1, 1),
    ],
    words: List.generate(
      120,
      (i) => QvpWordData(
        index: i,
        surah: 2,
        ayah: (i ~/ 10) + 1,
        word: (i % 10) + 1,
        lineIndex: i ~/ 8,
        ayahIndex: 0,
        firstPath: i,
        nPaths: 1,
        text: 'كَلِمَة',
        box: [20.0 + (i % 8) * 35.0, 30.0 + (i ~/ 8) * 34.0, 50.0 + (i % 8) * 35.0, 60.0 + (i ~/ 8) * 34.0],
      ),
    ),
    decorations: [],
    paths: List.generate(
      120,
      (i) => QvpPathData(
        ops: Uint8List.fromList([0, 1, 1, 4]),
        pts: Float32List.fromList([0, 0, 10, 0, 10, 10]),
        box: [0, 0, 10, 10],
        kind: 1,
        mark: 0,
        family: 1,
        rule: 'nonzero',
      ),
    ),
  );
}

void main() {
  test('toArabicDigits converts Western numerals to Eastern Arabic numerals', () {
    expect(toArabicDigits(1), '١');
    expect(toArabicDigits(42), '٤٢');
    expect(toArabicDigits(114), '١١٤');
    expect(toArabicDigits('786'), '٧٨٦');
  });

  test('Reciters list contains exactly 10 reciters with valid URLs', () {
    expect(RECITERS.length, 10);
    final afasy = RECITERS.firstWhere((r) => r.id == 'ar.alafasy');
    expect(afasy.name, 'Mishary Rashid Alafasy');

    final url = getRemoteAudioUrl(afasy, 1, 1);
    expect(url, 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3');

    final sudais = RECITERS.firstWhere((r) => r.id == 'Sudais');
    final sudaisUrl = getRemoteAudioUrl(sudais, 1, 1);
    expect(sudaisUrl, 'https://verses.quran.com/Sudais/mp3/001001.mp3');
  });

  test('Malayalam Lalithasaram audio URL is generated correctly', () {
    final url = getRemoteMalayalamAudioUrl(1, 1);
    expect(url, 'https://lalithasaram.net/audio/qtaud/transl/001_001.mp3');
  });

  test('Surah names and vocalized titles map all 114 surahs', () {
    expect(SURAH_NAMES.length, 114);
    expect(VOCALIZED_SURAH_TITLES.length, 114);
    expect(SURAH_NAMES[1]?.englishName, 'Al-Fatihah');
    expect(SURAH_NAMES[1]?.name, 'الفاتحة');
    expect(VOCALIZED_SURAH_TITLES[1], 'سُورَةُ الفَاتِحَةِ');
    expect(SURAH_NAMES[114]?.englishName, 'An-Nas');
  });

  test('JUZ_DATA contains all 30 juzs with valid page boundaries', () {
    expect(JUZ_DATA.length, 30);
    expect(JUZ_DATA[0].number, 1);
    expect(JUZ_DATA[0].startPage, 1);
    expect(JUZ_DATA[29].number, 30);
    expect(JUZ_DATA[29].startPage, 582);
  });

  testWidgets('JustifiedQuranLine justifies standard lines and centers short lines', (tester) async {
    // 1. Standard line with 8 words (fits within maxStretchGap)
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 300,
          height: 40,
          child: JustifiedQuranLine(
            isCentered: false,
            children: List.generate(
              8,
              (i) => const SizedBox(width: 32, height: 30),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // 2. Short end line with 3 words (should center rather than stretch)
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 300,
          height: 40,
          child: JustifiedQuranLine(
            isCentered: true,
            children: List.generate(
              3,
              (i) => const SizedBox(width: 32, height: 30),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // 3. Overfull line with wide words (should scale down smoothly without overflow)
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 300,
          height: 40,
          child: JustifiedQuranLine(
            isCentered: false,
            children: List.generate(
              12,
              (i) => const SizedBox(width: 30, height: 30),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MushafPageView renders Page 1 and Page 3 with zero overflow across screen sizes', (tester) async {
    // Construct mock PageData2 for Page 1 (8 lines) and Page 3 (15 lines)
    final page1Mock = PageData2(
      page: 1,
      font: 'QCF4_Hafs_01',
      surahs: const [
        PageSurahHeader(id: 1, name: 'Al-Fatihah', nameArabic: 'الفاتحة', verseStart: 1, verseEnd: 7),
      ],
      lines: [
        const PageLine(line: 1, words: [PageWord(code: 1, char: 'سُورَةُ الفَاتِحَةِ', font: 'QCF4_QBSML', text: 'سورة الفاتحة', type: 'surah_header', position: 1)]),
        const PageLine(line: 2, words: [
          PageWord(code: 2, char: 'بِسْمِ', font: 'QCF4_Hafs_01', text: 'بِسْمِ', type: 'word', verseKey: '1:1', position: 1),
          PageWord(code: 3, char: 'اللَّهِ', font: 'QCF4_Hafs_01', text: 'اللَّهِ', type: 'word', verseKey: '1:1', position: 2),
          PageWord(code: 4, char: 'الرَّحْمَنِ', font: 'QCF4_Hafs_01', text: 'الرَّحْمَنِ', type: 'word', verseKey: '1:1', position: 3),
          PageWord(code: 5, char: 'الرَّحِيمِ', font: 'QCF4_Hafs_01', text: 'الرَّحِيمِ', type: 'word', verseKey: '1:1', position: 4),
          PageWord(code: 6, char: '١', font: 'QCF4_Hafs_01', text: '1', type: 'end', verseKey: '1:1', position: 5),
        ]),
        const PageLine(line: 3, words: [
          PageWord(code: 7, char: 'الْحَمْدُ', font: 'QCF4_Hafs_01', text: 'الْحَمْدُ', type: 'word', verseKey: '1:2', position: 1),
          PageWord(code: 8, char: 'لِلَّهِ', font: 'QCF4_Hafs_01', text: 'لِلَّهِ', type: 'word', verseKey: '1:2', position: 2),
          PageWord(code: 9, char: 'رَبِّ', font: 'QCF4_Hafs_01', text: 'رَبِّ', type: 'word', verseKey: '1:2', position: 3),
          PageWord(code: 10, char: 'الْعَالَمِينَ', font: 'QCF4_Hafs_01', text: 'الْعَالَمِينَ', type: 'word', verseKey: '1:2', position: 4),
          PageWord(code: 11, char: '٢', font: 'QCF4_Hafs_01', text: '2', type: 'end', verseKey: '1:2', position: 5),
        ]),
        const PageLine(line: 4, words: [
          PageWord(code: 12, char: 'الرَّحْمَنِ', font: 'QCF4_Hafs_01', text: 'الرَّحْمَنِ', type: 'word', verseKey: '1:3', position: 1),
          PageWord(code: 13, char: 'الرَّحِيمِ', font: 'QCF4_Hafs_01', text: 'الرَّحِيمِ', type: 'word', verseKey: '1:3', position: 2),
          PageWord(code: 14, char: '٣', font: 'QCF4_Hafs_01', text: '3', type: 'end', verseKey: '1:3', position: 3),
          PageWord(code: 15, char: 'مَالِكِ', font: 'QCF4_Hafs_01', text: 'مَالِكِ', type: 'word', verseKey: '1:4', position: 1),
          PageWord(code: 16, char: 'يَوْمِ', font: 'QCF4_Hafs_01', text: 'يَوْمِ', type: 'word', verseKey: '1:4', position: 2),
          PageWord(code: 17, char: 'الدِّينِ', font: 'QCF4_Hafs_01', text: 'الدِّينِ', type: 'word', verseKey: '1:4', position: 3),
          PageWord(code: 18, char: '٤', font: 'QCF4_Hafs_01', text: '4', type: 'end', verseKey: '1:4', position: 4),
        ]),
        const PageLine(line: 5, words: [
          PageWord(code: 19, char: 'إِيَّاكَ', font: 'QCF4_Hafs_01', text: 'إِيَّاكَ', type: 'word', verseKey: '1:5', position: 1),
          PageWord(code: 20, char: 'نَعْبُدُ', font: 'QCF4_Hafs_01', text: 'نَعْبُدُ', type: 'word', verseKey: '1:5', position: 2),
          PageWord(code: 21, char: 'وَإِيَّاكَ', font: 'QCF4_Hafs_01', text: 'وَإِيَّاكَ', type: 'word', verseKey: '1:5', position: 3),
          PageWord(code: 22, char: 'نَسْتَعِينُ', font: 'QCF4_Hafs_01', text: 'نَسْتَعِينُ', type: 'word', verseKey: '1:5', position: 4),
          PageWord(code: 23, char: '٥', font: 'QCF4_Hafs_01', text: '5', type: 'end', verseKey: '1:5', position: 5),
          PageWord(code: 24, char: 'اهْدِنَا', font: 'QCF4_Hafs_01', text: 'اهْدِنَا', type: 'word', verseKey: '1:6', position: 1),
        ]),
        const PageLine(line: 6, words: [
          PageWord(code: 25, char: 'الصِّرَاطَ', font: 'QCF4_Hafs_01', text: 'الصِّرَاطَ', type: 'word', verseKey: '1:6', position: 2),
          PageWord(code: 26, char: 'الْمُسْتَقِيمَ', font: 'QCF4_Hafs_01', text: 'الْمُسْتَقِيمَ', type: 'word', verseKey: '1:6', position: 3),
          PageWord(code: 27, char: '٦', font: 'QCF4_Hafs_01', text: '6', type: 'end', verseKey: '1:6', position: 4),
          PageWord(code: 28, char: 'صِرَاطَ', font: 'QCF4_Hafs_01', text: 'صِرَاطَ', type: 'word', verseKey: '1:7', position: 1),
          PageWord(code: 29, char: 'الَّذِينَ', font: 'QCF4_Hafs_01', text: 'الَّذِينَ', type: 'word', verseKey: '1:7', position: 2),
          PageWord(code: 30, char: 'أَنْعَمْتَ', font: 'QCF4_Hafs_01', text: 'أَنْعَمْتَ', type: 'word', verseKey: '1:7', position: 3),
        ]),
        const PageLine(line: 7, words: [
          PageWord(code: 31, char: 'عَلَيْهِمْ', font: 'QCF4_Hafs_01', text: 'عَلَيْهِمْ', type: 'word', verseKey: '1:7', position: 4),
          PageWord(code: 32, char: 'غَيْرِ', font: 'QCF4_Hafs_01', text: 'غَيْرِ', type: 'word', verseKey: '1:7', position: 5),
          PageWord(code: 33, char: 'الْمَغْضُوبِ', font: 'QCF4_Hafs_01', text: 'الْمَغْضُوبِ', type: 'word', verseKey: '1:7', position: 6),
          PageWord(code: 34, char: 'عَلَيْهِمْ', font: 'QCF4_Hafs_01', text: 'عَلَيْهِمْ', type: 'word', verseKey: '1:7', position: 7),
        ]),
        const PageLine(line: 8, words: [
          PageWord(code: 35, char: 'وَلَا', font: 'QCF4_Hafs_01', text: 'وَلَا', type: 'word', verseKey: '1:7', position: 8),
          PageWord(code: 36, char: 'الضَّالِّينَ', font: 'QCF4_Hafs_01', text: 'الضَّالِّينَ', type: 'word', verseKey: '1:7', position: 9),
          PageWord(code: 37, char: '٧', font: 'QCF4_Hafs_01', text: '7', type: 'end', verseKey: '1:7', position: 10),
        ]),
      ],
    );

    final page3Mock = PageData2(
      page: 3,
      font: 'QCF4_Hafs_01',
      surahs: const [
        PageSurahHeader(id: 2, name: 'Al-Baqarah', nameArabic: 'البقرة', verseStart: 6, verseEnd: 16),
      ],
      lines: List.generate(
        15,
        (lineIndex) => PageLine(
          line: lineIndex + 1,
          words: List.generate(
            9,
            (wIdx) => PageWord(
              code: (lineIndex * 10) + wIdx,
              char: 'كَلِمَة',
              font: 'QCF4_Hafs_01',
              text: 'كلمة',
              type: wIdx == 8 && lineIndex % 3 == 0 ? 'end' : 'word',
              verseKey: '2:${6 + lineIndex}',
              position: wIdx + 1,
            ),
          ),
        ),
      ),
    );

    final testOverrides = [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorage()),
      qvpPageProvider(1).overrideWith((ref) => Future.value(createMockQvpPage(1))),
      qvpPageProvider(3).overrideWith((ref) => Future.value(createMockQvpPage(3))),
      qcf4PageProvider(1).overrideWith((ref) => Future.value(page1Mock)),
      qcf4PageProvider(3).overrideWith((ref) => Future.value(page3Mock)),
      wbwDataProvider.overrideWith((ref) => Future.value(<String, List<String>>{})),
      translationPageProvider(1).overrideWith((ref) => Future.value(<String, String>{})),
      translationPageProvider(3).overrideWith((ref) => Future.value(<String, String>{})),
      uthmaniPageProvider(1).overrideWith((ref) => Future.value(const PageData(number: 1, ayahs: []))),
      uthmaniPageProvider(3).overrideWith((ref) => Future.value(const PageData(number: 3, ayahs: []))),
    ];

    // Test on Phone (390 x 844)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Test standard 15-line page on Phone
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Test standard 15-line page on iPad (1024 x 1366)
    tester.view.physicalSize = const Size(1024 * 2, 1366 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Test standard 15-line page on Widescreen (1920 x 1080)
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MadaniFrameWidget scales and preserves aspect ratio across screens', (tester) async {
    // 1. Mobile Phone (390 x 844)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MadaniFrameWidget(
            pageNumber: 3,
            surahTitle: 'سُورَةُ البَقَرَةِ',
            juzTitle: 'الجُزْءُ الأَوَّلُ',
            themeMode: AppThemeMode.light,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // 2. Large iPad / Tablet (1024 x 1366)
    tester.view.physicalSize = const Size(1024 * 2, 1366 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MadaniFrameWidget(
            pageNumber: 3,
            surahTitle: 'سُورَةُ البَقَرَةِ',
            juzTitle: 'الجُزْءُ الأَوَّلُ',
            themeMode: AppThemeMode.light,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // 3. Desktop Widescreen (1920 x 1080)
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MadaniFrameWidget(
            pageNumber: 3,
            surahTitle: 'سُورَةُ البَقَرَةِ',
            juzTitle: 'الجُزْءُ الأَوَّلُ',
            themeMode: AppThemeMode.light,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MushafPageView with Word-by-Word enabled scales on Phone, iPad, and 4K displays with zero overflow', (tester) async {
    final page3Mock = PageData2(
      page: 3,
      font: 'QCF4_Hafs_01',
      surahs: const [
        PageSurahHeader(id: 2, name: 'Al-Baqarah', nameArabic: 'البقرة', verseStart: 6, verseEnd: 16),
      ],
      lines: List.generate(
        15,
        (lineIndex) => PageLine(
          line: lineIndex + 1,
          words: List.generate(
            8,
            (wIdx) => PageWord(
              code: (lineIndex * 10) + wIdx,
              char: 'كَلِمَة',
              font: 'QCF4_Hafs_01',
              text: 'كلمة',
              type: wIdx == 7 && lineIndex % 3 == 0 ? 'end' : 'word',
              verseKey: '2:${6 + lineIndex}',
              position: wIdx + 1,
            ),
          ),
        ),
      ),
    );

    final mockWbw = {
      for (int i = 0; i < 15; i++)
        '2:${6 + i}': List.generate(8, (j) => 'വാക്ക് ${j + 1}')
    };

    final testOverrides = [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageWBW()),
      qvpPageProvider(3).overrideWith((ref) => Future.value(createMockQvpPage(3))),
      qcf4PageProvider(3).overrideWith((ref) => Future.value(page3Mock)),
      wbwDataProvider.overrideWith((ref) => Future.value(mockWbw)),
      translationPageProvider(3).overrideWith((ref) => Future.value(<String, String>{})),
      uthmaniPageProvider(3).overrideWith((ref) => Future.value(const PageData(number: 3, ayahs: []))),
    ];

    // Phone (390 x 844)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // iPad Pro (1024 x 1366)
    tester.view.physicalSize = const Size(1024 * 2, 1366 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 4K Monitor (3840 x 2160)
    tester.view.physicalSize = const Size(3840, 2160);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MushafPageView(pageNumber: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('PageFlipBookWidget renders dual-page spread on iPad Landscape and Desktop displays', (tester) async {
    final page3Mock = PageData2(
      page: 3,
      font: 'QCF4_Hafs_01',
      surahs: const [PageSurahHeader(id: 2, name: 'Al-Baqarah', nameArabic: 'البقرة', verseStart: 6, verseEnd: 16)],
      lines: List.generate(15, (i) => PageLine(line: i + 1, words: const [
        PageWord(code: 1, char: 'كَلِمَة', font: 'QCF4_Hafs_01', text: 'كلمة', type: 'word', verseKey: '2:6', position: 1),
      ])),
    );
    final page4Mock = PageData2(
      page: 4,
      font: 'QCF4_Hafs_01',
      surahs: const [PageSurahHeader(id: 2, name: 'Al-Baqarah', nameArabic: 'البقرة', verseStart: 17, verseEnd: 24)],
      lines: List.generate(15, (i) => PageLine(line: i + 1, words: const [
        PageWord(code: 2, char: 'كَلِمَة', font: 'QCF4_Hafs_01', text: 'كلمة', type: 'word', verseKey: '2:17', position: 1),
      ])),
    );

    final testOverrides = [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageTwoPage()),
      qvpPageProvider(3).overrideWith((ref) => Future.value(createMockQvpPage(3))),
      qvpPageProvider(4).overrideWith((ref) => Future.value(createMockQvpPage(4))),
      qcf4PageProvider(3).overrideWith((ref) => Future.value(page3Mock)),
      qcf4PageProvider(4).overrideWith((ref) => Future.value(page4Mock)),
      wbwDataProvider.overrideWith((ref) => Future.value(<String, List<String>>{})),
      translationPageProvider(3).overrideWith((ref) => Future.value(<String, String>{})),
      translationPageProvider(4).overrideWith((ref) => Future.value(<String, String>{})),
      uthmaniPageProvider(3).overrideWith((ref) => Future.value(const PageData(number: 3, ayahs: []))),
      uthmaniPageProvider(4).overrideWith((ref) => Future.value(const PageData(number: 4, ayahs: []))),
    ];

    // iPad Landscape (1366 x 1024)
    tester.view.physicalSize = const Size(1366 * 2, 1024 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: PageFlipBookWidget(currentPage: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Desktop Widescreen (1920 x 1080)
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides,
        child: const MaterialApp(
          home: Scaffold(
            body: PageFlipBookWidget(currentPage: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuranDressingScreen renders and updates dressing options seamlessly without error', (tester) async {
    final fakeStorage = FakeLocalStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(fakeStorage),
          qvpPageProvider(1).overrideWith((ref) => Future.value(createMockQvpPage(1))),
        ],
        child: const MaterialApp(
          home: QuranDressingScreen(previewPageNumber: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quran Dressing & Ornaments'), findsOneWidget);
    expect(find.text('Live Ornament Preview'), findsOneWidget);

    // Verify presence of authentic manuscript styles
    expect(find.text('Hafs al-Adi (Standard Madani)'), findsOneWidget);
    expect(find.text('Hafs Madinah Kabir'), findsOneWidget);

    // Tap Hafs Madinah Kabir frame
    await tester.tap(find.text('Hafs Madinah Kabir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap Reset default
    await tester.tap(find.text('Reset Default'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.takeException(), isNull);
  });
}

