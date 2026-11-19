import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class JustifiedLineParentData extends ContainerBoxParentData<RenderBox> {}

class JustifiedQuranLine extends MultiChildRenderObjectWidget {
  final bool isCentered;
  final TextDirection textDirection;

  const JustifiedQuranLine({
    super.key,
    required super.children,
    this.isCentered = false,
    this.textDirection = TextDirection.rtl,
  });

  @override
  RenderJustifiedQuranLine createRenderObject(BuildContext context) {
    return RenderJustifiedQuranLine(
      isCentered: isCentered,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderJustifiedQuranLine renderObject) {
    renderObject
      ..isCentered = isCentered
      ..textDirection = textDirection;
  }
}

class RenderJustifiedQuranLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, JustifiedLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, JustifiedLineParentData> {
  bool _isCentered;
  TextDirection _textDirection;
  double _scale = 1.0;

  RenderJustifiedQuranLine({
    List<RenderBox>? children,
    required bool isCentered,
    required TextDirection textDirection,
  })  : _isCentered = isCentered,
        _textDirection = textDirection {
    addAll(children);
  }

  bool get isCentered => _isCentered;
  set isCentered(bool val) {
    if (_isCentered == val) return;
    _isCentered = val;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection val) {
    if (_textDirection == val) return;
    _textDirection = val;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! JustifiedLineParentData) {
      child.parentData = JustifiedLineParentData();
    }
  }

  @override
  void performLayout() {
    double maxChildHeight = 0.0;
    double totalWordsWidth = 0.0;
    int childCount = 0;

    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(const BoxConstraints(), parentUsesSize: true);
      totalWordsWidth += child.size.width;
      maxChildHeight = math.max(maxChildHeight, child.size.height);
      childCount++;
      final childParentData = child.parentData! as JustifiedLineParentData;
      child = childParentData.nextSibling;
    }

    final double targetWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : (totalWordsWidth > 0 ? totalWordsWidth : 300.0);
    final double targetHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : (maxChildHeight > 0 ? maxChildHeight : 30.0);

    if (childCount == 0) {
      _scale = 1.0;
      size = Size(targetWidth, targetHeight);
      return;
    }

    // In authentic Madani Mushaf typography (conforming to quran-engine layout rules):
    // 1. Inter-word spacing expands gently to justify flush to margins.
    // 2. Gaps are strictly bounded by maxStretchGap (REFLOW_MAX_STRETCH = 2.0-2.2).
    // 3. Short lines whose needed gap exceeds maxStretchGap or total ink is under 75%
    //    are centered with naturalGap, preventing giant gaping holes between words.
    // 4. Overfull lines scale down smoothly via transform matrix with zero overflow warnings.
    final double naturalGap = math.max(2.5, targetWidth * 0.012);
    final double maxStretchGap = naturalGap * 2.2;

    final double neededGap = childCount > 1
        ? (targetWidth - totalWordsWidth) / (childCount - 1)
        : 0.0;

    final bool shouldCenter = _isCentered ||
        childCount == 1 ||
        (totalWordsWidth + naturalGap * (childCount - 1) < targetWidth * 0.75) ||
        (neededGap > maxStretchGap);

    if (totalWordsWidth > targetWidth && targetWidth > 0) {
      _scale = targetWidth / totalWordsWidth;
    } else {
      _scale = 1.0;
    }

    final double layoutWidth = _scale < 1.0 ? totalWordsWidth : targetWidth;

    if (shouldCenter) {
      final double effectiveGap = naturalGap;
      final double rowWidth = totalWordsWidth + effectiveGap * (childCount - 1);
      double curX = _textDirection == TextDirection.rtl
          ? (layoutWidth + rowWidth) / 2.0
          : (layoutWidth - rowWidth) / 2.0;

      child = firstChild;
      while (child != null) {
        final double cw = child.size.width;
        final double ch = child.size.height;
        final double cy = (targetHeight - ch) / 2.0;
        final childParentData = child.parentData! as JustifiedLineParentData;

        if (_textDirection == TextDirection.rtl) {
          curX -= cw;
          childParentData.offset = Offset(curX, cy);
          curX -= effectiveGap;
        } else {
          childParentData.offset = Offset(curX, cy);
          curX += cw + effectiveGap;
        }
        child = childParentData.nextSibling;
      }
    } else {
      // Justified flush to both right and left margins with bounded natural gap
      final double gap = neededGap.clamp(0.0, maxStretchGap);

      double curX = _textDirection == TextDirection.rtl ? layoutWidth : 0.0;
      child = firstChild;
      while (child != null) {
        final double cw = child.size.width;
        final double ch = child.size.height;
        final double cy = (targetHeight - ch) / 2.0;
        final childParentData = child.parentData! as JustifiedLineParentData;

        if (_textDirection == TextDirection.rtl) {
          curX -= cw;
          childParentData.offset = Offset(curX, cy);
          curX -= gap;
        } else {
          childParentData.offset = Offset(curX, cy);
          curX += cw + gap;
        }
        child = childParentData.nextSibling;
      }
    }

    size = Size(targetWidth, targetHeight);
    // debugPrint('JQL_LAYOUT: targetWidth=$targetWidth, targetHeight=$targetHeight, totalWordsWidth=$totalWordsWidth, scale=$_scale');
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_scale < 1.0) {
      final Matrix4 transform = Matrix4.diagonal3Values(_scale, _scale, 1.0);
      context.pushTransform(needsCompositing, offset, transform, (PaintingContext ctx, Offset off) {
        defaultPaint(ctx, off);
      });
    } else {
      defaultPaint(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale < 1.0) {
      final Offset transformedPosition = Offset(position.dx / _scale, position.dy / _scale);
      return defaultHitTestChildren(result, position: transformedPosition);
    }
    return defaultHitTestChildren(result, position: position);
  }
}
