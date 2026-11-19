/// Authentic Quran Manuscript Dressing Catalog
/// Extracted from https://github.com/quran-ws/quran-assets.git
class MushafDressItem {
  final String id;
  final String title;
  final String riwayah;
  final String description;
  final bool isDefault;

  const MushafDressItem({
    required this.id,
    required this.title,
    required this.riwayah,
    required this.description,
    this.isDefault = false,
  });
}

class FrameMeta {
  final String id;
  final String name;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double slotX;
  final double slotY;
  final double slotWidth;
  final double slotHeight;

  const FrameMeta({
    required this.id,
    required this.name,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.slotX,
    required this.slotY,
    required this.slotWidth,
    required this.slotHeight,
  });

  double get aspectRatio => viewBoxWidth / viewBoxHeight;
  double get slotInsetLeftRatio => slotX / viewBoxWidth;
  double get slotInsetRightRatio => (viewBoxWidth - slotX - slotWidth) / viewBoxWidth;
  double get slotInsetTopRatio => slotY / viewBoxHeight;
  double get slotInsetBottomRatio => (viewBoxHeight - slotY - slotHeight) / viewBoxHeight;
}

class SurahHeaderMeta {
  final String id;
  final String name;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double slotX;
  final double slotY;
  final double slotWidth;
  final double slotHeight;

  const SurahHeaderMeta({
    required this.id,
    required this.name,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.slotX,
    required this.slotY,
    required this.slotWidth,
    required this.slotHeight,
  });

  double get slotCenterX => slotX + slotWidth / 2.0;
  double get slotCenterY => slotY + slotHeight / 2.0;
}

class AyahMarkerMeta {
  final String id;
  final String name;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double slotX;
  final double slotY;
  final double slotWidth;
  final double slotHeight;
  final double scaleMultiplier;

  const AyahMarkerMeta({
    required this.id,
    required this.name,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.slotX,
    required this.slotY,
    required this.slotWidth,
    required this.slotHeight,
    this.scaleMultiplier = 1.28,
  });

  double get slotCenterX => slotX + slotWidth / 2.0;
  double get slotCenterY => slotY + slotHeight / 2.0;
}

class QuranDressingCatalog {
  /// The 8 authentic manuscript editions available in quran-assets
  static const List<MushafDressItem> mushafStyles = [
    MushafDressItem(
      id: 'mushaf-hafs-adi',
      title: 'Hafs al-Adi (Standard Madani)',
      riwayah: "Hafs 'an 'Asim (al-'Adi)",
      description: 'King Fahd Complex standard Madani manuscript illumination (Classic Default)',
      isDefault: true,
    ),
    MushafDressItem(
      id: 'mushaf-hafs-madinah-kabir',
      title: 'Hafs Madinah Kabir',
      riwayah: "Hafs 'an 'Asim (Madinah, large)",
      description: 'Ornate large format King Fahd Complex edition with opulent floral borders',
    ),
    MushafDressItem(
      id: 'mushaf-hafs-madinah-mumtaza',
      title: 'Hafs Madinah Mumtaza',
      riwayah: "Hafs 'an 'Asim (Madinah, mumtaza)",
      description: 'Deluxe historical illumination with intricate arabesque cornerpieces',
    ),
    MushafDressItem(
      id: 'mushaf-warsh',
      title: "Warsh 'an Nafi'",
      riwayah: "Warsh 'an Nafi' (North African)",
      description: 'North African Maghribi manuscript tradition with geometric and floral rosettes',
    ),
    MushafDressItem(
      id: 'mushaf-qalon',
      title: "Qalun 'an Nafi'",
      riwayah: "Qalun 'an Nafi'",
      description: 'Libyan and Tunisian manuscript style with distinctive emerald and gold motifs',
    ),
    MushafDressItem(
      id: 'mushaf-douri',
      title: "Al-Duri 'an Abi 'Amr",
      riwayah: "al-Duri 'an Abi 'Amr (Sudan / Levant)",
      description: 'Eastern African and Sudanese manuscript ornament with warm earth tones',
    ),
    MushafDressItem(
      id: 'mushaf-sousi',
      title: "Al-Susi 'an Abi 'Amr",
      riwayah: "al-Susi 'an Abi 'Amr",
      description: 'Classical Levantine ornamentation with refined geometric border bands',
    ),
    MushafDressItem(
      id: 'mushaf-shubah',
      title: "Shu'bah 'an 'Asim",
      riwayah: "Shu'bah 'an 'Asim (Kufan)",
      description: 'Traditional Kufan illumination with elegant gold medallions and cartouches',
    ),
  ];

