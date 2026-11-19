import 'package:flutter/material.dart';

/// A vector icon that visually represents an authentic open Madani Mushaf spread.
///
/// In the authentic Right-to-Left (RTL) Madani Quran:
/// - Odd pages (1, 3, 5, ...) appear on the **RIGHT** side of the spread.
/// - Even pages (2, 4, 6, ...) appear on the **LEFT** side of the spread.
///
/// This icon renders the open two-page book spread and highlights the active page
/// (Right for odd, Left for even), giving the user an instant, accurate representation
/// of the page's position in the real physical Mushaf.
class MushafPageSideIcon extends StatelessWidget {
  final int pageNumber;
  final double width;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showTooltip;

  const MushafPageSideIcon({
    super.key,
    required this.pageNumber,
    this.width = 20,
    this.height = 15,
    this.activeColor,
    this.inactiveColor,
    this.showTooltip = true,
  });

  bool get isOddPage => pageNumber % 2 == 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveActive = activeColor ?? theme.colorScheme.onSurface;
    final effectiveInactive = inactiveColor ?? effectiveActive.withValues(alpha: 0.35);

    Widget icon = CustomPaint(
      size: Size(width, height),
      painter: _MushafPageSidePainter(
        isOdd: isOddPage,
        activeColor: effectiveActive,
        inactiveColor: effectiveInactive,
      ),
    );

    if (showTooltip) {
      final sideLabel = isOddPage ? 'Right page' : 'Left page';
      return Tooltip(
        message: '$sideLabel (Page $pageNumber)',
        child: icon,
      );
    }

    return icon;
  }
}

class _MushafPageSidePainter extends CustomPainter {
  final bool isOdd;
  final Color activeColor;
  final Color inactiveColor;

  _MushafPageSidePainter({
    required this.isOdd,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    const double padX = 1.0;
    const double padY = 0.8;
    final double center = w / 2.0;
    const double spineGap = 1.6;
    final double dip = h * 0.08;

    final double outerLeft = padX;
    final double spineLeft = center - spineGap / 2.0;
    final double spineRight = center + spineGap / 2.0;
    final double outerRight = w - padX;

    final double top = padY;
    final double bottom = h - padY - 1.2;

    // --- Build Left Page Path ---
    final leftPath = Path();
    leftPath.moveTo(spineLeft, top + dip);
    leftPath.quadraticBezierTo(
      (spineLeft + outerLeft) / 2.0,
      top - 0.4,
      outerLeft,
      top + 0.3,
    );
    leftPath.lineTo(outerLeft, bottom);
    leftPath.quadraticBezierTo(
      (spineLeft + outerLeft) / 2.0,
      bottom - 0.4,
      spineLeft,
      bottom + dip,
    );
    leftPath.close();

    // --- Build Right Page Path ---
    final rightPath = Path();
    rightPath.moveTo(spineRight, top + dip);
    rightPath.quadraticBezierTo(
      (spineRight + outerRight) / 2.0,
      top - 0.4,
      outerRight,
      top + 0.3,
    );
    rightPath.lineTo(outerRight, bottom);
    rightPath.quadraticBezierTo(
      (spineRight + outerRight) / 2.0,
      bottom - 0.4,
      spineRight,
      bottom + dip,
    );
    rightPath.close();

    // --- Spine Hinge ---
    final hingePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final hingePath = Path();
    hingePath.moveTo(spineLeft - 0.5, bottom + dip);
    hingePath.quadraticBezierTo(center, bottom + dip + 1.2, spineRight + 0.5, bottom + dip);
    canvas.drawPath(hingePath, hingePaint);

    // In a real Mushaf:
    // Odd = Right page active
    // Even = Left page active
    final bool rightActive = isOdd;
    final bool leftActive = !isOdd;

    final activeFillPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final activeStrokePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final inactiveFillPaint = Paint()
      ..color = inactiveColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final inactiveStrokePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Line ink on active page (representing scripture lines)
    final linePaint = Paint()
      ..color = (activeColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
          .withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // --- Draw Left Page ---
    if (leftActive) {
      canvas.drawPath(leftPath, activeFillPaint);
      canvas.drawPath(leftPath, activeStrokePaint);

      // 3 subtle scripture lines on active left page
      for (final ratio in [0.30, 0.50, 0.70]) {
        final ly = top + (bottom - top) * ratio;
        canvas.drawLine(
          Offset(outerLeft + 2.2, ly),
          Offset(spineLeft - 2.0, ly + 0.2),
          linePaint,
        );
      }
    } else {
      canvas.drawPath(leftPath, inactiveFillPaint);
      canvas.drawPath(leftPath, inactiveStrokePaint);
    }

    // --- Draw Right Page ---
    if (rightActive) {
      canvas.drawPath(rightPath, activeFillPaint);
      canvas.drawPath(rightPath, activeStrokePaint);

      // 3 subtle scripture lines on active right page
      for (final ratio in [0.30, 0.50, 0.70]) {
        final ly = top + (bottom - top) * ratio;
        canvas.drawLine(
          Offset(spineRight + 2.0, ly + 0.2),
          Offset(outerRight - 2.2, ly),
          linePaint,
        );
      }
    } else {
      canvas.drawPath(rightPath, inactiveFillPaint);
      canvas.drawPath(rightPath, inactiveStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MushafPageSidePainter oldDelegate) {
    return oldDelegate.isOdd != isOdd ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
