import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';
import '../../core/models/quran_types.dart';
import '../../core/models/quran_dressing_catalog.dart';
import '../../core/models/qvp_dress.dart';
import '../../core/theme/app_theme.dart';

typedef MadaniFrameSlotBuilder = Widget Function(
  BuildContext context,
  double frameWidth,
  double frameHeight,
);

class MadaniFrameWidget extends StatelessWidget {
  /// Canonical mathematical frame and slot dimensions extracted from
  /// KFGQPC Hafs manuscript scans (quran-assets / mushaf-hafs-adi).
  static const double frameAspectRatio = 64.419 / 100.0; // 0.64419
  static const double slotInsetLeftRatio = 4.2763 / 64.419; // ~0.06638 (6.638%)
  static const double slotInsetRightRatio = (64.419 - 4.2763 - 55.8662) / 64.419; // ~0.06638 (6.638%)
  static const double slotInsetTopRatio = 5.0439 / 100.0; // ~0.05044 (5.044%)
  static const double slotInsetBottomRatio = (100.0 - 5.0439 - 89.9671) / 100.0; // ~0.04989 (4.989%)

  final int pageNumber;
  final Widget? child;
  final MadaniFrameSlotBuilder? builder;
  final String surahTitle;
  final String juzTitle;
  final bool isSinglePage;
  final AppThemeMode themeMode;
  final String frameDress;
  final QvpFrameDress? frameDressData;
  final VoidCallback? onBackgroundTap;

