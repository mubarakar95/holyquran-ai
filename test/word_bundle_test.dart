import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_easy_native/core/models/quran_types.dart';
import 'package:quran_easy_native/core/utils/wbw_bundle_helper.dart';
import 'package:quran_easy_native/core/services/local_storage_service.dart';
import 'package:quran_easy_native/providers/service_providers.dart';
import 'package:quran_easy_native/providers/quran_page_provider.dart';
import 'package:quran_easy_native/ui/mushaf/mushaf_page_side_icon.dart';

class _FakeLocalStorage extends Fake implements LocalStorageService {
  @override
  int get currentPage => 1;
  @override
  set currentPage(int val) {}
  @override
  bool get showWordByWord => false;
  @override
  set showWordByWord(bool val) {}
  @override
  bool get showTranslation => false;
  @override
  set showTranslation(bool val) {}
  @override
  bool get twoPageMode => false;
  @override
  set twoPageMode(bool val) {}
  @override
  bool get showSwipeWBW => false;
  @override
  set showSwipeWBW(bool val) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WbwBundleHelper', () {
    // Exact data from assets/data/malayalam-wbw.json for Ayah 2:62 (start of Page 10)
    final ayah2_62Meanings = [
      "നിശ്ചയം സത്യവിശ്വാസം സ്വീകരിച്ചവര്‍", // 0
      "",                                     // 1
      "",                                     // 2
      "യഹൂദരും",                              // 3
      "",                                     // 4
      "ക്രൈസ്തവരും",                           // 5
      "സാബികളും",                             // 6
      "ആര്‍",                                  // 7
      "വിശ്വസിച്ചു",                           // 8
      "അല്ലാഹുവില്‍",                          // 9
      "അന്ത്യദിനത്തിലും",                      // 10
      "",                                     // 11
      "പ്രവര്‍ത്തിക്കുകയും ചെയ്തു",              // 12
      "സല്‍കര്‍മം",                            // 13
    ];

    test('resolves 3-word bundle from head index (word 0)', () {
      final bundle = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 0);
      expect(bundle.headIndex, 0);
      expect(bundle.wordIndices, [0, 1, 2]);
      expect(bundle.meaning, "നിശ്ചയം സത്യവിശ്വാസം സ്വീകരിച്ചവര്‍");
      expect(bundle.isBundle, isTrue);
    });

    test('resolves 3-word bundle from middle index (word 1)', () {
      final bundle = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 1);
      expect(bundle.headIndex, 0);
      expect(bundle.wordIndices, [0, 1, 2]);
      expect(bundle.meaning, "നിശ്ചയം സത്യവിശ്വാസം സ്വീകരിച്ചവര്‍");
      expect(bundle.isBundle, isTrue);
    });

    test('resolves 3-word bundle from tail index (word 2)', () {
      final bundle = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 2);
      expect(bundle.headIndex, 0);
      expect(bundle.wordIndices, [0, 1, 2]);
      expect(bundle.meaning, "നിശ്ചയം സത്യവിശ്വാസം സ്വീകരിച്ചവര്‍");
      expect(bundle.isBundle, isTrue);
    });

    test('resolves 2-word bundle (words 3 and 4)', () {
      final bundleFromHead = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 3);
      expect(bundleFromHead.headIndex, 3);
      expect(bundleFromHead.wordIndices, [3, 4]);
      expect(bundleFromHead.meaning, "യഹൂദരും");
      expect(bundleFromHead.isBundle, isTrue);

      final bundleFromTail = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 4);
      expect(bundleFromTail.headIndex, 3);
      expect(bundleFromTail.wordIndices, [3, 4]);
      expect(bundleFromTail.meaning, "യഹൂദരും");
      expect(bundleFromTail.isBundle, isTrue);
    });

    test('resolves standalone word (word 5)', () {
      final bundle = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 5);
      expect(bundle.headIndex, 5);
      expect(bundle.wordIndices, [5]);
      expect(bundle.meaning, "ക്രൈസ്തവരും");
      expect(bundle.isBundle, isFalse);
    });

    test('gracefully handles boundary conditions', () {
      // Empty list
      final emptyResult = WbwBundleHelper.resolveBundle([], 0);
      expect(emptyResult.headIndex, 0);
      expect(emptyResult.wordIndices, [0]);
      expect(emptyResult.meaning, '');
      expect(emptyResult.isBundle, isFalse);

      // Out of bounds
      final oobResult = WbwBundleHelper.resolveBundle(ayah2_62Meanings, 99);
      expect(oobResult.headIndex, 99);
      expect(oobResult.wordIndices, [99]);
      expect(oobResult.meaning, '');

      // Null list
      final nullResult = WbwBundleHelper.resolveBundle(null, 2);
      expect(nullResult.headIndex, 2);
      expect(nullResult.wordIndices, [2]);
      expect(nullResult.meaning, '');
    });
  });

  group('QuranPageNotifier with Word Bundles', () {
    test('updates selectedWord with bundle and handles instant switching', () {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial state
      expect(container.read(quranPageProvider).selectedWord, isNull);

      // 2. Select first bundle [0, 1, 2]
      const bundle1 = HighlightWord(
        verseKey: '2:62',
        wordIndex: 0,
        wordIndices: [0, 1, 2],
        bundle: true,
      );
      container.read(quranPageProvider.notifier).setSelectedWord(bundle1);

      final selected1 = container.read(quranPageProvider).selectedWord;
      expect(selected1, isNotNull);
      expect(selected1!.verseKey, '2:62');
      expect(selected1.wordIndex, 0);
      expect(selected1.wordIndices, [0, 1, 2]);
      expect(selected1.bundle, isTrue);

      // 3. Instant switch to second bundle [3, 4]
      const bundle2 = HighlightWord(
        verseKey: '2:62',
        wordIndex: 3,
        wordIndices: [3, 4],
        bundle: true,
      );
      container.read(quranPageProvider.notifier).setSelectedWord(bundle2);

      final selected2 = container.read(quranPageProvider).selectedWord;
      expect(selected2, isNotNull);
      expect(selected2!.verseKey, '2:62');
      expect(selected2.wordIndex, 3);
      expect(selected2.wordIndices, [3, 4]);

      // 4. Clear selection
      container.read(quranPageProvider.notifier).setSelectedWord(null);
      expect(container.read(quranPageProvider).selectedWord, isNull);
    });
  });

  group('MushafPageSideIcon', () {
    testWidgets('accurately represents Right page for odd numbers in real Mushaf', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MushafPageSideIcon(pageNumber: 1), // Al-Fatiha
          ),
        ),
      );

      final iconFinder = find.byType(MushafPageSideIcon);
      expect(iconFinder, findsOneWidget);

      final iconWidget = tester.widget<MushafPageSideIcon>(iconFinder);
      expect(iconWidget.isOddPage, isTrue); // Right page
    });

    testWidgets('accurately represents Left page for even numbers in real Mushaf', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MushafPageSideIcon(pageNumber: 10), // Even page
          ),
        ),
      );

      final iconFinder = find.byType(MushafPageSideIcon);
      expect(iconFinder, findsOneWidget);

      final iconWidget = tester.widget<MushafPageSideIcon>(iconFinder);
      expect(iconWidget.isOddPage, isFalse); // Left page
    });
  });
}
