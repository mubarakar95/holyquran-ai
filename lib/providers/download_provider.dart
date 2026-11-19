import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/models/quran_types.dart';
import '../core/services/offline_audio_service.dart';
import 'service_providers.dart';

enum DownloadFilter {
  all,
  downloaded,
  notDownloaded,
}

class DownloadState {
  final Reciter selectedReciter;
  final bool isMalayalam;
  final Map<int, SurahDownloadInfo> surahInfoMap;
  final int? downloadingSurah;
  final int currentProgress;
  final int totalProgress;
  final int totalStorageBytes;
  final int reciterStorageBytes;
  final bool isBatchDownloading;
  final int batchCompletedSurahs;
  final int batchTotalSurahs;
  final String searchQuery;
  final DownloadFilter statusFilter;
  final String? errorMessage;

  const DownloadState({
    required this.selectedReciter,
    required this.isMalayalam,
    required this.surahInfoMap,
    this.downloadingSurah,
    this.currentProgress = 0,
    this.totalProgress = 0,
    this.totalStorageBytes = 0,
    this.reciterStorageBytes = 0,
    this.isBatchDownloading = false,
    this.batchCompletedSurahs = 0,
    this.batchTotalSurahs = 0,
    this.searchQuery = '',
    this.statusFilter = DownloadFilter.all,
    this.errorMessage,
  });

  Set<int> get downloadedSurahs {
    return surahInfoMap.entries
        .where((e) => e.value.isComplete)
        .map((e) => e.key)
        .toSet();
  }