  static const Map<String, FrameMeta> frames = {
    'mushaf-hafs-adi': FrameMeta(
      id: 'mushaf-hafs-adi',
      name: "Hafs 'an 'Asim (al-'Adi)",
      viewBoxWidth: 64.419,
      viewBoxHeight: 100.0,
      slotX: 4.2763,
      slotY: 5.0439,
      slotWidth: 55.8662,
      slotHeight: 89.9671,
    ),
    'mushaf-hafs-madinah-kabir': FrameMeta(
      id: 'mushaf-hafs-madinah-kabir',
      name: "Hafs 'an 'Asim (Madinah, large)",
      viewBoxWidth: 63.79,
      viewBoxHeight: 100.0,
      slotX: 4.4504,
      slotY: 5.8665,
      slotWidth: 54.8887,
      slotHeight: 88.5367,
    ),
    'mushaf-hafs-madinah-mumtaza': FrameMeta(
      id: 'mushaf-hafs-madinah-mumtaza',
      name: "Hafs 'an 'Asim (Madinah, mumtaza)",
      viewBoxWidth: 69.084,
      viewBoxHeight: 100.0,
      slotX: 9.3382,
      slotY: 9.3382,
      slotWidth: 50.408,
      slotHeight: 81.233,
    ),
    'mushaf-warsh': FrameMeta(
      id: 'mushaf-warsh',
      name: "Warsh 'an Nafi'",
      viewBoxWidth: 68.317,
      viewBoxHeight: 100.0,
      slotX: 5.4455,
      slotY: 5.3355,
      slotWidth: 57.4257,
      slotHeight: 89.3289,
    ),
    'mushaf-qalon': FrameMeta(
      id: 'mushaf-qalon',
      name: "Qalun 'an Nafi'",
      viewBoxWidth: 68.317,
      viewBoxHeight: 100.0,
      slotX: 5.4455,
      slotY: 5.3355,
      slotWidth: 57.4257,
      slotHeight: 89.3289,
    ),
    'mushaf-douri': FrameMeta(
      id: 'mushaf-douri',
      name: "al-Duri 'an Abi 'Amr",
      viewBoxWidth: 65.591,
      viewBoxHeight: 100.0,
      slotX: 4.9234,
      slotY: 5.1422,
      slotWidth: 55.744,
      slotHeight: 89.7702,
    ),
    'mushaf-sousi': FrameMeta(
      id: 'mushaf-sousi',
      name: "al-Susi 'an Abi 'Amr",
      viewBoxWidth: 66.52,
      viewBoxHeight: 100.0,
      slotX: 5.2689,
      slotY: 5.3787,
      slotWidth: 55.9824,
      slotHeight: 89.2975,
    ),
    'mushaf-shubah': FrameMeta(
      id: 'mushaf-shubah',
      name: "Shu'bah 'an 'Asim",
      viewBoxWidth: 65.7,
      viewBoxHeight: 100.0,
      slotX: 4.9781,
      slotY: 4.9781,
      slotWidth: 55.744,
      slotHeight: 90.0438,
    ),
  };

  static const Map<String, SurahHeaderMeta> surahHeaders = {
    'mushaf-hafs-adi': SurahHeaderMeta(
      id: 'mushaf-hafs-adi',
      name: "Hafs 'an 'Asim (al-'Adi)",
      viewBoxWidth: 872.674,
      viewBoxHeight: 100.0,
      slotX: 239.8256,
      slotY: 9.593,
      slotWidth: 393.314,
      slotHeight: 81.1047,
    ),
    'mushaf-hafs-madinah-kabir': SurahHeaderMeta(
      id: 'mushaf-hafs-madinah-kabir',
      name: "Hafs 'an 'Asim (Madinah, large)",
      viewBoxWidth: 811.409,
      viewBoxHeight: 100.0,
      slotX: 234.5638,
      slotY: 13.0872,
      slotWidth: 342.2819,
      slotHeight: 74.4966,
    ),
    'mushaf-hafs-madinah-mumtaza': SurahHeaderMeta(
      id: 'mushaf-hafs-madinah-mumtaza',
      name: "Hafs 'an 'Asim (Madinah, mumtaza)",
      viewBoxWidth: 854.688,
      viewBoxHeight: 100.0,
      slotX: 256.25,
      slotY: 7.8125,
      slotWidth: 342.1875,
      slotHeight: 83.5938,
    ),
    'mushaf-warsh': SurahHeaderMeta(
      id: 'mushaf-warsh',
      name: "Warsh 'an Nafi'",
      viewBoxWidth: 863.429,
      viewBoxHeight: 100.0,
      slotX: 180.8571,
      slotY: 8.5714,
      slotWidth: 501.4286,
      slotHeight: 83.1429,
    ),
    'mushaf-qalon': SurahHeaderMeta(
      id: 'mushaf-qalon',
      name: "Qalun 'an Nafi'",
      viewBoxWidth: 863.429,
      viewBoxHeight: 100.0,
      slotX: 180.8571,
      slotY: 8.5714,
      slotWidth: 501.4286,
      slotHeight: 83.1429,
    ),
    'mushaf-douri': SurahHeaderMeta(
      id: 'mushaf-douri',
      name: "al-Duri 'an Abi 'Amr",
      viewBoxWidth: 857.714,
      viewBoxHeight: 100.0,
      slotX: 235.7143,
      slotY: 10.2857,
      slotWidth: 386.5714,
      slotHeight: 79.7143,
    ),
    'mushaf-sousi': SurahHeaderMeta(
      id: 'mushaf-sousi',
      name: "al-Susi 'an Abi 'Amr",
      viewBoxWidth: 782.54,
      viewBoxHeight: 100.0,
      slotX: 226.1905,
      slotY: 9.5238,
      slotWidth: 330.9524,
      slotHeight: 80.9524,
    ),
    'mushaf-shubah': SurahHeaderMeta(
      id: 'mushaf-shubah',
      name: "Shu'bah 'an 'Asim",
      viewBoxWidth: 872.674,
      viewBoxHeight: 100.0,
      slotX: 239.8256,
      slotY: 8.7209,
      slotWidth: 393.314,
      slotHeight: 82.8488,
    ),
  };

