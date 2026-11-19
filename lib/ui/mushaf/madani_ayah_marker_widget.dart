import 'package:flutter/material.dart';
import '../../core/models/quran_types.dart';

class MadaniAyahMarkerWidget extends StatelessWidget {
  final String? verseKey;
  final String? char;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final double scale;
  final double? width;
  final double? height;

  const MadaniAyahMarkerWidget({
    super.key,
    this.verseKey,
    this.char,
    this.isHighlighted = false,
    this.onTap,
    this.scale = 1.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final verseNum = verseKey?.split(':').last;
    final displayNum = verseNum != null ? toArabicDigits(verseNum) : (char ?? '');
    final numLength = displayNum.length;

    final double effectiveHeight = height ?? (34 * scale);
    final double effectiveWidth = width ?? (26 * scale);

    final fontSize = numLength >= 3
        ? effectiveHeight * 0.32
        : numLength >= 2
            ? effectiveHeight * 0.38
            : effectiveHeight * 0.44;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: effectiveWidth,
        height: effectiveHeight,
        margin: width != null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 2),
        decoration: isHighlighted
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC59B27).withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/madani-ayah-marker.png',
              width: effectiveWidth,
              height: effectiveHeight,
              fit: BoxFit.contain,
            ),
            Positioned(
              top: effectiveHeight * 0.20,
              child: Text(
                displayNum,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