  DownloadState copyWith({
    Reciter? selectedReciter,
    bool? isMalayalam,
    Map<int, SurahDownloadInfo>? surahInfoMap,
    int? Function()? downloadingSurah,
    int? currentProgress,
    int? totalProgress,
    int? totalStorageBytes,
    int? reciterStorageBytes,
    bool? isBatchDownloading,
    int? batchCompletedSurahs,
    int? batchTotalSurahs,
    String? searchQuery,
    DownloadFilter? statusFilter,
    String? Function()? errorMessage,
  }) {
    return DownloadState(
      selectedReciter: selectedReciter ?? this.selectedReciter,
      isMalayalam: isMalayalam ?? this.isMalayalam,
      surahInfoMap: surahInfoMap ?? this.surahInfoMap,
      downloadingSurah: downloadingSurah != null ? downloadingSurah() : this.downloadingSurah,
      currentProgress: currentProgress ?? this.currentProgress,
      totalProgress: totalProgress ?? this.totalProgress,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      reciterStorageBytes: reciterStorageBytes ?? this.reciterStorageBytes,
      isBatchDownloading: isBatchDownloading ?? this.isBatchDownloading,
      batchCompletedSurahs: batchCompletedSurahs ?? this.batchCompletedSurahs,
      batchTotalSurahs: batchTotalSurahs ?? this.batchTotalSurahs,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;
  CancelToken? _cancelToken;
  bool _batchCancelled = false;

  DownloadNotifier(this._ref)
      : super(DownloadState(
          selectedReciter: RECITERS[0],
          isMalayalam: false,
          surahInfoMap: {},
        )) {
    refreshStatus();
  }

  String get currentReciterKey =>
      state.isMalayalam ? 'malayalam' : state.selectedReciter.id;

  Future<void> refreshStatus() async {
    final offline = _ref.read(offlineAudioServiceProvider);
    final key = currentReciterKey;
    final infoMap = await offline.getAllSurahsDownloadInfo(key);
    final reciterBytes = await offline.getReciterStorageBytes(key);
    final totalBytes = await offline.getTotalStorageBytes();

    state = state.copyWith(
      surahInfoMap: infoMap,
      reciterStorageBytes: reciterBytes,
      totalStorageBytes: totalBytes,
    );
  }

  void selectReciter(Reciter reciter) {
    if (state.downloadingSurah != null || state.isBatchDownloading) {
      cancelDownload();
    }
    state = state.copyWith(
      selectedReciter: reciter,
      isMalayalam: false,
      errorMessage: () => null,
    );
    refreshStatus();
  }

  void toggleMalayalam(bool isMl) {
    if (state.downloadingSurah != null || state.isBatchDownloading) {
      cancelDownload();
    }
    state = state.copyWith(
      isMalayalam: isMl,
      errorMessage: () => null,
    );
    refreshStatus();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(DownloadFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  Future<void> downloadSurah(int surahNumber) async {
    if (state.downloadingSurah != null) return;
    _cancelToken = CancelToken();

    state = state.copyWith(
      downloadingSurah: () => surahNumber,
      currentProgress: 0,
      totalProgress: SURAH_AYAH_COUNTS[surahNumber - 1],
      errorMessage: () => null,
    );

    final offline = _ref.read(offlineAudioServiceProvider);

    try {
      await offline.downloadSurahAudio(
        reciter: state.selectedReciter,
        surahNumber: surahNumber,
        isMalayalam: state.isMalayalam,
        cancelToken: _cancelToken,
        onProgress: (current, total) {
          state = state.copyWith(
            currentProgress: current,
            totalProgress: total,
          );
        },
      );
    } catch (e) {
      if (!(_cancelToken?.isCancelled ?? false)) {
        state = state.copyWith(
          errorMessage: () => 'Download failed for Surah $surahNumber. Please check your internet connection.',
        );
      }
    } finally {
      _cancelToken = null;
      state = state.copyWith(downloadingSurah: () => null);
      await refreshStatus();
    }
  }

  Future<void> downloadAllSurahs() async {
    if (state.isBatchDownloading || state.downloadingSurah != null) return;

    final offline = _ref.read(offlineAudioServiceProvider);
    final key = currentReciterKey;
    final infoMap = await offline.getAllSurahsDownloadInfo(key);

    // List of surahs needing download
    final incompleteSurahs = <int>[];
    for (int s = 1; s <= 114; s++) {
      final info = infoMap[s];
      if (info == null || !info.isComplete) {
        incompleteSurahs.add(s);
      }
    }

    if (incompleteSurahs.isEmpty) return;

    _batchCancelled = false;
    state = state.copyWith(
      isBatchDownloading: true,
      batchCompletedSurahs: 0,
      batchTotalSurahs: incompleteSurahs.length,
      errorMessage: () => null,
    );

    for (int i = 0; i < incompleteSurahs.length; i++) {
      if (_batchCancelled) break;

      final surahNum = incompleteSurahs[i];
      _cancelToken = CancelToken();

      state = state.copyWith(
        downloadingSurah: () => surahNum,
        currentProgress: 0,
        totalProgress: SURAH_AYAH_COUNTS[surahNum - 1],
        batchCompletedSurahs: i,
      );

      try {
        await offline.downloadSurahAudio(
          reciter: state.selectedReciter,
          surahNumber: surahNum,
          isMalayalam: state.isMalayalam,
          cancelToken: _cancelToken,
          onProgress: (current, total) {
            state = state.copyWith(
              currentProgress: current,
              totalProgress: total,
            );
          },
        );
      } catch (e) {
        if (_batchCancelled || (_cancelToken?.isCancelled ?? false)) {
          break;
        }
        // Continue to next surah on error, but record message
        state = state.copyWith(
          errorMessage: () => 'Issue downloading Surah $surahNum. Continuing remaining surahs...',
        );
      } finally {
        _cancelToken = null;
        await refreshStatus();
      }
    }

    state = state.copyWith(
      isBatchDownloading: false,
      downloadingSurah: () => null,
      batchCompletedSurahs: 0,
      batchTotalSurahs: 0,
    );
    await refreshStatus();
  }

  void cancelDownload() {
    _batchCancelled = true;
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(
      downloadingSurah: () => null,
      isBatchDownloading: false,
    );
  }

  Future<void> deleteSurah(int surahNumber) async {
    final offline = _ref.read(offlineAudioServiceProvider);
    await offline.deleteSurahAudio(currentReciterKey, surahNumber);
    await refreshStatus();
  }

  Future<void> deleteCurrentReciterStorage() async {
    final offline = _ref.read(offlineAudioServiceProvider);
    await offline.deleteReciterAudio(currentReciterKey);
    await refreshStatus();
  }

  Future<void> clearAllCache() async {
    final offline = _ref.read(offlineAudioServiceProvider);
    await offline.clearAllAudio();
    await refreshStatus();
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});
