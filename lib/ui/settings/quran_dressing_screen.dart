import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';
import '../../core/models/quran_dressing_catalog.dart';
import '../../core/models/qvp_dress.dart';
import '../../core/models/quran_types.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

class QuranDressingScreen extends ConsumerWidget {
  final int previewPageNumber;

  const QuranDressingScreen({
    super.key,
    this.previewPageNumber = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final colors = AppColors.fromMode(settings.theme);

    final currentFrame = QuranDressingCatalog.normalizeFrameId(settings.frameDress);
    final currentHeader = QuranDressingCatalog.normalizeHeaderId(settings.surahHeaderDress);
    final currentAyah = QuranDressingCatalog.normalizeAyahId(settings.ayahDress);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.foreground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Quran Dressing & Ornaments',
          style: TextStyle(
            color: colors.foreground,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              settingsNotifier.setFrameDress('mushaf-hafs-adi');
              settingsNotifier.setAyahDress('mushaf-hafs-adi');
              settingsNotifier.setSurahHeaderDress('mushaf-hafs-adi');
            },
            child: Text(
              'Reset Default',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ─── LIVE ORNAMENT PREVIEW CARD ──────────────────────────────────
          _DressingLivePreview(
            frameDress: settings.frameDress,
            surahHeaderDress: settings.surahHeaderDress,
            ayahDress: settings.ayahDress,
            themeMode: settings.theme,
            colors: colors,
          ),
          const SizedBox(height: 24),

          // ─── SECTION 1: PAGE FRAME STYLE ───────────────────────────────
          _SectionHeader(
            title: 'Page Frame Style',
            subtitle: 'Choose the manuscript border framing the Quran pages from quran-assets',
            icon: Icons.crop_portrait_rounded,
            colors: colors,
          ),
          const SizedBox(height: 10),

          // The 8 Authentic Manuscript Frames
          ...QuranDressingCatalog.mushafStyles.map((item) {
            final isSelected = currentFrame == item.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DressingOptionCard(
                title: item.title,
                subtitle: item.riwayah,
                description: item.description,
                isSelected: isSelected,
                isDefault: item.isDefault,
                icon: Icons.auto_awesome_rounded,
                colors: colors,
                onTap: () => settingsNotifier.setFrameDress(item.id),
              ),
            );
          }),

          // Minimalist & Borderless options
          _DressingOptionCard(
            title: 'Minimalist Gold Rule',
            subtitle: 'Modern Clean Framing',
            description: 'Double golden rule border with delicate geometric corner accents',
            isSelected: settings.frameDress == 'minimal',
            isDefault: false,
            icon: Icons.border_style_rounded,
            colors: colors,
            onTap: () => settingsNotifier.setFrameDress('minimal'),
          ),
          const SizedBox(height: 8),
          _DressingOptionCard(
            title: 'Borderless (Full Bleed)',
            subtitle: 'Marginless Reading',
            description: 'Maximizes text canvas area with zero margins for distraction-free reading',
            isSelected: settings.frameDress == 'none',
            isDefault: false,
            icon: Icons.crop_free_rounded,
            colors: colors,
            onTap: () => settingsNotifier.setFrameDress('none'),
          ),
          const SizedBox(height: 28),

          // ─── SECTION 2: SURAH HEADING DECORATIONS ──────────────────────
          _SectionHeader(
            title: 'Surah Heading Header',
            subtitle: 'Select the illuminated ornamental cartouche above each Surah beginning',
            icon: Icons.view_headline_rounded,
            colors: colors,
          ),
          const SizedBox(height: 10),

          // The 8 Authentic Manuscript Surah Headers
          ...QuranDressingCatalog.mushafStyles.map((item) {
            final isSelected = currentHeader == item.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DressingOptionCard(
                title: '${item.title} Cartouche',
                subtitle: item.riwayah,
                description: item.description,
                isSelected: isSelected,
                isDefault: item.isDefault,
                icon: Icons.style_rounded,
                colors: colors,
                onTap: () => settingsNotifier.setSurahHeaderDress(item.id),
              ),
            );
          }),

          _DressingOptionCard(
            title: 'Original Manuscript Calligraphy',
            subtitle: 'Unadorned Title',
            description: 'Native ink title calligraphy directly on the page without cartouche illumination',
            isSelected: settings.surahHeaderDress == 'classic' || settings.surahHeaderDress == 'none',
            isDefault: false,
            icon: Icons.article_rounded,
            colors: colors,
            onTap: () => settingsNotifier.setSurahHeaderDress('classic'),
          ),
          const SizedBox(height: 28),

          // ─── SECTION 3: AYAH MARKER ORNAMENTS ──────────────────────────
          _SectionHeader(
            title: 'Ayah Marker Ornaments',
            subtitle: 'Choose the decorative end-of-ayah marker and numeral medallion',
            icon: Icons.stars_rounded,
            colors: colors,
          ),
          const SizedBox(height: 10),

          // The 8 Authentic Manuscript Ayah Markers
          ...QuranDressingCatalog.mushafStyles.map((item) {
            final isSelected = currentAyah == item.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DressingOptionCard(
                title: '${item.title} Marker',
                subtitle: item.riwayah,
                description: item.description,
                isSelected: isSelected,
                isDefault: item.isDefault,
                icon: Icons.star_rounded,
                colors: colors,
                onTap: () => settingsNotifier.setAyahDress(item.id),
              ),
            );
          }),

