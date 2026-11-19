import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

@immutable
class QvpWordData {
  final int index;
  final int surah;
  final int ayah;
  final int word; // 1-based index within the ayah
  final int lineIndex;
  final int ayahIndex;
  final int firstPath;
  final int nPaths;
  final String text;
  final List<double> box; // [x0, y0, x1, y1] in page coordinates

  const QvpWordData({
    required this.index,
    required this.surah,
    required this.ayah,
    required this.word,
    required this.lineIndex,
    required this.ayahIndex,
    required this.firstPath,
    required this.nPaths,
    required this.text,
    required this.box,
  });

  String get verseKey => '$surah:$ayah';
  double get x0 => box[0];
  double get y0 => box[1];
  double get x1 => box[2];
  double get y1 => box[3];
  double get width => x1 - x0;
  double get height => y1 - y0;
  double get centerX => (x0 + x1) / 2.0;
  double get centerY => (y0 + y1) / 2.0;

  bool contains(double px, double py) {
    return px >= x0 && px <= x1 && py >= y0 && py <= y1;
  }
}

@immutable
class QvpLineData {
  final int index;
  final int lineNumber;
  final int firstWord;
  final int nWords;

  const QvpLineData(this.index, this.lineNumber, this.firstWord, this.nWords);
}

@immutable
class QvpAyahData {
  final int index;
  final int surah;
  final int ayah;
  final int fragment;
  final int fragments;
  final int flags;
  final int firstWord;
  final int nWords;
  final int ayahMarkDecoration;
  final int rubuAlHizb;

  const QvpAyahData(
    this.index,
    this.surah,
    this.ayah,
    this.fragment,
    this.fragments,
    this.flags,
    this.firstWord,
    this.nWords,
    this.ayahMarkDecoration,
    this.rubuAlHizb,
  );

  String get verseKey => '$surah:$ayah';
}

@immutable
class QvpPathData {
  final Uint8List ops;
  final Float32List pts;
  final List<double> box;
  final int kind;
  final int mark;
  final int family;
  final String rule; // 'evenodd' or 'nonzero'

  const QvpPathData({
    required this.ops,
    required this.pts,
    required this.box,
    required this.kind,
    required this.mark,
    required this.family,
    required this.rule,
  });
}

@immutable
class QvpDecorationData {
  final int index;
  final int firstPath;
  final int nPaths;
  final int decoration;
  final int surah;
  final int ayah;
  final int lineIndex;
  final String text;
  final List<double>? box;

  const QvpDecorationData({
    required this.index,
    required this.firstPath,
    required this.nPaths,
    required this.decoration,
    required this.surah,
    required this.ayah,
    required this.lineIndex,
    required this.text,
    required this.box,
  });

  String get verseKey => '$surah:$ayah';
}

class QvpDecodedPage {
  final int pageNumber;
  final double width;
  final double height;
  final List<QvpLineData> lines;
  final List<QvpAyahData> ayahs;
  final List<QvpWordData> words;
  final List<QvpDecorationData> decorations;
  final List<QvpPathData> paths;

  List<ui.Path>? _cachedUiPaths;
  Set<int>? _decorationPathIndices;
  double? _inkCenterX;

  /// Center X of actual text ink bounding box, used for perfect optical centering
  double get inkCenterX {
    if (_inkCenterX != null) return _inkCenterX!;
    if (paths.isEmpty) return width / 2.0;
    double minX = double.infinity;
    double maxX = -double.infinity;
    for (final p in paths) {
      if (p.box[0] < minX) minX = p.box[0];
      if (p.box[2] > maxX) maxX = p.box[2];
    }
    _inkCenterX = (minX.isFinite && maxX.isFinite) ? (minX + maxX) / 2.0 : width / 2.0;
    return _inkCenterX!;
  }

  QvpDecodedPage({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.lines,
    required this.ayahs,
    required this.words,
    required this.decorations,
    required this.paths,
  });