  static const Map<String, AyahMarkerMeta> ayahMarkers = {
    'mushaf-hafs-adi': AyahMarkerMeta(
      id: 'mushaf-hafs-adi',
      name: "Hafs 'an 'Asim (al-'Adi)",
      viewBoxWidth: 76.14,
      viewBoxHeight: 100.0,
      slotX: 13.6842,
      slotY: 33.6842,
      slotWidth: 49.4737,
      slotHeight: 32.6316,
    ),
    'mushaf-hafs-madinah-kabir': AyahMarkerMeta(
      id: 'mushaf-hafs-madinah-kabir',
      name: "Hafs 'an 'Asim (Madinah, large)",
      viewBoxWidth: 76.754,
      viewBoxHeight: 100.0,
      slotX: 13.1579,
      slotY: 34.2105,
      slotWidth: 50.0,
      slotHeight: 31.5789,
    ),
    'mushaf-hafs-madinah-mumtaza': AyahMarkerMeta(
      id: 'mushaf-hafs-madinah-mumtaza',
      name: "Hafs 'an 'Asim (Madinah, mumtaza)",
      viewBoxWidth: 76.699,
      viewBoxHeight: 100.0,
      slotX: 12.6214,
      slotY: 33.0097,
      slotWidth: 50.4854,
      slotHeight: 33.9806,
    ),
    'mushaf-warsh': AyahMarkerMeta(
      id: 'mushaf-warsh',
      name: "Warsh 'an Nafi'",
      viewBoxWidth: 72.043,
      viewBoxHeight: 100.0,
      slotX: 12.9032,
      slotY: 22.5806,
      slotWidth: 46.2366,
      slotHeight: 54.8387,
    ),
    'mushaf-qalon': AyahMarkerMeta(
      id: 'mushaf-qalon',
      name: "Qalun 'an Nafi'",
      viewBoxWidth: 73.162,
      viewBoxHeight: 100.0,
      slotX: 13.2353,
      slotY: 23.1618,
      slotWidth: 46.3235,
      slotHeight: 54.0441,
    ),
    'mushaf-douri': AyahMarkerMeta(
      id: 'mushaf-douri',
      name: "al-Duri 'an Abi 'Amr",
      viewBoxWidth: 77.143,
      viewBoxHeight: 100.0,
      slotX: 13.9286,
      slotY: 34.2857,
      slotWidth: 49.2857,
      slotHeight: 32.1429,
    ),
    'mushaf-sousi': AyahMarkerMeta(
      id: 'mushaf-sousi',
      name: "al-Susi 'an Abi 'Amr",
      viewBoxWidth: 77.113,
      viewBoxHeight: 100.0,
      slotX: 13.7324,
      slotY: 32.7465,
      slotWidth: 49.6479,
      slotHeight: 34.8592,
    ),
    'mushaf-shubah': AyahMarkerMeta(
      id: 'mushaf-shubah',
      name: "Shu'bah 'an 'Asim",
      viewBoxWidth: 76.409,
      viewBoxHeight: 100.0,
      slotX: 13.7324,
      slotY: 33.8028,
      slotWidth: 49.6479,
      slotHeight: 32.7465,
    ),
  };

  /// Normalizes legacy or shorthand style IDs to official quran-assets style IDs.
  static String normalizeFrameId(String id) {
    if (id == 'madani') return 'mushaf-hafs-adi';
    return id;
  }

  static String normalizeHeaderId(String id) {
    if (id == 'madani') return 'mushaf-hafs-adi';
    return id;
  }

  static String normalizeAyahId(String id) {
    if (id == 'hafs-adi') return 'mushaf-hafs-adi';
    return id;
  }

  static FrameMeta getFrameMeta(String styleId) {
    final norm = normalizeFrameId(styleId);
    return frames[norm] ?? frames['mushaf-hafs-adi']!;
  }

  static SurahHeaderMeta getSurahHeaderMeta(String styleId) {
    final norm = normalizeHeaderId(styleId);
    return surahHeaders[norm] ?? surahHeaders['mushaf-hafs-adi']!;
  }

  static AyahMarkerMeta getAyahMarkerMeta(String styleId) {
    final norm = normalizeAyahId(styleId);
    return ayahMarkers[norm] ?? ayahMarkers['mushaf-hafs-adi']!;
  }
}
