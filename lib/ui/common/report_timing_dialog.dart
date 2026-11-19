import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timing_report_provider.dart';

class ReportTimingDialog extends ConsumerStatefulWidget {
  final String verseKey; // e.g. "2:187"
  final AppColors colors;

  const ReportTimingDialog({
    super.key,
    required this.verseKey,
    required this.colors,
  });

  static Future<void> show(BuildContext context, {required String verseKey}) {
    return showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider);
            final colors = AppColors.fromMode(settings.theme);
            return ReportTimingDialog(verseKey: verseKey, colors: colors);
          },
        );
      },
    );
  }

  @override
  ConsumerState<ReportTimingDialog> createState() => _ReportTimingDialogState();
}

class _ReportTimingDialogState extends ConsumerState<ReportTimingDialog> {
  String _selectedIssue = 'timing_mismatch';
  late final TextEditingController _noteController;

  final List<Map<String, String>> _issueOptions = [
    {'id': 'timing_mismatch', 'label': '⏰ Timing Out of Sync'},
    {'id': 'highlight_too_fast', 'label': '⚡ Highlight Too Fast'},
    {'id': 'highlight_too_slow', 'label': '🐢 Highlight Too Slow'},
    {'id': 'wrong_phrase', 'label': '✂️ Wrong Phrase Split'},
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final reportState = ref.watch(timingReportProvider);
    final isAlreadyReported = reportState.isAyahReported(widget.verseKey);

    final parts = widget.verseKey.split(':');
    final surahNum = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final ayahNum = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Flag Icon + Title + Ayah Badge + Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    size: 22,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Timing Issue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ayah ${widget.verseKey}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                              ),
                            ),
                          ),
                          if (isAlreadyReported) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Pending Review',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: colors.muted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Description
            Text(
              'Is the segment highlight out of sync for this verse? Report it and our automated AI system will re-analyze and correct the timestamps.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.muted,
              ),
            ),

            const SizedBox(height: 16),

            // Issue selector label
            Text(
              'Select Issue:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 8),

            // Issue chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _issueOptions.map((opt) {
                final isSelected = _selectedIssue == opt['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIssue = opt['id']!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accent.withValues(alpha: 0.15)
                          : colors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? colors.accent : colors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      opt['label']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? colors.accent : colors.foreground,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Optional Note field
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: TextStyle(fontSize: 12, color: colors.foreground),
              decoration: InputDecoration(
                hintText: 'Additional details (optional, e.g. starts 1s early)',
                hintStyle: TextStyle(fontSize: 11, color: colors.muted.withValues(alpha: 0.6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: colors.background,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.accent),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Actions: Cancel & Submit
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: reportState.isSubmitting
                      ? null
                      : () async {
                          final notifier = ref.read(timingReportProvider.notifier);
                          final ok = await notifier.reportAyah(
                            surahNumber: surahNum,
                            ayahNumber: ayahNum,
                            issueType: _selectedIssue,
                            note: _noteController.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? '✅ Ayah ${widget.verseKey} reported. The AI agent will re-align it!'
                                      : '❌ Failed to submit report. Please try again.',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                backgroundColor: ok ? const Color(0xFF059669) : Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: reportState.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAlreadyReported ? 'Update Report' : 'Submit Report',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