          _DressingOptionCard(
            title: 'Classic Manuscript Ring',
            subtitle: 'Native Ink Circle',
            description: 'Original simple vector circle extracted directly from the manuscript page',
            isSelected: settings.ayahDress == 'classic' || settings.ayahDress == 'none',
            isDefault: false,
            icon: Icons.radio_button_unchecked_rounded,
            colors: colors,
            onTap: () => settingsNotifier.setAyahDress('classic'),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

/// Standalone, robust, crash-proof live preview card
class _DressingLivePreview extends StatelessWidget {
  final String frameDress;
  final String surahHeaderDress;
  final String ayahDress;
  final AppThemeMode themeMode;
  final AppColors colors;

  const _DressingLivePreview({
    required this.frameDress,
    required this.surahHeaderDress,
    required this.ayahDress,
    required this.themeMode,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == AppThemeMode.dark;
    final normalizedFrame = QuranDressingCatalog.normalizeFrameId(frameDress);
    final normalizedHeader = QuranDressingCatalog.normalizeHeaderId(surahHeaderDress);
    final normalizedAyah = QuranDressingCatalog.normalizeAyahId(ayahDress);

    final isFrameNone = frameDress == 'none';
    final isFrameMinimal = frameDress == 'minimal';
    final isHeaderClassic = surahHeaderDress == 'classic' || surahHeaderDress == 'none';
    final isAyahClassic = ayahDress == 'classic' || ayahDress == 'none';

    final frameMeta = QuranDressingCatalog.getFrameMeta(normalizedFrame);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Frame background and inner area
          Center(
            child: AspectRatio(
              aspectRatio: frameMeta.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Slot background
                  Positioned(
                    left: 200 * frameMeta.slotInsetLeftRatio,
                    right: 200 * frameMeta.slotInsetRightRatio,
                    top: 260 * frameMeta.slotInsetTopRatio,
                    bottom: 260 * frameMeta.slotInsetBottomRatio,
                    child: Container(
                      color: isDark
                          ? const Color(0xFF18181B)
                          : (themeMode == AppThemeMode.creme
                              ? const Color(0xFFF7F2E9)
                              : Colors.white),
                    ),
                  ),

                  // Frame SVG overlay
                  if (isFrameMinimal)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFC59B27),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  else if (!isFrameNone)
                    Positioned.fill(
                      child: Opacity(
                        opacity: isDark ? 0.75 : 1.0,
                        child: Builder(
                          builder: (context) {
                            final cachedDress = QvpFrameDress.getCached(normalizedFrame);
                            if (cachedDress?.picture != null) {
                              return CustomPaint(
                                painter: QvpFramePainter(dress: cachedDress!),
                              );
                            }
                            return SvgPicture(
                              AssetBytesLoader(
                                'assets/ornaments/page-frames/$normalizedFrame.svg.vec',
                              ),
                              fit: BoxFit.fill,
                            );
                          },
                        ),
                      ),
                    ),

                  // Content inside frame slot
                  Positioned(
                    left: 200 * frameMeta.slotInsetLeftRatio + 8.0,
                    right: 200 * frameMeta.slotInsetRightRatio + 8.0,
                    top: 260 * frameMeta.slotInsetTopRatio + 8.0,
                    bottom: 260 * frameMeta.slotInsetBottomRatio + 8.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Surah Header Cartouche Preview
                        if (!isHeaderClassic)
                          SizedBox(
                            height: 38,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: isDark ? 0.80 : 1.0,
                                  child: SvgPicture.asset(
                                    'assets/ornaments/surah-headers/$normalizedHeader.svg',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    'سُورَةُ ٱلْفَاتِحَةِ',
                                    style: TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'سُورَةُ ٱلْفَاتِحَةِ',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.foreground,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Basmalah Calligraphy
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Sample Verse Line with Ayah Marker
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
                                style: TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.foreground,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!isAyahClassic)
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/ornaments/ayah-markers/$normalizedAyah.svg',
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.contain,
                                      ),
                                      Text(
                                        toArabicDigits(1),
                                        style: TextStyle(
                                          fontFamily: 'Amiri',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: colors.foreground,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.accent, width: 1.2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    toArabicDigits(1),
                                    style: TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: colors.accent,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live Preview Badge
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.remove_red_eye_rounded, size: 12, color: colors.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Live Ornament Preview',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.foreground),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final AppColors colors;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colors.accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

class _DressingOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String description;
  final bool isSelected;
  final bool isDefault;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onTap;

  const _DressingOptionCard({
    required this.title,
    this.subtitle,
    required this.description,
    required this.isSelected,
    required this.isDefault,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent.withValues(alpha: 0.10) : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.accent : colors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withValues(alpha: 0.20)
                      : colors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? colors.accent : colors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? colors.accent : colors.foreground,
                            ),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC59B27).withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC59B27),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.accent.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? colors.accent : colors.muted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
