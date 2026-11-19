import 'package:flutter/material.dart';

class MadaniSurahHeaderWidget extends StatelessWidget {
  final String char;
  final String font;
  final String? title;
  final bool isDark;

  const MadaniSurahHeaderWidget({
    super.key,
    required this.char,
    required this.font,
    this.title,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        // Aspect ratio of Madani Surah Banner is roughly 8.72 : 1
        double height = maxWidth / 8.72;
        double width = maxWidth;

        if (constraints.hasBoundedHeight && height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * 8.72;
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/madani-surah-header.png',
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Positioned(
                top: height * 0.04,
                bottom: height * 0.16,
                left: width * 0.275,
                right: width * 0.275,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    char,
                    style: TextStyle(
                      fontFamily: font.isNotEmpty ? font : 'QCF4_QBSML',
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF18181B),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
