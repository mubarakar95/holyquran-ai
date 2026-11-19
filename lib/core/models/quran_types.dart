import 'package:flutter/foundation.dart';

@immutable
class SurahInfo {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  const SurahInfo({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory SurahInfo.fromJson(Map<String, dynamic> json) {
    return SurahInfo(
      number: json['number'] as int,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: json['numberOfAyahs'] as int? ?? 0,
      revelationType: json['revelationType'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'englishName': englishName,
    'englishNameTranslation': englishNameTranslation,
    'numberOfAyahs': numberOfAyahs,
    'revelationType': revelationType,
  };
}

@immutable
class AyahInfo {
  final int number;
  final String text;
  final int numberInSurah;
  final int juz;
  final int manzil;
  final int ruku;
  final int hizbQuarter;
  final dynamic sajda;
  final SurahInfo surah;

  const AyahInfo({
    required this.number,
    required this.text,
    required this.numberInSurah,
    required this.juz,
    required this.manzil,
    required this.ruku,
    required this.hizbQuarter,
    required this.sajda,
    required this.surah,
  });

  String get verseKey => '${surah.number}:$numberInSurah';

  factory AyahInfo.fromJson(Map<String, dynamic> json) {
    return AyahInfo(
      number: json['number'] as int,
      text: json['text'] as String? ?? '',
      numberInSurah: json['numberInSurah'] as int,
      juz: json['juz'] as int? ?? 1,
      manzil: json['manzil'] as int? ?? 1,
      ruku: json['ruku'] as int? ?? 1,
      hizbQuarter: json['hizbQuarter'] as int? ?? 1,
      sajda: json['sajda'],
      surah: SurahInfo.fromJson(json['surah'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'text': text,
    'numberInSurah': numberInSurah,
    'juz': juz,
    'manzil': manzil,
    'ruku': ruku,
    'hizbQuarter': hizbQuarter,
    'sajda': sajda,
    'surah': surah.toJson(),
  };
}

@immutable
class PageData {
  final int number;
  final List<AyahInfo> ayahs;

  const PageData({required this.number, required this.ayahs});

  factory PageData.fromJson(Map<String, dynamic> json) {
    final list = json['ayahs'] as List<dynamic>? ?? [];
    return PageData(
      number: json['number'] as int,
      ayahs: list.map((e) => AyahInfo.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'ayahs': ayahs.map((e) => e.toJson()).toList(),
  };
}

enum AudioFormat { global, surah }
enum AudioMode { arabic, malayalam, both }
enum QuranRepeatMode { none, ayah, page }
enum ClausePhase { ml, ar }

@immutable
class Reciter {
  final String id;
  final String name;
  final String arabicName;
  final String audioBase;
  final AudioFormat audioFormat;
  final int? quranComId;

  const Reciter({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.audioBase,
    required this.audioFormat,
    this.quranComId,
  });
}

const List<Reciter> RECITERS = [
  Reciter(
    id: "ar.alafasy",
    name: "Mishary Rashid Alafasy",
    arabicName: "مشاري راشد العفاسي",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.alafasy",
    audioFormat: AudioFormat.global,
    quranComId: 7,
  ),
  Reciter(
    id: "Sudais",
    name: "Abdurrahman As-Sudais",
    arabicName: "عبد الرحمن السديس",
    audioBase: "https://verses.quran.com/Sudais/mp3",
    audioFormat: AudioFormat.surah,
    quranComId: 3,
  ),
  Reciter(
    id: "ar.hudhaify",
    name: "Ali Al-Hudaify",
    arabicName: "علي الحذيفي",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.hudhaify",
    audioFormat: AudioFormat.global,
    quranComId: null,
  ),
  Reciter(
    id: "ar.husary",
    name: "Mahmoud Khalil Al-Husary",
    arabicName: "محمود خليل الحصري",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.husary",
    audioFormat: AudioFormat.global,
    quranComId: 6,
  ),
  Reciter(
    id: "ar.shaatree",
    name: "Abdullah Awad Al-Juhani",
    arabicName: "عبد الله عواد الجهني",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.shaatree",
    audioFormat: AudioFormat.global,
    quranComId: null,
  ),
  Reciter(
    id: "ar.husarymujawwad",
    name: "Husary (Mujawwad)",
    arabicName: "الحصري مجود",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.husarymujawwad",
    audioFormat: AudioFormat.global,
    quranComId: null,
  ),
  Reciter(
    id: "ar.minshawi",
    name: "Mohamed Siddiq El-Minshawi",
    arabicName: "محمد صديق المنشاوي",
    audioBase: "https://verses.quran.com/Minshawi/Murattal/mp3",
    audioFormat: AudioFormat.surah,
    quranComId: 9,
  ),
  Reciter(
    id: "ar.ahmedajamy",
    name: "Ahmed ibn Ali al-Ajamy",
    arabicName: "أحمد بن علي العجمي",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.ahmedajamy",
    audioFormat: AudioFormat.global,
    quranComId: null,
  ),
  Reciter(
    id: "ar.saoodshuraym",
    name: "Saud Ash-Shuraim",
    arabicName: "سعود الشريم",
    audioBase: "https://verses.quran.com/Shuraym/mp3",
    audioFormat: AudioFormat.surah,
    quranComId: 10,
  ),
  Reciter(
    id: "ar.abdullahalmatrood",
    name: "Abdullah Al-Matrood",
    arabicName: "عبد الله المطرود",
    audioBase: "https://cdn.islamic.network/quran/audio/128/ar.abdullahalmatrood",
    audioFormat: AudioFormat.surah,
    quranComId: null,
  ),
];

@immutable
class WordSegment {
  final int wordIndex;
  final int startMs;
  final int endMs;

  const WordSegment({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });

  factory WordSegment.fromJson(Map<String, dynamic> json) {
    return WordSegment(
      wordIndex: (json['wordIndex'] as num?)?.toInt() ?? 0,
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'wordIndex': wordIndex,
    'startMs': startMs,
    'endMs': endMs,
  };
}

@immutable
class AyahClause {
  final int startMs;
  final int endMs;
  final List<int> wordIndices;
  final String? phrase;

  const AyahClause({
    required this.startMs,
    required this.endMs,
    required this.wordIndices,
    this.phrase,
  });

  factory AyahClause.fromJson(Map<String, dynamic> json) {
    return AyahClause(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      wordIndices: (json['wordIndices'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      phrase: json['phrase'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'wordIndices': wordIndices,
    if (phrase != null) 'phrase': phrase,
  };
}

@immutable
class AyahSegments {
  final String verseKey;
  final List<WordSegment> segments;
  final List<AyahClause>? clauses;

  const AyahSegments({
    required this.verseKey,
    required this.segments,
    this.clauses,
  });

  factory AyahSegments.fromJson(Map<String, dynamic> json) {
    final segs = (json['segments'] as List<dynamic>? ?? [])
        .map((e) => WordSegment.fromJson(e as Map<String, dynamic>))
        .toList();
    final cls = json['clauses'] != null
        ? (json['clauses'] as List<dynamic>)
            .map((e) => AyahClause.fromJson(e as Map<String, dynamic>))
            .toList()
        : null;
    return AyahSegments(verseKey: json['verseKey'] as String, segments: segs, clauses: cls);
  }

  Map<String, dynamic> toJson() => {
    'verseKey': verseKey,
    'segments': segments.map((e) => e.toJson()).toList(),
    if (clauses != null) 'clauses': clauses!.map((e) => e.toJson()).toList(),
  };
}

@immutable
class HighlightWord {
  final String verseKey;
  final int wordIndex;
  final List<int>? wordIndices;
  final bool bundle;

  const HighlightWord({
    required this.verseKey,
    required this.wordIndex,
    this.wordIndices,
    this.bundle = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightWord &&
          runtimeType == other.runtimeType &&
          verseKey == other.verseKey &&
          wordIndex == other.wordIndex &&
          bundle == other.bundle &&
          listEquals(wordIndices, other.wordIndices);

  @override
  int get hashCode => Object.hash(verseKey, wordIndex, bundle, Object.hashAll(wordIndices ?? []));
}

const String MALAYALAM_EDITION = "ml.karakunnu";
const int TOTAL_PAGES = 604;

class JuzInfo {
  final int number;
  final String name;
  final String nameEn;
  final int startPage;

  const JuzInfo({
    required this.number,
    required this.name,
    required this.nameEn,
    required this.startPage,
  });
}

const List<JuzInfo> JUZ_DATA = [
  JuzInfo(number: 1, name: "الجُزْءُ الأَوَّلُ", nameEn: "Juz 1", startPage: 1),
  JuzInfo(number: 2, name: "الجُزْءُ الثَّانِي", nameEn: "Juz 2", startPage: 22),
  JuzInfo(number: 3, name: "الجُزْءُ الثَّالِثُ", nameEn: "Juz 3", startPage: 42),
  JuzInfo(number: 4, name: "الجُزْءُ الرَّابِعُ", nameEn: "Juz 4", startPage: 62),
  JuzInfo(number: 5, name: "الجُزْءُ الخَامِسُ", nameEn: "Juz 5", startPage: 82),
  JuzInfo(number: 6, name: "الجُزْءُ السَّادِسُ", nameEn: "Juz 6", startPage: 102),
  JuzInfo(number: 7, name: "الجُزْءُ السَّابِعُ", nameEn: "Juz 7", startPage: 122),
  JuzInfo(number: 8, name: "الجُزْءُ الثَّامِنُ", nameEn: "Juz 8", startPage: 142),
  JuzInfo(number: 9, name: "الجُزْءُ التَّاسِعُ", nameEn: "Juz 9", startPage: 162),
  JuzInfo(number: 10, name: "الجُزْءُ العَاشِرُ", nameEn: "Juz 10", startPage: 182),
  JuzInfo(number: 11, name: "الجُزْءُ الحَادِي عَشَرَ", nameEn: "Juz 11", startPage: 202),
  JuzInfo(number: 12, name: "الجُزْءُ الثَّانِي عَشَرَ", nameEn: "Juz 12", startPage: 222),
  JuzInfo(number: 13, name: "الجُزْءُ الثَّالِثَ عَشَرَ", nameEn: "Juz 13", startPage: 242),
  JuzInfo(number: 14, name: "الجُزْءُ الرَّابِعَ عَشَرَ", nameEn: "Juz 14", startPage: 262),
  JuzInfo(number: 15, name: "الجُزْءُ الخَامِسَ عَشَرَ", nameEn: "Juz 15", startPage: 282),
  JuzInfo(number: 16, name: "الجُزْءُ السَّادِسَ عَشَرَ", nameEn: "Juz 16", startPage: 302),
  JuzInfo(number: 17, name: "الجُزْءُ السَّابِعَ عَشَرَ", nameEn: "Juz 17", startPage: 322),
  JuzInfo(number: 18, name: "الجُزْءُ الثَّامِنَ عَشَرَ", nameEn: "Juz 18", startPage: 342),
  JuzInfo(number: 19, name: "الجُزْءُ التَّاسِعَ عَشَرَ", nameEn: "Juz 19", startPage: 362),
  JuzInfo(number: 20, name: "الجُزْءُ العِشْرُونَ", nameEn: "Juz 20", startPage: 382),
  JuzInfo(number: 21, name: "الجُزْءُ الحَادِي وَالعِشْرُونَ", nameEn: "Juz 21", startPage: 402),
  JuzInfo(number: 22, name: "الجُزْءُ الثَّانِي وَالعِشْرُونَ", nameEn: "Juz 22", startPage: 422),
  JuzInfo(number: 23, name: "الجُزْءُ الثَّالِثُ وَالعِشْرُونَ", nameEn: "Juz 23", startPage: 442),
  JuzInfo(number: 24, name: "الجُزْءُ الرَّابِعُ وَالعِشْرُونَ", nameEn: "Juz 24", startPage: 462),
  JuzInfo(number: 25, name: "الجُزْءُ الخَامِسُ وَالعِشْرُونَ", nameEn: "Juz 25", startPage: 482),
  JuzInfo(number: 26, name: "الجُزْءُ السَّادِسُ وَالعِشْرُونَ", nameEn: "Juz 26", startPage: 502),
  JuzInfo(number: 27, name: "الجُزْءُ السَّابِعُ وَالعِشْرُونَ", nameEn: "Juz 27", startPage: 522),
  JuzInfo(number: 28, name: "الجُزْءُ الثَّامِنُ وَالعِشْرُونَ", nameEn: "Juz 28", startPage: 542),
  JuzInfo(number: 29, name: "الجُزْءُ التَّاسِعَ وَالعِشْرُونَ", nameEn: "Juz 29", startPage: 562),
  JuzInfo(number: 30, name: "الجُزْءُ الثَّلَاثُونَ", nameEn: "Juz 30", startPage: 582),
];

String toArabicDigits(dynamic num) {
  const arabicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
  return num.toString().replaceAllMapped(RegExp(r'\d'), (match) {
    final digit = int.parse(match.group(0)!);
    return arabicDigits[digit];
  });
}
