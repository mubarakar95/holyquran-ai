import 'package:flutter/foundation.dart';

@immutable
class WbwBundle {
  final int headIndex;
  final List<int> wordIndices;
  final String meaning;
  final bool isBundle;

  const WbwBundle({
    required this.headIndex,
    required this.wordIndices,
    required this.meaning,
    this.isBundle = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WbwBundle &&
          runtimeType == other.runtimeType &&
          headIndex == other.headIndex &&
          meaning == other.meaning &&
          isBundle == other.isBundle &&
          listEquals(wordIndices, other.wordIndices);

  @override
  int get hashCode => Object.hash(headIndex, meaning, isBundle, Object.hashAll(wordIndices));
}

class WbwBundleHelper {
  /// Resolves the multi-word bundle for a given word index within an ayah.
  ///
  /// In the Word-by-Word translation dataset, adjacent words that share a single
  /// Malayalam meaning have the full meaning assigned to the first word (head),
  /// and subsequent continuation words in the bundle have empty string meanings ("").
  ///
  /// Given any word index in the bundle (head, middle, or tail), this function:
  /// 1. Scans backward to locate the head index with non-empty meaning.
  /// 2. Scans forward from the head through all consecutive empty-string siblings.
  /// 3. Returns a [WbwBundle] containing the head index, all contiguous word indices,
  ///    and the shared meaning.
  static WbwBundle resolveBundle(List<String>? meanings, int tappedWordIndex) {
    if (meanings == null || meanings.isEmpty || tappedWordIndex < 0 || tappedWordIndex >= meanings.length) {
      return WbwBundle(
        headIndex: tappedWordIndex,
        wordIndices: [tappedWordIndex],
        meaning: '',
        isBundle: false,
      );
    }

    // 1. Locate head index (scan backward if tapped word has an empty meaning)
    int head = tappedWordIndex;
    if (meanings[head].trim().isEmpty) {
      while (head > 0 && meanings[head].trim().isEmpty) {
        head--;
      }
    }

    final String sharedMeaning = meanings[head].trim();

    // 2. Locate the end of the bundle (scan forward through consecutive empty strings)
    int end = head;
    while (end + 1 < meanings.length && meanings[end + 1].trim().isEmpty) {
      end++;
    }

    final wordIndices = <int>[];
    for (int i = head; i <= end; i++) {
      wordIndices.add(i);
    }

    return WbwBundle(
      headIndex: head,
      wordIndices: wordIndices,
      meaning: sharedMeaning,
      isBundle: wordIndices.length > 1,
    );
  }
}
