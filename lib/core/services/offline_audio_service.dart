import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/quran_types.dart';

const List<int> SURAH_AYAH_COUNTS = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
  5, 4, 5, 6
];

final List<int> _globalAyahOffset = () {
  final offsets = List<int>.filled(115, 0);
  for (int i = 1; i <= 114; i++) {
    offsets[i] = offsets[i - 1] + SURAH_AYAH_COUNTS[i - 1];
  }
  return offsets;
}();

int getGlobalAyahNumber(int surah, int ayahInSurah) {
  return _globalAyahOffset[surah - 1] + ayahInSurah;
}

String getRemoteAudioUrl(Reciter reciter, int surahNumber, int ayahInSurah) {
  if (reciter.audioFormat == AudioFormat.global) {
    final globalNum = getGlobalAyahNumber(surahNumber, ayahInSurah);
    return '${reciter.audioBase}/$globalNum.mp3';
  }
  final s = surahNumber.toString().padLeft(3, '0');
  final a = ayahInSurah.toString().padLeft(3, '0');
  return '${reciter.audioBase}/$s$a.mp3';
}

const String LALITHASARAM_AUDIO_BASE = "https://lalithasaram.net/audio/qtaud/transl";

String getRemoteMalayalamAudioUrl(int surahNumber, int ayahInSurah) {
  final s = surahNumber.toString().padLeft(3, '0');
  final a = ayahInSurah.toString().padLeft(3, '0');
  return '$LALITHASARAM_AUDIO_BASE/${s}_$a.mp3';
}

class SurahDownloadInfo {
  final int surahNumber;
  final int downloadedCount;
  final int totalAyahs;
  final int totalBytes;

  const SurahDownloadInfo({
    required this.surahNumber,
    required this.downloadedCount,
    required this.totalAyahs,
    required this.totalBytes,
  });

  bool get isComplete => downloadedCount >= totalAyahs && totalAyahs > 0;
  bool get isPartial => downloadedCount > 0 && downloadedCount < totalAyahs;
  double get progress => totalAyahs > 0 ? (downloadedCount / totalAyahs).clamp(0.0, 1.0) : 0.0;
}

class OfflineAudioService {
  final Dio _dio;
  Directory? _baseDir;

  OfflineAudioService([Dio? dio]) : _dio = dio ?? Dio();

