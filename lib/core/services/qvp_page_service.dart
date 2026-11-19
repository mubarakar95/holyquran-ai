import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/qvp_models.dart';

class QvpPageService {
  final Dio _dio;
  final Map<int, QvpDecodedPage> _memoryCache = {};
  final Map<int, Future<QvpDecodedPage>> _inflight = {};

  static const String _primaryCdn = "https://cdn.quran.ws/qvp/v0.5.0";
  static const String _fallbackCdn = "https://raw.githubusercontent.com/quran-ws/quran-engine/main/crates/qvp-core/test-pages";

  QvpPageService([Dio? dio]) : _dio = dio ?? Dio();

  Future<Directory> _getPagesDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/qvp_pages');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<QvpDecodedPage> getPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > 604) {
      throw RangeError('Page number must be between 1 and 604');
    }

    if (_memoryCache.containsKey(pageNumber)) {
      return _memoryCache[pageNumber]!;
    }

    if (_inflight.containsKey(pageNumber)) {
      return _inflight[pageNumber]!;
    }

    final future = _loadPage(pageNumber);
    _inflight[pageNumber] = future;

    try {
      final page = await future;
      _memoryCache[pageNumber] = page;
      // Pre-warm the UI Path cache in background/memory
      page.getUiPaths();
      return page;
    } finally {
      _inflight.remove(pageNumber);
    }
  }

  Future<QvpDecodedPage> _loadPage(int pageNumber) async {
    final padded = pageNumber.toString().padLeft(3, '0');
    Uint8List? bytes;

    // 1. Try bundled asset directly (zero flash duplication, 100% offline from APK)
    try {
      final assetData = await rootBundle.load('assets/data/qvp/$padded.qvp');
      bytes = assetData.buffer.asUint8List();
    } catch (_) {
      // Not bundled, proceed to check local file cache or CDN
    }

    // 2. Try local disk cache if not bundled
    File? localFile;
    if (bytes == null || bytes.isEmpty) {
      final pagesDir = await _getPagesDir();
      localFile = File('${pagesDir.path}/$padded.qvp');
      if (await localFile.exists()) {
        try {
          bytes = await localFile.readAsBytes();
        } catch (e) {
          debugPrint('Error reading cached QVP page $pageNumber: $e');
        }
      }
    }

    // 3. Fallback: Download from CDN if not bundled and not on disk
    if (bytes == null || bytes.isEmpty) {
      final urls = [
        '$_primaryCdn/$padded.qvp',
        '$_fallbackCdn/$padded.qvp',
      ];

      for (final url in urls) {
        try {
          final res = await _dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

          if (res.data != null && res.statusCode == 200) {
            bytes = Uint8List.fromList(res.data!);
            if (localFile != null) {
              await localFile.writeAsBytes(bytes, flush: true);
            }
            break;
          }
        } catch (e) {
          debugPrint('Error downloading QVP page from $url: $e');
        }
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Failed to load QVP page $pageNumber from cache or network');
    }

    return QvpDecoder.decode(bytes);
  }

  /// Preload neighbor pages asynchronously in the background
  void preloadNeighborPages(int currentPage) {
    final neighbors = [
      currentPage + 1,
      currentPage - 1,
      currentPage + 2,
      currentPage - 2,
    ];

    for (final page in neighbors) {
      if (page >= 1 && page <= 604 && !_memoryCache.containsKey(page) && !_inflight.containsKey(page)) {
        getPage(page).catchError((e) {
          debugPrint('Background preload error for page $page: $e');
          return QvpDecodedPage(
            pageNumber: page,
            width: 345,
            height: 550,
            lines: [],
            ayahs: [],
            words: [],
            decorations: [],
            paths: [],
          );
        });
      }
    }
  }
}