  /// Build or return cached [ui.Path] objects for all vector paths
  List<ui.Path> getUiPaths() {
    if (_cachedUiPaths != null) return _cachedUiPaths!;

    final list = List<ui.Path>.generate(paths.length, (i) {
      final p = paths[i];
      final path = ui.Path();
      path.fillType =
          p.rule == 'evenodd' ? ui.PathFillType.evenOdd : ui.PathFillType.nonZero;
      var k = 0;
      for (final op in p.ops) {
        switch (op) {
          case 0:
            path.moveTo(p.pts[k], p.pts[k + 1]);
            k += 2;
            break;
          case 1:
            path.lineTo(p.pts[k], p.pts[k + 1]);
            k += 2;
            break;
          case 2:
            path.quadraticBezierTo(
                p.pts[k], p.pts[k + 1], p.pts[k + 2], p.pts[k + 3]);
            k += 4;
            break;
          case 3:
            path.cubicTo(p.pts[k], p.pts[k + 1], p.pts[k + 2], p.pts[k + 3],
                p.pts[k + 4], p.pts[k + 5]);
            k += 6;
            break;
          case 4:
            path.close();
            break;
        }
      }
      return path;
    }, growable: false);

    _cachedUiPaths = list;
    return list;
  }

  Set<int> get decorationPathIndices {
    if (_decorationPathIndices != null) return _decorationPathIndices!;
    final set = <int>{};
    for (final dec in decorations) {
      for (var i = dec.firstPath; i < dec.firstPath + dec.nPaths; i++) {
        set.add(i);
      }
    }
    _decorationPathIndices = set;
    return set;
  }

  /// Gap-aware hit test: returns the word at or near page coordinates (px, py)
  /// Hit test word with line-aware box-proximity detection.
  /// Accurately matches direct taps, padded touches, and taps in whitespace between words,
  /// while heavily penalizing vertical deviations to prevent mistouching across adjacent lines.
  QvpWordData? hitTestWord(double px, double py, {double maxDistance = 24.0}) {
    if (words.isEmpty) return null;

    // 1. Direct hit inside padded word bounding box (instant match)
    QvpWordData? directMatch;
    double bestDirectArea = double.infinity;
    for (final word in words) {
      if (px >= word.x0 - 1.5 &&
          px <= word.x1 + 1.5 &&
          py >= word.y0 - 3.5 &&
          py <= word.y1 + 3.5) {
        final area = word.width * word.height;
        if (area < bestDirectArea) {
          bestDirectArea = area;
          directMatch = word;
        }
      }
    }
    if (directMatch != null) return directMatch;

    // 2. Proximity hit test using distance to box boundary with line-affinity weighting
    QvpWordData? closest;
    double minScore = maxDistance * maxDistance;

    for (final word in words) {
      final double dx = px < word.x0
          ? (word.x0 - px)
          : (px > word.x1 ? (px - word.x1) : 0.0);

      final double dy = py < word.y0
          ? (word.y0 - py)
          : (py > word.y1 ? (py - word.y1) : 0.0);

      // Heavy 3.5x vertical penalty ensures horizontal line affinity and prevents mistouching across adjacent lines
      final double dyWeighted = dy * 3.5;
      final double score = dx * dx + dyWeighted * dyWeighted;

      if (score < minScore) {
        minScore = score;
        closest = word;
      }
    }

    return closest;
  }

