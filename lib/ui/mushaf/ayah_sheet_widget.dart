import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quran_types.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/quran_page_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timing_report_provider.dart';
import '../common/report_timing_dialog.dart';

class AyahSheetWidget extends ConsumerStatefulWidget {
  final String verseKey;
  final VoidCallback onClose;

  const AyahSheetWidget({
    super.key,
    required this.verseKey,
    required this.onClose,
  });

  @override
  ConsumerState<AyahSheetWidget> createState() => _AyahSheetWidgetState();
}

class _AyahSheetWidgetState extends ConsumerState<AyahSheetWidget> {
  Set<int>? _selectedArabicPositions;
  double _dragOffsetY = 0.0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);
    final isReported = ref.watch(timingReportProvider).isAyahReported(widget.verseKey);

    final quranState = ref.watch(quranPageProvider);
    final wbwAsync = ref.watch(wbwDataProvider);
    final translationAsync = ref.watch(translationPageProvider(quranState.currentPage));
    final alignmentsAsync = ref.watch(pageAlignmentsProvider(quranState.currentPage));

    final wbwList = wbwAsync.value?[widget.verseKey] ?? [];
    final translation = translationAsync.value?[widget.verseKey] ?? '';
    final alignments = alignmentsAsync.value?[widget.verseKey] ?? [];

    return Transform.translate(
      offset: Offset(0, _dragOffsetY),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Draggable Top Area (Drag Handle + Header)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! > 0 || _dragOffsetY > 0) {
                  setState(() {
                    _dragOffsetY = (_dragOffsetY + details.primaryDelta!).clamp(0.0, 400.0);
                  });
                }
              },
              onVerticalDragEnd: (details) {
                if (_dragOffsetY > 60.0 || (details.primaryVelocity ?? 0) > 250.0) {
                  widget.onClose();
                } else {
                  setState(() {
                    _dragOffsetY = 0.0;
                  });
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(top: 8, bottom: 6),
                      decoration: BoxDecoration(
                        color: colors.muted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.verseKey,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.foreground,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Play Arabic Button
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(audioPlayerProvider.notifier).playAyah(
                                  widget.verseKey,
                                  modeOverride: AudioMode.arabic,
                                );
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.blue),
                              label: const Text('العربية Audio', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.background,
                                foregroundColor: colors.foreground,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(color: colors.border),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Play Malayalam Button
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(audioPlayerProvider.notifier).playAyah(
                                  widget.verseKey,
                                  modeOverride: AudioMode.malayalam,
                                );
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF059669)),
                              label: const Text('മലയാളം Audio', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.background,
                                foregroundColor: colors.foreground,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(color: colors.border),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: isReported ? 'Timing reported (Under Review)' : 'Report timing issue',
                              onPressed: () => ReportTimingDialog.show(context, verseKey: widget.verseKey),
                              icon: Icon(
                                isReported ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                                size: 18,
                                color: isReported ? Colors.amber : colors.muted,
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close, size: 18),
                              color: colors.muted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Scrollable content: Translation + WBW rows
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Full Malayalam translation with phrase highlights
                if (translation.isNotEmpty) ...[
                  Text(
                    'വിവർത്തനം',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (alignments.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: alignments.map((align) {
                        final isSelected = _selectedArabicPositions != null &&
                            align.arabicPositions.any((pos) => _selectedArabicPositions!.contains(pos));

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedArabicPositions = null;
                              } else {
                                _selectedArabicPositions = align.arabicPositions.toSet();
                              }
                            });
                          },
                          onDoubleTap: () {
                            final firstPos = align.arabicPositions.isNotEmpty ? align.arabicPositions.first - 1 : 0;
                            ref.read(audioPlayerProvider.notifier).seekToWord(widget.verseKey, firstPos);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                  : colors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF59E0B)
                                    : colors.border,
                              ),
                            ),
                            child: Text(
                              align.phrase,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.foreground,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      translation,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.foreground,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                const Divider(height: 1),
                const SizedBox(height: 8),

                // Word by word table
                Text(
                  'പദാനുപദ അർത്ഥം',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 8),

                ...List.generate(wbwList.length, (idx) {
                  final position = idx + 1;
                  final meaning = wbwList[idx];
                  final isRowSelected = _selectedArabicPositions?.contains(position) ?? false;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isRowSelected) {
                          _selectedArabicPositions = null;
                        } else {
                          _selectedArabicPositions = {position};
                        }
                      });
                    },
                    onDoubleTap: () {
                      ref.read(audioPlayerProvider.notifier).seekToWord(widget.verseKey, idx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isRowSelected
                            ? const Color(0xFFFDE68A).withValues(alpha: 0.3)
                            : colors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isRowSelected
                              ? const Color(0xFFF59E0B)
                              : colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              meaning,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.foreground,
                                fontWeight: isRowSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'പദം $position',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    ),);
  }
}
