import 'package:flutter/foundation.dart';

@immutable
class PageWord {
  final int code;
  final String char;
  final String font;
  final String text;
  final String type; // 'word', 'end', 'surah_header', 'bismillah'
  final String? verseKey;
  final int? sura;
  final int position;

  const PageWord({
    required this.code,
    required this.char,
    required this.font,
    required this.text,
    required this.type,
    this.verseKey,
    this.sura,
    required this.position,
  });

  factory PageWord.fromJson(Map<String, dynamic> json) {
    return PageWord(
      code: json['code'] as int,
      char: json['char'] as String? ?? '',
      font: json['font'] as String? ?? '',
      text: json['text'] as String? ?? '',
      type: json['type'] as String? ?? 'word',
      verseKey: json['verse_key'] as String?,
      sura: json['sura'] as int?,
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'char': char,
    'font': font,
    'text': text,
    'type': type,
    if (verseKey != null) 'verse_key': verseKey,
    if (sura != null) 'sura': sura,
    'position': position,
  };
}

@immutable
class PageLine {
  final int line;
  final List<PageWord> words;

  const PageLine({required this.line, required this.words});

  factory PageLine.fromJson(Map<String, dynamic> json) {
    final wordsList = (json['words'] as List<dynamic>? ?? [])
        .map((e) => PageWord.fromJson(e as Map<String, dynamic>))
        .toList();
    return PageLine(line: json['line'] as int, words: wordsList);
  }

  Map<String, dynamic> toJson() => {
    'line': line,
    'words': words.map((e) => e.toJson()).toList(),
  };
}

@immutable
class PageSurahHeader {
  final int id;
  final String name;
  final String nameArabic;
  final int verseStart;
  final int verseEnd;

  const PageSurahHeader({
    required this.id,
    required this.name,
    required this.nameArabic,
    required this.verseStart,
    required this.verseEnd,
  });