  /// Fluid continuous hit testing for drag gestures across lines and pages.
  /// Snaps smoothly to the nearest word on the active line without dead zones
  /// or dropouts between adjacent words or lines.
  QvpWordData? hitTestWordForDrag(double px, double py) {
    if (words.isEmpty) return null;

    // 1. Direct hit inside padded word bounding box
    for (final word in words) {
      if (px >= word.x0 - 2.0 &&
          px <= word.x1 + 2.0 &&
          py >= word.y0 - 4.0 &&
          py <= word.y1 + 4.0) {
        return word;
      }
    }

    // 2. Group words by lineIndex and find line vertical bounds
    final lineMap = <int, List<QvpWordData>>{};
    final lineBounds = <int, ({double minY, double maxY})>{};

    for (final word in words) {
      lineMap.putIfAbsent(word.lineIndex, () => []).add(word);
      final existing = lineBounds[word.lineIndex];
      if (existing == null) {
        lineBounds[word.lineIndex] = (minY: word.y0, maxY: word.y1);
      } else {
        lineBounds[word.lineIndex] = (
          minY: math.min(existing.minY, word.y0),
          maxY: math.max(existing.maxY, word.y1),
        );
      }
    }

    if (lineMap.isEmpty) return null;

    // Find the vertically nearest line to py
    int? bestLine;
    double minLineDist = double.infinity;

    for (final entry in lineBounds.entries) {
      final bounds = entry.value;
      double dy = 0.0;
      if (py < bounds.minY) {
        dy = bounds.minY - py;
      } else if (py > bounds.maxY) {
        dy = py - bounds.maxY;
      }
      if (dy < minLineDist) {
        minLineDist = dy;
        bestLine = entry.key;
      }
    }

    // If py is far outside the text block, do not snap
    if (bestLine == null || minLineDist > 45.0) {
      return null;
    }

    final lineWords = lineMap[bestLine]!;

    // Find the horizontally nearest word on that line to px
    QvpWordData? bestWord;
    double minDx = double.infinity;

    for (final word in lineWords) {
      double dx = 0.0;
      if (px < word.x0) {
        dx = word.x0 - px;
      } else if (px > word.x1) {
        dx = px - word.x1;
      }
      if (dx < minDx) {
        minDx = dx;
        bestWord = word;
      }
    }

    return bestWord;
  }

  /// Hit test decoration (e.g. ayah end rosette)
  QvpDecorationData? hitTestDecoration(double px, double py) {
    for (final dec in decorations) {
      if (dec.box != null) {
        if (px >= dec.box![0] - 3 &&
            px <= dec.box![2] + 3 &&
            py >= dec.box![1] - 3 &&
            py <= dec.box![3] + 3) {
          return dec;
        }
      }
    }
    return null;
  }
}

class _QvpSectionReader {
  final Uint8List bytes;
  final ByteData data;
  final int start;
  final int end;
  int position;

  _QvpSectionReader(this.bytes, this.data, this.start, this.end)
      : position = start;

  int byte() {
    if (position >= end) throw Exception('Truncated QVP section');
    return bytes[position++];
  }

  int varint() {
    int value = 0;
    for (int shift = 0; shift < 35; shift += 7) {
      final b = byte();
      if (shift == 28 && b > 15) throw Exception('Invalid QVP varint');
      value += (b & 127) * (1 << shift);
      if (b < 128) return value;
    }
    throw Exception('Invalid QVP varint');
  }

  int zigzag() {
    final value = varint();
    return (value >>> 1) ^ -(value & 1);
  }

  double float() {
    if (position + 4 > end) throw Exception('Truncated QVP float');
    final value = data.getFloat32(position, Endian.little);
    position += 4;
    return value;
  }
}

class _WordRecord {
  final int textIndex;
  final int index;
  final int surah;
  final int ayah;
  final int word;
  final int lineIndex;
  final int ayahIndex;
  final int firstPathDelta;
  final int nPaths;

  _WordRecord({
    required this.textIndex,
    required this.index,
    required this.surah,
    required this.ayah,
    required this.word,
    required this.lineIndex,
    required this.ayahIndex,
    required this.firstPathDelta,
    required this.nPaths,
  });
}

class _DecorationRecord {
  final int index;
  final int firstPath;
  final int nPaths;
  final int decoration;
  final int surah;
  final int ayah;
  final int textIndex;
  final int lineIndex;

  _DecorationRecord({
    required this.index,
    required this.firstPath,
    required this.nPaths,
    required this.decoration,
    required this.surah,
    required this.ayah,
    required this.textIndex,
    required this.lineIndex,
  });
}

class _ShapeData {
  final Uint8List ops;
  final Float64List pts;
  _ShapeData(this.ops, this.pts);
}

class QvpDecoder {
  static const int limitFileBytes = 2 * 1024 * 1024;

