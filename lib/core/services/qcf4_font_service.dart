import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/qcf4_models.dart';

class Qcf4FontService {
  final Dio _dio;
  final Set<String> _loadedFonts = {'QCF4_QBSML', 'QCF4_Hafs_01'};
  final Map<int, PageData2> _pageCache = {};
  final Map<String, Future<void>> _fontInflight = {};

  static const String _rawBase = "https://raw.githubusercontent.com/MohamadHajjRabee/quran-qcf4/main";
  static const String _cdnBase = "https://cdn.jsdelivr.net/gh/MohamadHajjRabee/quran-qcf4@main";

  Qcf4FontService([Dio? dio]) : _dio = dio ?? Dio();

  Future<Directory> _getPagesDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/qcf4_pages');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _getFontsDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/qcf4_fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<PageData2> fetchPageData(int page) async {
    if (_pageCache.containsKey(page)) {
      return _pageCache[page]!;
    }

    final padded = page.toString().padLeft(3, '0');
    final pagesDir = await _getPagesDir();
    final localFile = File('${pagesDir.path}/$padded.json');

    Map<String, dynamic>? jsonMap;

    if (await localFile.exists()) {
      try {
        final text = await localFile.readAsString();
        jsonMap = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (jsonMap == null) {
      final urls = [
        '$_rawBase/pages/$padded.json',
        '$_cdnBase/pages/$padded.json',
      ];

      for (final url in urls) {
        try {
          final res = await _dio.get<String>(
            url,
            options: Options(
              responseType: ResponseType.plain,
              headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
            ),
          );
          if (res.data != null && res.statusCode == 200) {
            jsonMap = jsonDecode(res.data!) as Map<String, dynamic>;
            await localFile.writeAsString(res.data!);
            break;
          }
        } catch (e) {
          debugPrint('Error fetching page from $url: $e');
        }
      }
    }

    if (jsonMap == null) {
      throw Exception('Failed to load page data for page $page');
    }

    final pageData = PageData2.fromJson(jsonMap);
    _pageCache[page] = pageData;

    // Await all fonts used on this page so layout calculations and glyphs render accurately
    final fontsToLoad = <String>{};
    if (pageData.font.isNotEmpty) {
      fontsToLoad.add(pageData.font);
    }
    for (final line in pageData.lines) {
      for (final word in line.words) {
        if (word.font.isNotEmpty) {
          fontsToLoad.add(word.font);
        }
      }
    }

    try {
      await Future.wait(fontsToLoad.map((f) => ensureFontLoaded(f)));
    } catch (e) {
      debugPrint('Warning: Some fonts for page $page could not be loaded: $e');
    }

    return pageData;
  }

  Future<void> ensureFontLoaded(String fontName) {
    if (_loadedFonts.contains(fontName)) {
      return Future.value();
    }
    if (_fontInflight.containsKey(fontName)) {
      return _fontInflight[fontName]!;
    }

    final future = _loadFontInternal(fontName).then((_) {
      _loadedFonts.add(fontName);
      _fontInflight.remove(fontName);
    }).catchError((err) {
      _fontInflight.remove(fontName);
      throw err;
    });

    _fontInflight[fontName] = future;
    return future;
  }

  Future<void> _loadFontInternal(String fontName) async {
    final fontsDir = await _getFontsDir();
    final suffix = fontName == 'QCF4_QBSML' ? '' : '_W';
    final fileName = '$fontName$suffix.ttf';
    final fontFile = File('${fontsDir.path}/$fileName');

    Uint8List? fontBytes;

    if (await fontFile.exists()) {
      try {
        fontBytes = await fontFile.readAsBytes();
      } catch (_) {}
    }

    if (fontBytes == null) {
      final urls = [
        '$_rawBase/fonts/$fileName',
        '$_cdnBase/fonts/$fileName',
      ];

      for (final url in urls) {
        try {
          final res = await _dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {"User-Agent": "QuranEasyMalayalam/1.0"},
            ),
          );
          if (res.data != null && res.statusCode == 200) {
            fontBytes = Uint8List.fromList(res.data!);
            await fontFile.writeAsBytes(fontBytes);
            break;
          }
        } catch (_) {}
      }
    }

    if (fontBytes == null) {
      return;
    }

    try {
      final fontLoader = FontLoader(fontName);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
    } catch (_) {}
  }

  void preloadNeighborPages(int currentPage) {
    for (int delta = -1; delta <= 3; delta++) {
      if (delta == 0) continue;
      final p = currentPage + delta;
      if (p >= 1 && p <= 604) {
        fetchPageData(p).then((_) {}, onError: (_) {});
      }
    }
  }

  bool isFontLoaded(String fontName) => _loadedFonts.contains(fontName);

  Future<bool> hasPageData(int page) async {
    final padded = page.toString().padLeft(3, '0');
    final pagesDir = await _getPagesDir();
    final localFile = File('${pagesDir.path}/$padded.json');
    return localFile.exists();
  }
}
