import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mushaf_page_view.dart';

class PageFlipBookWidget extends ConsumerWidget {
  final int currentPage;

  const PageFlipBookWidget({
    super.key,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In RTL Mushaf:
    // Right page is odd (currentPage)
    // Left page is even (currentPage + 1)
    final rightPage = currentPage % 2 == 1 ? currentPage : currentPage - 1;
    final leftPage = rightPage + 1 <= 604 ? rightPage + 1 : null;

    return Row(
      children: [
        // Left Page (Even)
        Expanded(
          child: leftPage != null
              ? MushafPageView(pageNumber: leftPage, isSinglePage: false)
              : const SizedBox.shrink(),
        ),

        // Spine separator line
        Container(
          width: 1.5,
          color: Colors.black.withValues(alpha: 0.15),
        ),

        // Right Page (Odd)
        Expanded(
          child: MushafPageView(pageNumber: rightPage, isSinglePage: false),
        ),
      ],
    );
  }
}