  static QvpDecodedPage decode(Uint8List bytes) {
    if (bytes.length < 64) throw Exception('Truncated QVP header');
    if (bytes.length > limitFileBytes) throw Exception('QVP page exceeds maximum size');

    final data = ByteData.sublistView(bytes);

    final magic = data.getUint32(0, Endian.little);
    final version = data.getUint16(4, Endian.little);
    if (magic != 0x31505651 || version != 1) {
      throw Exception('Expected a QVP1 page (magic: 0x${magic.toRadixString(16)}, version: $version)');
    }

    final quant = data.getUint16(6, Endian.little);
    final number = data.getUint16(8, Endian.little);
    final width = data.getFloat32(12, Endian.little);
    final height = data.getFloat32(16, Endian.little);
    final nLines = data.getUint16(20, Endian.little);
    final nAyahs = data.getUint16(22, Endian.little);
    final nWords = data.getUint16(24, Endian.little);
    final nDecorations = data.getUint16(26, Endian.little);
    final nPaths = data.getUint32(28, Endian.little);
    final nStrings = data.getUint16(32, Endian.little);
    final nGlyphs = data.getUint16(34, Endian.little);
    final nInstances = data.getUint16(36, Endian.little);

    int sectionOffset = 64;
    final sectionStarts = <int>[];
    final sectionEnds = <int>[];
    for (int i = 0; i < 6; i++) {
      final start = sectionOffset;
      sectionOffset += data.getUint32(40 + i * 4, Endian.little);
      if (sectionOffset > bytes.length) throw Exception('Invalid QVP section length');
      sectionStarts.add(start);
      sectionEnds.add(sectionOffset);
    }
    if (sectionOffset != bytes.length) throw Exception('Invalid QVP length');

    _QvpSectionReader getReader(int sectionIndex) =>
        _QvpSectionReader(bytes, data, sectionStarts[sectionIndex], sectionEnds[sectionIndex]);

    final metadata = getReader(0);
    int firstWord = 0;
    final lines = List<QvpLineData>.generate(nLines, (index) {
      final lineNumber = metadata.byte();
      final numWords = metadata.varint();
      final line = QvpLineData(index, lineNumber, firstWord, numWords);
      firstWord += numWords;
      return line;
    });

    firstWord = 0;
    int ayahSurah = 0;
    int ayahNumber = 0;
    final ayahs = List<QvpAyahData>.generate(nAyahs, (index) {
      ayahSurah += metadata.zigzag();
      ayahNumber += metadata.zigzag();
      final fragment = metadata.byte();
      final fragments = metadata.byte();
      final flags = metadata.byte();
      final numWords = metadata.varint();
      final ayahMarkDecoration = metadata.varint() - 1;
      final rubuAlHizb = metadata.varint();
      final ayah = QvpAyahData(index, ayahSurah, ayahNumber, fragment, fragments,
          flags, firstWord, numWords, ayahMarkDecoration, rubuAlHizb);
      firstWord += numWords;
      return ayah;
    });

    int surah = 0;
    int ayah = 0;
    int word = 0;
    int lineIndex = 0;
    int ayahIndex = 0;

    final wordRecords = List<_WordRecord>.generate(nWords, (index) {
      final firstPathDelta = metadata.zigzag();
      surah += metadata.zigzag();
      ayah += metadata.zigzag();
      word += metadata.zigzag();
      lineIndex += metadata.zigzag();
      ayahIndex += metadata.zigzag();
      final textIndex = metadata.varint() - 1;
      for (int i = 0; i < 4; i++) {
        metadata.varint();
      }
      return _WordRecord(
        textIndex: textIndex,
        index: index,
        surah: surah,
        ayah: ayah,
        word: word,
        lineIndex: lineIndex,
        ayahIndex: ayahIndex,
        firstPathDelta: firstPathDelta,
        nPaths: metadata.varint(),
      );
    });

    final columns = List.generate(4, (_) => Uint8List(nPaths));
    for (int col = 0; col < 4; col++) {
      for (int i = 0; i < nPaths; i++) {
        columns[col][i] = metadata.byte();
      }
    }

    final counts = Uint32List(nPaths);
    for (int i = 0; i < nPaths; i++) {
      counts[i] = metadata.varint();
    }

    int nInstancePaths = 0;
    for (int i = 0; i < nPaths; i++) {
      if ((columns[3][i] & 16) != 0) nInstancePaths++;
    }

    final instanceBoxes = List<List<double>>.generate(nInstancePaths, (_) {
      final x0 = metadata.zigzag();
      final y0 = metadata.zigzag();
      final x1 = x0 + metadata.zigzag();
      final y1 = y0 + metadata.zigzag();
      return [x0 / quant, y0 / quant, x1 / quant, y1 / quant];
    });

    int decorationEnd = 0;
    int decorationSurah = 0;

    final decorationRecords = List<_DecorationRecord>.generate(nDecorations, (index) {
      final firstPath = decorationEnd + metadata.zigzag();
      final decType = metadata.byte();
      decorationSurah += metadata.zigzag();
      final a = metadata.varint();
      final textIndex = metadata.varint() - 1;
      final numPaths = metadata.varint();
      final lIndex = metadata.varint() - 1;
      decorationEnd = firstPath + numPaths;
      return _DecorationRecord(
        index: index,
        firstPath: firstPath,
        nPaths: numPaths,
        decoration: decType,
        surah: decorationSurah,
        ayah: a,
        textIndex: textIndex,
        lineIndex: lIndex,
      );
    });

    final glyphCounts = List<int>.generate(nGlyphs, (_) {
      final count = metadata.varint();
      for (int i = 0; i < 4; i++) {
        metadata.zigzag();
      }
      return count;
    });

    final instances = List<List<double>>.generate(nInstances, (_) {
      final b0 = metadata.byte();
      final b1 = metadata.byte();
      final glyphIndex = (b0 | (b1 << 8)).toDouble();
      final a = metadata.float();
      final b = metadata.float();
      final c = metadata.float();
      final d = metadata.float();
      final e = metadata.float();
      final f = metadata.float();
      return [glyphIndex, a, b, c, d, e, f];
    });

    if (metadata.position != sectionEnds[0]) {
      throw Exception('Invalid QVP metadata position (${metadata.position} != ${sectionEnds[0]})');
    }

    final wireCounts = <int>[];
    for (int i = 0; i < nPaths; i++) {
      if ((columns[3][i] & 16) == 0) {
        wireCounts.add(counts[i]);
      }
    }
    wireCounts.addAll(glyphCounts);

    final closeReader = getReader(2);
    int closePosition = 0;
    final nCloses = closeReader.varint();
    final closePositions = List<int>.generate(nCloses, (_) {
      closePosition += closeReader.varint();
      return closePosition;
    });

    final xReader = getReader(3);
    final yReader = getReader(4);
    int previousX = 0;
    int previousY = 0;
    int operationIndex = 0;
    int closeIndex = 0;

    final shapes = wireCounts.map((count) {
      final opList = <int>[];
      final ptList = <double>[];
      const ptsPerOp = [1, 1, 2, 3];
      for (int i = 0; i < count; i++) {
        final byteVal = bytes[sectionStarts[1] + (operationIndex >> 2)];
        final operation = (byteVal >> ((operationIndex % 4) * 2)) & 3;
        opList.add(operation);
        final numPts = ptsPerOp[operation];
        for (int p = 0; p < numPts; p++) {
          previousX += xReader.zigzag();
          previousY += yReader.zigzag();
          ptList.add(previousX.toDouble());
          ptList.add(previousY.toDouble());
        }
        operationIndex++;
        while (closeIndex < closePositions.length && closePositions[closeIndex] == operationIndex) {
          opList.add(4); // close
          closeIndex++;
        }
      }
      if (opList.isNotEmpty && opList[0] == 0 && ptList.length >= 2) {
        previousX = ptList[0].round();
        previousY = ptList[1].round();
      }
      return _ShapeData(Uint8List.fromList(opList), Float64List.fromList(ptList));
    }).toList();

    final strings = getReader(5);
    final texts = List<String>.generate(nStrings, (_) {
      final length = strings.varint();
      final strBytes = bytes.sublist(strings.position, strings.position + length);
      strings.position += length;
      return utf8.decode(strBytes);
    });

    int directShape = 0;
    int instanceBox = 0;
    final paths = List<QvpPathData>.generate(nPaths, (i) {
      final isInstance = (columns[3][i] & 16) != 0;
      final transform = isInstance ? instances[counts[i]] : null;
      final _ShapeData shape;
      if (isInstance) {
        final glyphIdx = transform![0].toInt();
        shape = shapes[shapes.length - nGlyphs + glyphIdx];
      } else {
        shape = shapes[directShape++];
      }

      final pts = Float32List(shape.pts.length);
      final List<double> box;
      if (isInstance) {
        box = List<double>.from(instanceBoxes[instanceBox++]);
      } else {
        box = [double.infinity, double.infinity, -double.infinity, -double.infinity];
      }

      for (int p = 0; p < pts.length; p += 2) {
        final x = shape.pts[p] / quant;
        final y = shape.pts[p + 1] / quant;
        double outputX = x;
        double outputY = y;
        if (isInstance) {
          final a = transform![1];
          final b = transform[2];
          final c = transform[3];
          final d = transform[4];
          final e = transform[5];
          final f = transform[6];
          outputX = a * x + c * y + e;
          outputY = b * x + d * y + f;
        }
        pts[p] = outputX;
        pts[p + 1] = outputY;
        if (!isInstance) {
          if (outputX < box[0]) box[0] = outputX;
          if (outputY < box[1]) box[1] = outputY;
          if (outputX > box[2]) box[2] = outputX;
          if (outputY > box[3]) box[3] = outputY;
        }
      }

      return QvpPathData(
        ops: shape.ops,
        pts: pts,
        box: box,
        kind: columns[0][i],
        mark: columns[1][i],
        family: columns[2][i],
        rule: (columns[3][i] & 1) != 0 ? 'evenodd' : 'nonzero',
      );
    });

    int previousWordEnd = 0;
    final words = wordRecords.map((record) {
      final firstPath = previousWordEnd + record.firstPathDelta;
      final endPath = firstPath + record.nPaths;
      final box = [double.infinity, double.infinity, -double.infinity, -double.infinity];
      for (int path = firstPath; path < endPath; path++) {
        final pBox = paths[path].box;
        if (pBox[0] < box[0]) box[0] = pBox[0];
        if (pBox[1] < box[1]) box[1] = pBox[1];
        if (pBox[2] > box[2]) box[2] = pBox[2];
        if (pBox[3] > box[3]) box[3] = pBox[3];
      }
      previousWordEnd = endPath;
      final txt = (record.textIndex >= 0 && record.textIndex < texts.length)
          ? texts[record.textIndex]
          : '';
      return QvpWordData(
        index: record.index,
        surah: record.surah,
        ayah: record.ayah,
        word: record.word,
        lineIndex: record.lineIndex,
        ayahIndex: record.ayahIndex,
        firstPath: firstPath,
        nPaths: record.nPaths,
        text: txt,
        box: box,
      );
    }).toList();

    List<double>? bounds(List<QvpPathData> pathSlice) {
      if (pathSlice.isEmpty) return null;
      final box = [double.infinity, double.infinity, -double.infinity, -double.infinity];
      for (final p in pathSlice) {
        if (p.box[0] < box[0]) box[0] = p.box[0];
        if (p.box[1] < box[1]) box[1] = p.box[1];
        if (p.box[2] > box[2]) box[2] = p.box[2];
        if (p.box[3] > box[3]) box[3] = p.box[3];
      }
      return box;
    }

    final decorations = decorationRecords.map((record) {
      final slice = paths.sublist(record.firstPath, record.firstPath + record.nPaths);
      final box = bounds(slice);
      final txt = (record.textIndex >= 0 && record.textIndex < texts.length)
          ? texts[record.textIndex]
          : '';
      return QvpDecorationData(
        index: record.index,
        firstPath: record.firstPath,
        nPaths: record.nPaths,
        decoration: record.decoration,
        surah: record.surah,
        ayah: record.ayah,
        lineIndex: record.lineIndex,
        text: txt,
        box: box,
      );
    }).toList();

    return QvpDecodedPage(
      pageNumber: number,
      width: width,
      height: height,
      lines: lines,
      ayahs: ayahs,
      words: words,
      decorations: decorations,
      paths: paths,
    );
  }
}
