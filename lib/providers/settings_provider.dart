import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'service_providers.dart';

class SettingsState {
  final AppThemeMode theme;
  final int arFontSize;
  final int mlFontSize;
  final int lineHeight;
  final int hoverDelay;
  final int hoverFontSize;
  final String ayahDress;
  final String frameDress;
  final String surahHeaderDress;
  final String geminiApiKey;

  const SettingsState({
    required this.theme,
    required this.arFontSize,
    required this.mlFontSize,
    required this.lineHeight,
    required this.hoverDelay,
    required this.hoverFontSize,
    this.ayahDress = 'hafs-adi',
    this.frameDress = 'madani',
    this.surahHeaderDress = 'madani',
    required this.geminiApiKey,
  });

  SettingsState copyWith({
    AppThemeMode? theme,
    int? arFontSize,
    int? mlFontSize,
    int? lineHeight,
    int? hoverDelay,
    int? hoverFontSize,
    String? ayahDress,
    String? frameDress,
    String? surahHeaderDress,
    String? geminiApiKey,
  }) {
    return SettingsState(
      theme: theme ?? this.theme,
      arFontSize: arFontSize ?? this.arFontSize,
      mlFontSize: mlFontSize ?? this.mlFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      hoverDelay: hoverDelay ?? this.hoverDelay,
      hoverFontSize: hoverFontSize ?? this.hoverFontSize,
      ayahDress: ayahDress ?? this.ayahDress,
      frameDress: frameDress ?? this.frameDress,
      surahHeaderDress: surahHeaderDress ?? this.surahHeaderDress,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsNotifier(this._ref)
      : super(SettingsState(
          theme: AppThemeMode.fromString(_ref.read(localStorageServiceProvider).theme),
          arFontSize: _ref.read(localStorageServiceProvider).arFontSize,
          mlFontSize: _ref.read(localStorageServiceProvider).mlFontSize,
          lineHeight: _ref.read(localStorageServiceProvider).lineHeight,
          hoverDelay: _ref.read(localStorageServiceProvider).hoverDelay,
          hoverFontSize: _ref.read(localStorageServiceProvider).hoverFontSize,
          ayahDress: _ref.read(localStorageServiceProvider).ayahDress,
          frameDress: _ref.read(localStorageServiceProvider).frameDress,
          surahHeaderDress: _ref.read(localStorageServiceProvider).surahHeaderDress,
          geminiApiKey: _ref.read(localStorageServiceProvider).geminiApiKey,
        ));

  void setTheme(AppThemeMode mode) {
    state = state.copyWith(theme: mode);
    _ref.read(localStorageServiceProvider).theme = mode.value;
  }

  void toggleTheme() {
    switch (state.theme) {
      case AppThemeMode.light:
        setTheme(AppThemeMode.creme);
        break;
      case AppThemeMode.creme:
        setTheme(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        setTheme(AppThemeMode.light);
        break;
    }
  }

  void setArFontSize(int size) {
    state = state.copyWith(arFontSize: size.clamp(60, 200));
    _ref.read(localStorageServiceProvider).arFontSize = state.arFontSize;
  }

  void setMlFontSize(int size) {
    state = state.copyWith(mlFontSize: size.clamp(60, 200));
    _ref.read(localStorageServiceProvider).mlFontSize = state.mlFontSize;
  }

  void setLineHeight(int height) {
    state = state.copyWith(lineHeight: height.clamp(60, 200));
    _ref.read(localStorageServiceProvider).lineHeight = state.lineHeight;
  }

  void setHoverDelay(int delay) {
    state = state.copyWith(hoverDelay: delay);
    _ref.read(localStorageServiceProvider).hoverDelay = delay;
  }

  void setHoverFontSize(int size) {
    state = state.copyWith(hoverFontSize: size);
    _ref.read(localStorageServiceProvider).hoverFontSize = size;
  }

  void setAyahDress(String dress) {
    state = state.copyWith(ayahDress: dress);
    _ref.read(localStorageServiceProvider).ayahDress = dress;
  }

  void setFrameDress(String dress) {
    state = state.copyWith(frameDress: dress);
    _ref.read(localStorageServiceProvider).frameDress = dress;
  }

  void setSurahHeaderDress(String dress) {
    state = state.copyWith(surahHeaderDress: dress);
    _ref.read(localStorageServiceProvider).surahHeaderDress = dress;
  }

  void setGeminiApiKey(String key) {
    state = state.copyWith(geminiApiKey: key);
    _ref.read(localStorageServiceProvider).geminiApiKey = key;
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
