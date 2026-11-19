import 'package:flutter/foundation.dart';

enum ScopeType { page, juz, surah, all }

enum WordStatus {
  newWord('new'),
  learning('learning'),
  learned('learned'),
  mastered('mastered');

  final String value;
  const WordStatus(this.value);

  static WordStatus fromString(String str) {
    switch (str.toLowerCase()) {
      case 'learning':
        return WordStatus.learning;
      case 'learned':
        return WordStatus.learned;
      case 'mastered':
        return WordStatus.mastered;
      default:
        return WordStatus.newWord;
    }
  }
}

@immutable
class VocabularyWord {
  final String arabic;
  final String malayalam;
  final int wordCount;
  final int count;
  final List<String> verses;

  const VocabularyWord({
    required this.arabic,
    required this.malayalam,
    required this.wordCount,
    required this.count,
    required this.verses,
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    return VocabularyWord(
      arabic: json['arabic'] as String? ?? '',
      malayalam: json['malayalam'] as String? ?? '',
      wordCount: json['wordCount'] as int? ?? 1,
      count: json['count'] as int? ?? 1,
      verses: (json['verses'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'arabic': arabic,
    'malayalam': malayalam,
    'wordCount': wordCount,
    'count': count,
    'verses': verses,
  };
}

@immutable
class VocabularyData {
  final Map<String, dynamic> meta;
  final List<VocabularyWord> words;

  const VocabularyData({required this.meta, required this.words});

  factory VocabularyData.fromJson(Map<String, dynamic> json) {
    final wordsList = (json['words'] as List<dynamic>? ?? [])
        .map((e) => VocabularyWord.fromJson(e as Map<String, dynamic>))
        .toList();
    return VocabularyData(
      meta: (json['meta'] as Map<String, dynamic>?) ?? {},
      words: wordsList,
    );
  }
}

@immutable
class WordProgress {
  final WordStatus status;
  final int correct;
  final int wrong;
  final int lastReviewed;

  const WordProgress({
    required this.status,
    required this.correct,
    required this.wrong,
    required this.lastReviewed,
  });

  factory WordProgress.initial() => const WordProgress(
    status: WordStatus.newWord,
    correct: 0,
    wrong: 0,
    lastReviewed: 0,
  );

  factory WordProgress.fromJson(Map<String, dynamic> json) {
    return WordProgress(
      status: WordStatus.fromString(json['status'] as String? ?? 'new'),
      correct: json['correct'] as int? ?? 0,
      wrong: json['wrong'] as int? ?? 0,
      lastReviewed: json['lastReviewed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.value,
    'correct': correct,
    'wrong': wrong,
    'lastReviewed': lastReviewed,
  };

  WordProgress copyWith({
    WordStatus? status,
    int? correct,
    int? wrong,
    int? lastReviewed,
  }) {
    return WordProgress(
      status: status ?? this.status,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }
}

@immutable
class SurahMastery {
  final int number;
  final String name;
  final String englishName;
  final int total;
  final int mastered;
  final int learned;
  final int learning;

  const SurahMastery({
    required this.number,
    required this.name,
    required this.englishName,
    required this.total,
    required this.mastered,
    required this.learned,
    required this.learning,
  });

  double get percent => total > 0 ? (mastered / total) : 0.0;
}