  factory PageSurahHeader.fromJson(Map<String, dynamic> json) {
    return PageSurahHeader(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameArabic: json['name_arabic'] as String? ?? '',
      verseStart: json['verse_start'] as int? ?? 0,
      verseEnd: json['verse_end'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_arabic': nameArabic,
    'verse_start': verseStart,
    'verse_end': verseEnd,
  };
}

@immutable
class PageData2 {
  final int page;
  final String font;
  final List<PageSurahHeader> surahs;
  final List<PageLine> lines;

  const PageData2({
    required this.page,
    required this.font,
    required this.surahs,
    required this.lines,
  });

  factory PageData2.fromJson(Map<String, dynamic> json) {
    final surahsList = (json['surahs'] as List<dynamic>? ?? [])
        .map((e) => PageSurahHeader.fromJson(e as Map<String, dynamic>))
        .toList();
    final linesList = (json['lines'] as List<dynamic>? ?? [])
        .map((e) => PageLine.fromJson(e as Map<String, dynamic>))
        .toList();
    return PageData2(
      page: json['page'] as int,
      font: json['font'] as String? ?? '',
      surahs: surahsList,
      lines: linesList,
    );
  }

  Map<String, dynamic> toJson() => {
    'page': page,
    'font': font,
    'surahs': surahs.map((e) => e.toJson()).toList(),
    'lines': lines.map((e) => e.toJson()).toList(),
  };
}

class SurahNameEntry {
  final String name;
  final String englishName;

  const SurahNameEntry({required this.name, required this.englishName});
}

const Map<int, SurahNameEntry> SURAH_NAMES = {
  1: SurahNameEntry(name: "الفاتحة", englishName: "Al-Fatihah"),
  2: SurahNameEntry(name: "البقرة", englishName: "Al-Baqarah"),
  3: SurahNameEntry(name: "آل عمران", englishName: "Aal-Imran"),
  4: SurahNameEntry(name: "النساء", englishName: "An-Nisa"),
  5: SurahNameEntry(name: "المائدة", englishName: "Al-Ma'idah"),
  6: SurahNameEntry(name: "الأنعام", englishName: "Al-An'am"),
  7: SurahNameEntry(name: "الأعراف", englishName: "Al-A'raf"),
  8: SurahNameEntry(name: "الأنفال", englishName: "Al-Anfal"),
  9: SurahNameEntry(name: "التوبة", englishName: "At-Tawbah"),
  10: SurahNameEntry(name: "يونس", englishName: "Yunus"),
  11: SurahNameEntry(name: "هود", englishName: "Hud"),
  12: SurahNameEntry(name: "يوسف", englishName: "Yusuf"),
  13: SurahNameEntry(name: "الرعد", englishName: "Ar-Ra'd"),
  14: SurahNameEntry(name: "إبراهيم", englishName: "Ibrahim"),
  15: SurahNameEntry(name: "الحجر", englishName: "Al-Hijr"),
  16: SurahNameEntry(name: "النحل", englishName: "An-Nahl"),
  17: SurahNameEntry(name: "الإسراء", englishName: "Al-Isra"),
  18: SurahNameEntry(name: "الكهف", englishName: "Al-Kahf"),
  19: SurahNameEntry(name: "مريم", englishName: "Maryam"),
  20: SurahNameEntry(name: "طه", englishName: "Taha"),
  21: SurahNameEntry(name: "الأنبياء", englishName: "Al-Anbiya"),
  22: SurahNameEntry(name: "الحج", englishName: "Al-Hajj"),
  23: SurahNameEntry(name: "المؤمنون", englishName: "Al-Mu'minun"),
  24: SurahNameEntry(name: "النور", englishName: "An-Nur"),
  25: SurahNameEntry(name: "الفرقان", englishName: "Al-Furqan"),
  26: SurahNameEntry(name: "الشعراء", englishName: "Ash-Shu'ara"),
  27: SurahNameEntry(name: "النمل", englishName: "An-Naml"),
  28: SurahNameEntry(name: "القصص", englishName: "Al-Qasas"),
  29: SurahNameEntry(name: "العنكبوت", englishName: "Al-Ankabut"),
  30: SurahNameEntry(name: "الروم", englishName: "Ar-Rum"),
  31: SurahNameEntry(name: "لقمان", englishName: "Luqman"),
  32: SurahNameEntry(name: "السجدة", englishName: "As-Sajdah"),
  33: SurahNameEntry(name: "الأحزاب", englishName: "Al-Ahzab"),
  34: SurahNameEntry(name: "سبأ", englishName: "Saba"),
  35: SurahNameEntry(name: "فاطر", englishName: "Fatir"),
  36: SurahNameEntry(name: "يس", englishName: "Ya-Sin"),
  37: SurahNameEntry(name: "الصافات", englishName: "As-Saffat"),
  38: SurahNameEntry(name: "ص", englishName: "Sad"),
  39: SurahNameEntry(name: "الزمر", englishName: "Az-Zumar"),
  40: SurahNameEntry(name: "غافر", englishName: "Ghafir"),
  41: SurahNameEntry(name: "فصلت", englishName: "Fussilat"),
  42: SurahNameEntry(name: "الشورى", englishName: "Ash-Shura"),
  43: SurahNameEntry(name: "الزخرف", englishName: "Az-Zukhruf"),
  44: SurahNameEntry(name: "الدخان", englishName: "Ad-Dukhan"),
  45: SurahNameEntry(name: "الجاثية", englishName: "Al-Jathiyah"),
  46: SurahNameEntry(name: "الأحقاف", englishName: "Al-Ahqaf"),
  47: SurahNameEntry(name: "محمد", englishName: "Muhammad"),
  48: SurahNameEntry(name: "الفتح", englishName: "Al-Fath"),
  49: SurahNameEntry(name: "الحجرات", englishName: "Al-Hujurat"),
  50: SurahNameEntry(name: "ق", englishName: "Qaf"),
  51: SurahNameEntry(name: "الذاريات", englishName: "Adh-Dhariyat"),
  52: SurahNameEntry(name: "الطور", englishName: "At-Tur"),
  53: SurahNameEntry(name: "النجم", englishName: "An-Najm"),
  54: SurahNameEntry(name: "القمر", englishName: "Al-Qamar"),
  55: SurahNameEntry(name: "الرحمن", englishName: "Ar-Rahman"),
  56: SurahNameEntry(name: "الواقعة", englishName: "Al-Waqi'ah"),
  57: SurahNameEntry(name: "الحديد", englishName: "Al-Hadid"),
  58: SurahNameEntry(name: "المجادلة", englishName: "Al-Mujadilah"),
  59: SurahNameEntry(name: "الحشر", englishName: "Al-Hashr"),
  60: SurahNameEntry(name: "الممتحنة", englishName: "Al-Mumtahanah"),
  61: SurahNameEntry(name: "الصف", englishName: "As-Saf"),
  62: SurahNameEntry(name: "الجمعة", englishName: "Al-Jumu'ah"),
  63: SurahNameEntry(name: "المنافقون", englishName: "Al-Munafiqun"),
  64: SurahNameEntry(name: "التغابن", englishName: "At-Taghabun"),
  65: SurahNameEntry(name: "الطلاق", englishName: "At-Talaq"),
  66: SurahNameEntry(name: "التحريم", englishName: "At-Tahrim"),
  67: SurahNameEntry(name: "الملك", englishName: "Al-Mulk"),
  68: SurahNameEntry(name: "القلم", englishName: "Al-Qalam"),
  69: SurahNameEntry(name: "الحاقة", englishName: "Al-Haqqah"),
  70: SurahNameEntry(name: "المعارج", englishName: "Al-Ma'arij"),
  71: SurahNameEntry(name: "نوح", englishName: "Nuh"),
  72: SurahNameEntry(name: "الجن", englishName: "Al-Jinn"),
  73: SurahNameEntry(name: "المزمل", englishName: "Al-Muzzammil"),
  74: SurahNameEntry(name: "المدثر", englishName: "Al-Muddaththir"),
  75: SurahNameEntry(name: "القيامة", englishName: "Al-Qiyamah"),
  76: SurahNameEntry(name: "الإنسان", englishName: "Al-Insan"),
  77: SurahNameEntry(name: "المرسلات", englishName: "Al-Mursalat"),
  78: SurahNameEntry(name: "النبأ", englishName: "An-Naba"),
  79: SurahNameEntry(name: "النازعات", englishName: "An-Nazi'at"),
  80: SurahNameEntry(name: "عبس", englishName: "Abasa"),
  81: SurahNameEntry(name: "التكوير", englishName: "At-Takwir"),
  82: SurahNameEntry(name: "الانفطار", englishName: "Al-Infitar"),
  83: SurahNameEntry(name: "المطففين", englishName: "Al-Mutaffifin"),
  84: SurahNameEntry(name: "الانشقاق", englishName: "Al-Inshiqaq"),
  85: SurahNameEntry(name: "البروج", englishName: "Al-Buruj"),
  86: SurahNameEntry(name: "الطارق", englishName: "At-Tariq"),
  87: SurahNameEntry(name: "الأعلى", englishName: "Al-A'la"),
  88: SurahNameEntry(name: "الغاشية", englishName: "Al-Ghashiyah"),
  89: SurahNameEntry(name: "الفجر", englishName: "Al-Fajr"),
  90: SurahNameEntry(name: "البلد", englishName: "Al-Balad"),
  91: SurahNameEntry(name: "الشمس", englishName: "Ash-Shams"),
  92: SurahNameEntry(name: "الليل", englishName: "Al-Layl"),
  93: SurahNameEntry(name: "الضحى", englishName: "Ad-Duhaa"),
  94: SurahNameEntry(name: "الشرح", englishName: "Ash-Sharh"),
  95: SurahNameEntry(name: "التين", englishName: "At-Tin"),
  96: SurahNameEntry(name: "العلق", englishName: "Al-Alaq"),
  97: SurahNameEntry(name: "القدر", englishName: "Al-Qadr"),
  98: SurahNameEntry(name: "البينة", englishName: "Al-Bayyinah"),
  99: SurahNameEntry(name: "الزلزلة", englishName: "Az-Zalzalah"),
  100: SurahNameEntry(name: "العاديات", englishName: "Al-Adiyat"),
  101: SurahNameEntry(name: "القارعة", englishName: "Al-Qari'ah"),
  102: SurahNameEntry(name: "التكاثر", englishName: "At-Takathur"),
  103: SurahNameEntry(name: "العصر", englishName: "Al-Asr"),
  104: SurahNameEntry(name: "الهمزة", englishName: "Al-Humazah"),
  105: SurahNameEntry(name: "الفيل", englishName: "Al-Fil"),
  106: SurahNameEntry(name: "قريش", englishName: "Quraysh"),
  107: SurahNameEntry(name: "الماعون", englishName: "Al-Ma'un"),
  108: SurahNameEntry(name: "الكوثر", englishName: "Al-Kawthar"),
  109: SurahNameEntry(name: "الكافرون", englishName: "Al-Kafirun"),
  110: SurahNameEntry(name: "النصر", englishName: "An-Nasr"),
  111: SurahNameEntry(name: "المسد", englishName: "Al-Masad"),
  112: SurahNameEntry(name: "الإخلاص", englishName: "Al-Ikhlas"),
  113: SurahNameEntry(name: "الفلق", englishName: "Al-Falaq"),
  114: SurahNameEntry(name: "الناس", englishName: "An-Nas"),
};

const Map<int, String> VOCALIZED_SURAH_TITLES = {
  1: "سُورَةُ الفَاتِحَةِ",
  2: "سُورَةُ البَقَرَةِ",
  3: "سُورَةُ آلِ عِمْرَانَ",
  4: "سُورَةُ النِّسَاءِ",
  5: "سُورَةُ المَائِدَةِ",
  6: "سُورَةُ الأَنْعَامِ",
  7: "سُورَةُ الأَعْرَافِ",
  8: "سُورَةُ الأَنْفَالِ",
  9: "سُورَةُ التَّوْبَةِ",
  10: "سُورَةُ يُونُسَ",
  11: "سُورَةُ هُودٍ",
  12: "سُورَةُ يُوسُفَ",
  13: "سُورَةُ الرَّعْدِ",
  14: "سُورَةُ إِبْرَاهِيمَ",
  15: "سُورَةُ الحِجْرِ",
  16: "سُورَةُ النَّحْلِ",
  17: "سُورَةُ الإِسْرَاءِ",
  18: "سُورَةُ الكَهْفِ",
  19: "سُورَةُ مَرْيَمَ",
  20: "سُورَةُ طٰهٰ",
  21: "سُورَةُ الأَنْبِيَاءِ",
  22: "سُورَةُ الحَجِّ",
  23: "سُورَةُ المُؤْمِنُونَ",
  24: "سُورَةُ النُّورِ",
  25: "سُورَةُ الفُرْقَانِ",
  26: "سُورَةُ الشُّعَرَاءِ",
  27: "سُورَةُ النَّمْلِ",
  28: "سُورَةُ القَصَصِ",
  29: "سُورَةُ العَنْكَبُوتِ",
  30: "سُورَةُ الرُّومِ",
  31: "سُورَةُ لُقْمَانَ",
  32: "سُورَةُ السَّجْدَةِ",
  33: "سُورَةُ الأَحْزَابِ",
  34: "سُورَةُ سَبَإٍ",
  35: "سُورَةُ فَاطِرٍ",
  36: "سُورَةُ يٰسٓ",
  37: "سُورَةُ الصَّافَّاتِ",
  38: "سُورَةُ صٓ",
  39: "سُورَةُ الزُّمَرِ",
  40: "سُورَةُ غَافِرٍ",
  41: "سُورَةُ فُصِّلَتْ",
  42: "سُورَةُ الشُّورَىٰ",
  43: "سُورَةُ الزُّخْرُفِ",
  44: "سُورَةُ الدُّخَانِ",
  45: "سُورَةُ الجَاثِيَةِ",
  46: "سُورَةُ الأَحْقَافِ",
  47: "سُورَةُ مُحَمَّدٍ",
  48: "سُورَةُ الفَتْحِ",
  49: "سُورَةُ الحُجُرَاتِ",
  50: "سُورَةُ قٓ",
  51: "سُورَةُ الذَّارِيَاتِ",
  52: "سُورَةُ الطُّورِ",
  53: "سُورَةُ النَّجْمِ",
  54: "سُورَةُ القَمَرِ",
  55: "سُورَةُ الرَّحْمَٰنِ",
  56: "سُورَةُ الوَاقِعَةِ",
  57: "سُورَةُ الحَدِيدِ",
  58: "سُورَةُ المُجَادَلَةِ",
  59: "سُورَةُ الحَشْرِ",
  60: "سُورَةُ المُمْتَحَنَةِ",
  61: "سُورَةُ الصَّفِّ",
  62: "سُورَةُ الجُمُعَةِ",
  63: "سُورَةُ المُنَافِقُونَ",
  64: "سُورَةُ التَّغَابُنِ",
  65: "سُورَةُ الطَّلَاقِ",
  66: "سُورَةُ التَّحْرِيمِ",
  67: "سُورَةُ المُلْكِ",
  68: "سُورَةُ القَلَمِ",
  69: "سُورَةُ الحَاقَّةِ",
  70: "سُورَةُ المَعَارِجِ",
  71: "سُورَةُ نُوحٍ",
  72: "سُورَةُ الجِنِّ",
  73: "سُورَةُ المُزَّمِّلِ",
  74: "سُورَةُ المُدَّثِّرِ",
  75: "سُورَةُ القِيَامَةِ",
  76: "سُورَةُ الإِنْسَانِ",
  77: "سُورَةُ المُرْسَلَاتِ",
  78: "سُورَةُ النَّبَإِ",
  79: "سُورَةُ النَّازِعَاتِ",
  80: "سُورَةُ عَبَسَ",
  81: "سُورَةُ التَّكْوِيرِ",
  82: "سُورَةُ الانْفِطَارِ",
  83: "سُورَةُ المُطَفِّفِينَ",
  84: "سُورَةُ الانْشِقَاقِ",
  85: "سُورَةُ البُرُوجِ",
  86: "سُورَةُ الطَّارِقِ",
  87: "سُورَةُ الأَعْلَىٰ",
  88: "سُورَةُ الغَاشِيَةِ",
  89: "سُورَةُ الفَجْرِ",
  90: "سُورَةُ البَلَدِ",
  91: "سُورَةُ الشَّمْسِ",
  92: "سُورَةُ اللَّيْلِ",
  93: "سُورَةُ الضُّحَىٰ",
  94: "سُورَةُ الشَّرْحِ",
  95: "سُورَةُ التِّينِ",
  96: "سُورَةُ العَلَقِ",
  97: "سُورَةُ القَدْرِ",
  98: "سُورَةُ البَيِّنَةِ",
  99: "سُورَةُ الزَّلْزَلَةِ",
  100: "سُورَةُ العَادِيَاتِ",
  101: "سُورَةُ القَارِعَةِ",
  102: "سُورَةُ التَّكَاثُرِ",
  103: "سُورَةُ العَصْرِ",
  104: "سُورَةُ الهُمَزَةِ",
  105: "سُورَةُ الفِيلِ",
  106: "سُورَةُ قُرَيْشٍ",
  107: "سُورَةُ المَاعُونِ",
  108: "سُورَةُ الكَوْثَرِ",
  109: "سُورَةُ الكَافِرُونَ",
  110: "سُورَةُ النَّصْرِ",
  111: "سُورَةُ المَسَدِ",
  112: "سُورَةُ الإِخْلَاصِ",
  113: "سُورَةُ الفَلَقِ",
  114: "سُورَةُ النَّاسِ",
};

String getVocalizedSurahTitle(int surahNumber) {
  return VOCALIZED_SURAH_TITLES[surahNumber] ??
      "سُورَةُ ${SURAH_NAMES[surahNumber]?.name ?? ''}";
}