  Future<Directory> _getAudioDirectory() async {
    if (_baseDir != null) return _baseDir!;
    final appDocDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDocDir.path}/quran_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    _baseDir = audioDir;
    return audioDir;
  }

  Future<File> getAudioFile(String reciterId, int surahNumber, int ayahNumber) async {
    final dir = await _getAudioDirectory();
    return File('${dir.path}/$reciterId/$surahNumber/$ayahNumber.mp3');
  }

  Future<String?> getLocalAudioPathIfExists(String reciterId, int surahNumber, int ayahNumber) async {
    final file = await getAudioFile(reciterId, surahNumber, ayahNumber);
    if (await file.exists() && (await file.length()) > 0) {
      return file.path;
    }
    return null;
  }

  /// Silently caches an on-demand streamed ayah file into the offline audio directory
  /// so subsequent offline playbacks succeed without full manual surah download.
  Future<void> cacheAyahAudio({
    required Reciter? reciter,
    required String reciterKey,
    required int surahNumber,
    required int ayahNumber,
    required bool isMalayalam,
  }) async {
    final file = await getAudioFile(reciterKey, surahNumber, ayahNumber);
    if (await file.exists() && (await file.length()) > 0) {
      return; // Already cached
    }

    try {
      await file.parent.create(recursive: true);
      final url = isMalayalam
          ? getRemoteMalayalamAudioUrl(surahNumber, ayahNumber)
          : getRemoteAudioUrl(reciter!, surahNumber, ayahNumber);

      final tmpFile = File('${file.path}.tmp_${DateTime.now().millisecondsSinceEpoch}');
      await _dio.download(
        url,
        tmpFile.path,
        options: Options(
          headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (await tmpFile.exists() && (await tmpFile.length()) > 0) {
        await tmpFile.rename(file.path);
        debugPrint('[OfflineAudio] Cached on-demand audio for $reciterKey $surahNumber:$ayahNumber');
      } else {
        if (await tmpFile.exists()) await tmpFile.delete();
      }
    } catch (e) {
      debugPrint('[OfflineAudio] Non-fatal notice caching on-demand audio: $e');
    }
  }

  Future<bool> isAyahDownloaded(String reciterId, int surahNumber, int ayahNumber) async {
    final file = await getAudioFile(reciterId, surahNumber, ayahNumber);
    return (await file.exists()) && (await file.length()) > 0;
  }

  Future<bool> isSurahDownloaded(String reciterId, int surahNumber) async {
    final info = await getSurahDownloadInfo(reciterId, surahNumber);
    return info.isComplete;
  }

  Future<Set<int>> getDownloadedSurahs(String reciterId) async {
    final allInfo = await getAllSurahsDownloadInfo(reciterId);
    final result = <int>{};
    for (final entry in allInfo.entries) {
      if (entry.value.isComplete) {
        result.add(entry.key);
      }
    }
    return result;
  }

  Future<SurahDownloadInfo> getSurahDownloadInfo(String reciterKey, int surahNumber) async {
    if (surahNumber < 1 || surahNumber > 114) {
      return SurahDownloadInfo(
        surahNumber: surahNumber,
        downloadedCount: 0,
        totalAyahs: 0,
        totalBytes: 0,
      );
    }

    final totalAyahs = SURAH_AYAH_COUNTS[surahNumber - 1];
    final baseDir = await _getAudioDirectory();
    final surahDir = Directory('${baseDir.path}/$reciterKey/$surahNumber');

    if (!await surahDir.exists()) {
      return SurahDownloadInfo(
        surahNumber: surahNumber,
        downloadedCount: 0,
        totalAyahs: totalAyahs,
        totalBytes: 0,
      );
    }

    int count = 0;
    int bytes = 0;

    try {
      final entities = await surahDir.list(followLinks: false).toList();
      for (final e in entities) {
        if (e is File && e.path.endsWith('.mp3')) {
          final len = await e.length();
          if (len > 0) {
            count++;
            bytes += len;
          }
        }
      }
    } catch (e) {
      debugPrint('Error inspecting surah dir $surahNumber: $e');
    }

    return SurahDownloadInfo(
      surahNumber: surahNumber,
      downloadedCount: count,
      totalAyahs: totalAyahs,
      totalBytes: bytes,
    );
  }

  Future<Map<int, SurahDownloadInfo>> getAllSurahsDownloadInfo(String reciterKey) async {
    final result = <int, SurahDownloadInfo>{};
    final baseDir = await _getAudioDirectory();
    final reciterDir = Directory('${baseDir.path}/$reciterKey');

    for (int s = 1; s <= 114; s++) {
      result[s] = SurahDownloadInfo(
        surahNumber: s,
        downloadedCount: 0,
        totalAyahs: SURAH_AYAH_COUNTS[s - 1],
        totalBytes: 0,
      );
    }

    if (!await reciterDir.exists()) {
      return result;
    }

    try {
      final surahDirs = await reciterDir.list(followLinks: false).toList();
      for (final entity in surahDirs) {
        if (entity is Directory) {
          final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final sNum = int.tryParse(name);
          if (sNum != null && sNum >= 1 && sNum <= 114) {
            int count = 0;
            int bytes = 0;
            final files = await entity.list(followLinks: false).toList();
            for (final f in files) {
              if (f is File && f.path.endsWith('.mp3')) {
                final len = await f.length();
                if (len > 0) {
                  count++;
                  bytes += len;
                }
              }
            }
            result[sNum] = SurahDownloadInfo(
              surahNumber: sNum,
              downloadedCount: count,
              totalAyahs: SURAH_AYAH_COUNTS[sNum - 1],
              totalBytes: bytes,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading reciter dir $reciterKey: $e');
    }

    return result;
  }

  Future<void> downloadSurahAudio({
    required Reciter reciter,
    required int surahNumber,
    bool isMalayalam = false,
    void Function(int current, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final reciterKey = isMalayalam ? 'malayalam' : reciter.id;
    final totalAyahs = SURAH_AYAH_COUNTS[surahNumber - 1];

    // Identify which ayahs still need downloading
    final pendingAyahs = <int>[];
    int alreadyDownloaded = 0;

    for (int a = 1; a <= totalAyahs; a++) {
      final file = await getAudioFile(reciterKey, surahNumber, a);
      if (await file.exists() && (await file.length()) > 0) {
        alreadyDownloaded++;
      } else {
        pendingAyahs.add(a);
      }
    }

    onProgress?.call(alreadyDownloaded, totalAyahs);

    if (pendingAyahs.isEmpty) {
      return;
    }

    // Controlled concurrent download with retry
    int nextIndex = 0;
    int completedCount = alreadyDownloaded;
    const int concurrency = 3;

    Future<void> worker() async {
      while (true) {
        if (cancelToken?.isCancelled ?? false) break;

        if (nextIndex >= pendingAyahs.length) break;
        final ayah = pendingAyahs[nextIndex++];

        await _downloadAyahWithRetry(
          reciter: reciter,
          reciterKey: reciterKey,
          surahNumber: surahNumber,
          ayahNumber: ayah,
          isMalayalam: isMalayalam,
          cancelToken: cancelToken,
        );

        completedCount++;
        onProgress?.call(completedCount, totalAyahs);
      }
    }

    final workerCount = min(concurrency, pendingAyahs.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> _downloadAyahWithRetry({
    required Reciter reciter,
    required String reciterKey,
    required int surahNumber,
    required int ayahNumber,
    required bool isMalayalam,
    CancelToken? cancelToken,
    int maxRetries = 3,
  }) async {
    final file = await getAudioFile(reciterKey, surahNumber, ayahNumber);
    await file.parent.create(recursive: true);

    final url = isMalayalam
        ? getRemoteMalayalamAudioUrl(surahNumber, ayahNumber)
        : getRemoteAudioUrl(reciter, surahNumber, ayahNumber);

    final tmpFile = File('${file.path}.tmp');

    int attempts = 0;
    while (attempts < maxRetries) {
      if (cancelToken?.isCancelled ?? false) {
        if (await tmpFile.exists()) await tmpFile.delete();
        throw DioException(
          requestOptions: RequestOptions(path: url),
          type: DioExceptionType.cancel,
        );
      }

      attempts++;
      try {
        if (await tmpFile.exists()) await tmpFile.delete();

        await _dio.download(
          url,
          tmpFile.path,
          cancelToken: cancelToken,
          options: Options(
            headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 25),
          ),
        );

        if (await tmpFile.exists() && (await tmpFile.length()) > 0) {
          await tmpFile.rename(file.path);
          return;
        } else {
          throw Exception('Downloaded file is empty or corrupted');
        }
      } catch (e) {
        if (cancelToken?.isCancelled ?? false) {
          if (await tmpFile.exists()) await tmpFile.delete();
          rethrow;
        }
        if (attempts >= maxRetries) {
          if (await tmpFile.exists()) await tmpFile.delete();
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 350 * attempts));
      }
    }
  }

  Future<void> deleteSurahAudio(String reciterId, int surahNumber) async {
    final dir = await _getAudioDirectory();
    final surahDir = Directory('${dir.path}/$reciterId/$surahNumber');
    if (await surahDir.exists()) {
      await surahDir.delete(recursive: true);
    }
  }

  Future<void> deleteReciterAudio(String reciterKey) async {
    final dir = await _getAudioDirectory();
    final reciterDir = Directory('${dir.path}/$reciterKey');
    if (await reciterDir.exists()) {
      await reciterDir.delete(recursive: true);
    }
  }

  Future<int> getReciterStorageBytes(String reciterKey) async {
    final dir = await _getAudioDirectory();
    final reciterDir = Directory('${dir.path}/$reciterKey');
    if (!await reciterDir.exists()) return 0;
    int total = 0;
    await for (final file in reciterDir.list(recursive: true, followLinks: false)) {
      if (file is File && file.path.endsWith('.mp3')) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<int> getTotalStorageBytes() async {
    final dir = await _getAudioDirectory();
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final file in dir.list(recursive: true, followLinks: false)) {
      if (file is File && file.path.endsWith('.mp3')) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<void> clearAllAudio() async {
    final dir = await _getAudioDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }
}
