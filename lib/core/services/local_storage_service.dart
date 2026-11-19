import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  SharedPreferences get prefs => _prefs;

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // Current page
  int get currentPage => _prefs.getInt('quran-page') ?? 1;
  set currentPage(int page) => _prefs.setInt('quran-page', page);

  // Theme
  String get theme => _prefs.getString('quran-theme') ?? 'light';
  set theme(String val) => _prefs.setString('quran-theme', val);

  // Reciter
  String get reciterId => _prefs.getString('quran-reciter') ?? 'ar.alafasy';
  set reciterId(String id) => _prefs.setString('quran-reciter', id);

  // Playback rates
  double get arabicPlaybackRate => _prefs.getDouble('quran-playback-rate-arabic') ?? 1.0;
  set arabicPlaybackRate(double rate) => _prefs.setDouble('quran-playback-rate-arabic', rate);

  double get malayalamPlaybackRate => _prefs.getDouble('quran-playback-rate-malayalam') ?? 1.0;
  set malayalamPlaybackRate(double rate) => _prefs.setDouble('quran-playback-rate-malayalam', rate);

  // Repeat mode
  String get repeatMode => _prefs.getString('quran-repeat-mode') ?? 'none';
  set repeatMode(String mode) => _prefs.setString('quran-repeat-mode', mode);

  // View modes
  bool get showTranslation => _prefs.getBool('quran-show-translation') ?? false;
  set showTranslation(bool val) => _prefs.setBool('quran-show-translation', val);

  bool get showWordByWord => _prefs.getBool('quran-show-word-by-word') ?? false;
  set showWordByWord(bool val) => _prefs.setBool('quran-show-word-by-word', val);

  bool get showSwipeWBW => _prefs.getBool('quran-show-swipe-wbw') ?? false;
  set showSwipeWBW(bool val) => _prefs.setBool('quran-show-swipe-wbw', val);

  // Audio Segmented Mode (clause interleaving in Both mode)
  bool get segmentedMode => _prefs.getBool('quran-segmented-mode') ?? true;
  set segmentedMode(bool val) => _prefs.setBool('quran-segmented-mode', val);

  // Audio Mode ('arabic', 'malayalam', 'both')
  String get audioMode => _prefs.getString('quran-audio-mode') ?? 'arabic';
  set audioMode(String mode) => _prefs.setString('quran-audio-mode', mode);

  bool get twoPageMode => _prefs.getBool('quran-two-page-mode') ?? false;
  set twoPageMode(bool val) => _prefs.setBool('quran-two-page-mode', val);

  // Font scales & Line height
  int get arFontSize => _prefs.getInt('quran-ar-font-size') ?? 100;
  set arFontSize(int size) => _prefs.setInt('quran-ar-font-size', size);

  int get mlFontSize => _prefs.getInt('quran-ml-font-size') ?? 100;
  set mlFontSize(int size) => _prefs.setInt('quran-ml-font-size', size);

  int get lineHeight => _prefs.getInt('quran-line-height') ?? 100;
  set lineHeight(int height) => _prefs.setInt('quran-line-height', height);

  // Hover settings
  int get hoverDelay => _prefs.getInt('quran-hover-delay') ?? 80;
  set hoverDelay(int delay) => _prefs.setInt('quran-hover-delay', delay);

  int get hoverFontSize => _prefs.getInt('quran-hover-size') ?? 18;
  set hoverFontSize(int size) => _prefs.setInt('quran-hover-size', size);

  // Ayah Marker Dress ('hafs-adi' or 'classic')
  String get ayahDress => _prefs.getString('quran-ayah-dress') ?? 'hafs-adi';
  set ayahDress(String val) => _prefs.setString('quran-ayah-dress', val);

  // Frame Dress ('madani', 'minimal', or 'none')
  String get frameDress => _prefs.getString('quran-frame-dress') ?? 'madani';
  set frameDress(String val) => _prefs.setString('quran-frame-dress', val);

  // Surah Header Dress ('madani' or 'classic')
  String get surahHeaderDress => _prefs.getString('quran-surah-header-dress') ?? 'madani';
  set surahHeaderDress(String val) => _prefs.setString('quran-surah-header-dress', val);

  // Gemini API Key
  String get geminiApiKey => _prefs.getString('gemini-api-key') ?? '';
  set geminiApiKey(String key) => _prefs.setString('gemini-api-key', key.trim());

  // Vocabulary progress JSON map
  Map<String, dynamic> get vocabProgress {
    final raw = _prefs.getString('quran-vocab-progress');
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  set vocabProgress(Map<String, dynamic> map) {
    _prefs.setString('quran-vocab-progress', jsonEncode(map));
  }

  // Vocabulary quiz repetition list
  List<String> get vocabRepetitionList {
    return _prefs.getStringList('quran-vocab-repetition') ?? [];
  }

  set vocabRepetitionList(List<String> list) {
    _prefs.setStringList('quran-vocab-repetition', list);
  }

  // Mushtabihat bookmarks
  List<String> get mushtabihatBookmarks {
    return _prefs.getStringList('mushtabihat-bookmarks') ?? [];
  }

  set mushtabihatBookmarks(List<String> list) {
    _prefs.setStringList('mushtabihat-bookmarks', list);
  }

  // Mushtabihat hidden
  List<String> get mushtabihatHidden {
    return _prefs.getStringList('mushtabihat-hidden') ?? [];
  }

  set mushtabihatHidden(List<String> list) {
    _prefs.setStringList('mushtabihat-hidden', list);
  }
}