  const MadaniFrameWidget({
    super.key,
    required this.pageNumber,
    this.child,
    this.builder,
    required this.surahTitle,
    required this.juzTitle,
    this.isSinglePage = true,
    required this.themeMode,
    this.frameDress = 'madani',
    this.frameDressData,
    this.onBackgroundTap,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided');

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.fromMode(themeMode);
    final isOddPage = pageNumber % 2 == 1;

    // Authentic Madani Mushaf layout:
    // In RTL:
    // Odd (Right page): Outer is on RIGHT (Surah), Spine is on LEFT (Juz)
    // Even (Left page): Spine is on RIGHT (Juz), Outer is on LEFT (Surah)
    final topHeaderRight = isOddPage ? surahTitle : juzTitle;
    final topHeaderLeft = isOddPage ? juzTitle : surahTitle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        final frameMeta = QuranDressingCatalog.getFrameMeta(frameDress);
        final cachedDress = frameDressData ?? QvpFrameDress.getCached(frameDress);
        final double frameAspectRatio = frameMeta.aspectRatio;
        final double slotInsetLeftRatio = frameMeta.slotInsetLeftRatio;
        final double slotInsetRightRatio = frameMeta.slotInsetRightRatio;
        final double slotInsetTopRatio = frameMeta.slotInsetTopRatio;
        final double slotInsetBottomRatio = frameMeta.slotInsetBottomRatio;

        // Header & Footer vertical allocations (compact and crisp)
        final double headerHeight = (maxHeight * 0.028).clamp(18.0, 24.0);
        final double footerHeight = (maxHeight * 0.026).clamp(16.0, 22.0);
        const double headerGap = 2.0;
        const double footerGap = 2.0;

        // Maximum vertical space available for the ornate frame itself
        final double maxFrameHeight = maxHeight - headerHeight - footerHeight - headerGap - footerGap;

        // Calculate frame dimensions preserving authentic manuscript frame aspect ratio
        // Remove margin of the frame: expand frame to full available width (edge-to-edge)
        double frameWidth = maxWidth;
        double frameHeight = frameWidth / frameAspectRatio;

        // If height exceeds available vertical space (e.g. tablet two-page or landscape), constrain by height
        if (frameHeight > maxFrameHeight) {
          frameHeight = maxFrameHeight;
          frameWidth = frameHeight * frameAspectRatio;
        }

        // Horizontal centering (when frameWidth == maxWidth, frameAreaLeft is exactly 0.0: ZERO MARGIN)
        final double frameAreaLeft = (maxWidth - frameWidth) / 2.0;

        // Total content height (header + gap + frame + gap + footer)
        final double totalContentHeight = frameHeight + headerHeight + footerHeight + headerGap + footerGap;
        final double topOffset = (maxHeight - totalContentHeight) > 0 ? (maxHeight - totalContentHeight) / 2.0 : 0.0;

        final double headerTop = topOffset;
        final double actualFrameTop = topOffset + headerHeight + headerGap;
        final double footerTop = actualFrameTop + frameHeight + footerGap;

        return Center(
          child: SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Tap Catcher: only triggered on margins outside the frame
                if (onBackgroundTap != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBackgroundTap,
                    ),
                  ),

                // Top Sheet Header: Surah & Juz title placed gracefully ABOVE the frame
                Positioned(
                  top: headerTop,
                  left: frameAreaLeft + 4.0,
                  right: frameAreaLeft + 4.0,
                  height: headerHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rightmost title: Surah on odd page, Juz on even page
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          topHeaderRight,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: (headerHeight * 0.72).clamp(12.0, 16.0),
                            fontWeight: FontWeight.bold,
                            color: colors.foreground.withValues(alpha: 0.90),
                            height: 1.0,
                          ),
                        ),
                      ),
                      // Leftmost title: Juz on odd page, Surah on even page
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          topHeaderLeft,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: (headerHeight * 0.72).clamp(12.0, 16.0),
                            fontWeight: FontWeight.bold,
                            color: colors.foreground.withValues(alpha: 0.90),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Ornate Vector Frame & Text Block Area
                Positioned(
                  top: actualFrameTop,
                  left: frameAreaLeft,
                  width: frameWidth,
                  height: frameHeight,
                  child: Stack(
                    children: [
                      // Crisp background fill inside the inner frame text slot
                      Positioned(
                        left: frameWidth * slotInsetLeftRatio,
                        right: frameWidth * slotInsetRightRatio,
                        top: frameHeight * slotInsetTopRatio,
                        bottom: frameHeight * slotInsetBottomRatio,
                        child: ColoredBox(
                          color: themeMode == AppThemeMode.light
                              ? Colors.white
                              : (themeMode == AppThemeMode.creme
                                  ? const Color(0xFFF7F2E9)
                                  : Colors.transparent),
                        ),
                      ),

                      // Frame Overlay based on selected style
                      if (frameDress == 'minimal')
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MinimalFramePainter(
                              color: themeMode == AppThemeMode.dark
                                  ? const Color(0xFFFBBF24).withValues(alpha: 0.75)
                                  : const Color(0xFFC59B27).withValues(alpha: 0.85),
                            ),
                          ),
                        )
                      else if (frameDress != 'none')
                        Positioned.fill(
                          child: Opacity(
                            opacity: themeMode == AppThemeMode.dark ? 0.65 : 1.0,
                            child: cachedDress?.picture != null
                                ? CustomPaint(
                                    painter: QvpFramePainter(dress: cachedDress!),
                                  )
                                : SvgPicture(
                                    AssetBytesLoader(
                                      'assets/ornaments/page-frames/${QuranDressingCatalog.normalizeFrameId(frameDress)}.svg.vec',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                          ),
                        ),

                      // Text Slot Area inside the inner rule lines of the ornate frame
                      Positioned(
                        left: frameWidth * slotInsetLeftRatio,
                        right: frameWidth * slotInsetRightRatio,
                        top: frameHeight * slotInsetTopRatio,
                        bottom: frameHeight * slotInsetBottomRatio,
                        child: builder != null
                            ? builder!(context, frameWidth, frameHeight)
                            : child!,
                      ),
                    ],
                  ),
                ),

                // Bottom Sheet Footer: Page Number (centered) gracefully BELOW the frame
                Positioned(
                  top: footerTop,
                  left: 0,
                  right: 0,
                  height: footerHeight,
                  child: Center(
                    child: Text(
                      toArabicDigits(pageNumber),
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: (footerHeight * 0.88).clamp(14.0, 19.0),
                        fontWeight: FontWeight.bold,
                        color: colors.foreground.withValues(alpha: 0.9),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MinimalFramePainter extends CustomPainter {
  final Color color;

  const _MinimalFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(outerRect, outerPaint);

    final innerRect = Rect.fromLTWH(4.0, 4.0, size.width - 8.0, size.height - 8.0);
    canvas.drawRect(innerRect, innerPaint);

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final offset in [
      const Offset(2.0, 2.0),
      Offset(size.width - 2.0, 2.0),
      Offset(2.0, size.height - 2.0),
      Offset(size.width - 2.0, size.height - 2.0),
    ]) {
      canvas.drawCircle(offset, 1.8, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalFramePainter oldDelegate) => oldDelegate.color != color;
}


