import 'package:flutter/foundation.dart';

@immutable
class MushtabihatPair {
  final String ayah1;
  final String ayah2;
  final String category;
  final String note;
  final String source;
  final String origin;
  final int surah1;
  final int surah2;
  final int juz1;
  final int juz2;
  final String? text1;
  final String? text2;
  final double? similarity;

  const MushtabihatPair({
    required this.ayah1,
    required this.ayah2,
    required this.category,
    required this.note,
    required this.source,
    required this.origin,
    required this.surah1,
    required this.surah2,
    required this.juz1,
    required this.juz2,
    this.text1,
    this.text2,
    this.similarity,
  });

  String get pairKey => '$ayah1|$ayah2';

  factory MushtabihatPair.fromJson(Map<String, dynamic> json) {
    return MushtabihatPair(
      ayah1: json['ayah1'] as String? ?? '',
      ayah2: json['ayah2'] as String? ?? '',
      category: json['category'] as String? ?? '',
      note: json['note'] as String? ?? '',
      source: json['source'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      surah1: json['surah1'] as int? ?? 1,
      surah2: json['surah2'] as int? ?? 1,
      juz1: json['juz1'] as int? ?? 1,
      juz2: json['juz2'] as int? ?? 1,
      text1: json['text1'] as String?,
      text2: json['text2'] as String?,
      similarity: (json['similarity'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ayah1': ayah1,
    'ayah2': ayah2,
    'category': category,
    'note': note,
    'source': source,
    'origin': origin,
    'surah1': surah1,
    'surah2': surah2,
    'juz1': juz1,
    'juz2': juz2,
    if (text1 != null) 'text1': text1,
    if (text2 != null) 'text2': text2,
    if (similarity != null) 'similarity': similarity,
  };

  MushtabihatPair copyWith({String? text1, String? text2}) {
    return MushtabihatPair(
      ayah1: ayah1,
      ayah2: ayah2,
      category: category,
      note: note,
      source: source,
      origin: origin,
      surah1: surah1,
      surah2: surah2,
      juz1: juz1,
      juz2: juz2,
      text1: text1 ?? this.text1,
      text2: text2 ?? this.text2,
      similarity: similarity,
    );
  }
}
