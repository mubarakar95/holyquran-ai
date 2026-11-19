import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quran_types.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timing_report_provider.dart';
import '../common/report_timing_dialog.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  const AudioPlayerWidget({super.key});

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    if (!audioState.audioVisible) return const SizedBox.shrink();

    final timingReports = ref.watch(timingReportProvider);
    final currentVerse = audioState.currentVerseKey;
    final isReported = currentVerse != null && timingReports.isAyahReported(currentVerse);

    final audioNotifier = ref.read(audioPlayerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Playhead Progress Bar
            if (audioState.duration > Duration.zero)
              ClipRRect(
                child: LinearProgressIndicator(
                  value: (audioState.position.inMilliseconds / audioState.duration.inMilliseconds).clamp(0.0, 1.0),
                  minHeight: 2.5,
                  backgroundColor: colors.border.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              ),

            // Expanded controls (Speed, Repeat, Mode, Reciter)
            if (_isExpanded) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Reciter selector row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reciter',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                        DropdownButton<Reciter>(
                          value: audioState.reciter,
                          underline: const SizedBox(),
                          dropdownColor: colors.surface,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.foreground,
                          ),
                          items: RECITERS.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text('${r.name} (${r.arabicName})'),
                            );
                          }).toList(),
                          onChanged: (newReciter) {
                            if (newReciter != null) {
                              audioNotifier.setReciter(newReciter);
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Audio Mode & Speed row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Mode Selector (Ar, Ml, Both)
                        Row(
                          children: [
                            _buildModeChip('Ar', AudioMode.arabic, audioState.audioMode, colors, () {
                              audioNotifier.setAudioMode(AudioMode.arabic);
                            }),
                            const SizedBox(width: 4),
                            _buildModeChip('Ml', AudioMode.malayalam, audioState.audioMode, colors, () {
                              audioNotifier.setAudioMode(AudioMode.malayalam);
                            }),
                            const SizedBox(width: 4),
                            _buildModeChip('Ml+Ar', AudioMode.both, audioState.audioMode, colors, () {
                              audioNotifier.setAudioMode(AudioMode.both);
                            }),
                          ],
                        ),

                        // Speed selectors
                        Row(
                          children: [1.0, 1.25, 1.5, 2.0].map((spd) {
                            final curSpd = audioState.audioMode == AudioMode.malayalam
                                ? audioState.malayalamPlaybackRate
                                : audioState.arabicPlaybackRate;
                            final isSel = curSpd == spd;

                            return GestureDetector(
                              onTap: () {
                                if (audioState.audioMode == AudioMode.malayalam) {
                                  audioNotifier.setMalayalamSpeed(spd);
                                } else {
                                  audioNotifier.setArabicSpeed(spd);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSel ? colors.accent : colors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSel ? colors.accent : colors.border,
                                  ),
                                ),
                                child: Text(
                                  '${spd}x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : colors.foreground,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    if (audioState.audioMode == AudioMode.both) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: audioNotifier.toggleSegmentedMode,
                        child: Row(
                          children: [
                            Icon(
                              audioState.segmentedMode
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: audioState.segmentedMode ? const Color(0xFF10B981) : colors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Clause-by-Clause Sync',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: audioState.segmentedMode ? const Color(0xFF10B981) : colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (currentVerse != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => ReportTimingDialog.show(context, verseKey: currentVerse),
                            child: Row(
                              children: [
                                Icon(
                                  isReported ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                                  size: 16,
                                  color: isReported ? Colors.amber : colors.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isReported ? 'Ayah $currentVerse Reported (Under Review)' : 'Report Timing Issue ($currentVerse)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isReported ? Colors.amber : colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => ReportTimingDialog.show(context, verseKey: currentVerse),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isReported ? Colors.amber : colors.accent).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (isReported ? Colors.amber : colors.accent).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isReported ? 'Status: Pending' : 'Report',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isReported ? Colors.amber : colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Divider(color: colors.border, height: 1),
            ],

            // Main Player Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Expand / Collapse button
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.keyboard_arrow_down : Icons.tune_rounded,
                      size: 20,
                    ),
                    color: colors.muted,
                  ),

                  // Current Verse Tag
                  if (audioState.currentVerseKey != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        audioState.currentVerseKey!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    if (audioState.audioMode == AudioMode.both && audioState.segmentedMode && audioState.totalClauses > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '[${audioState.currentClauseIndex + 1}/${audioState.totalClauses}]',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                  ],

                  // Playback controls (RTL: Left button advances to Next Ayah, Right button returns to Prev Ayah)
                  IconButton(
                    tooltip: 'Next Ayah',
                    onPressed: audioNotifier.nextAyah,
                    icon: Transform.scale(
                      scaleX: -1,
                      child: const Icon(Icons.skip_next_rounded, size: 24),
                    ),
                    color: colors.foreground,
                  ),

                  // Play / Pause Circle
                  GestureDetector(
                    onTap: () {
                      if (audioState.isPlaying) {
                        audioNotifier.pause();
                      } else {
                        audioNotifier.resume();
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: audioState.isBuffering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                audioState.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Previous Ayah',
                    onPressed: audioNotifier.prevAyah,
                    icon: Transform.scale(
                      scaleX: -1,
                      child: const Icon(Icons.skip_previous_rounded, size: 24),
                    ),
                    color: colors.foreground,
                  ),

                  const Spacer(),

                  // Repeat toggle
                  IconButton(
                    onPressed: () {
                      final next = audioState.repeatMode == QuranRepeatMode.none
                          ? QuranRepeatMode.ayah
                          : audioState.repeatMode == QuranRepeatMode.ayah
                              ? QuranRepeatMode.page
                              : QuranRepeatMode.none;
                      audioNotifier.setRepeatMode(next);
                    },
                    icon: Icon(
                      audioState.repeatMode == QuranRepeatMode.ayah
                          ? Icons.repeat_one_rounded
                          : audioState.repeatMode == QuranRepeatMode.page
                              ? Icons.repeat_rounded
                              : Icons.repeat_rounded,
                      size: 20,
                    ),
                    color: audioState.repeatMode != QuranRepeatMode.none ? colors.accent : colors.muted,
                  ),

                  // Report timing issue button
                  if (currentVerse != null)
                    IconButton(
                      tooltip: isReported
                          ? 'Timing reported ($currentVerse - Under Review)'
                          : 'Report timing issue ($currentVerse)',
                      onPressed: () => ReportTimingDialog.show(context, verseKey: currentVerse),
                      icon: Icon(
                        isReported ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                        size: 20,
                        color: isReported ? Colors.amber : colors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
    String label,
    AudioMode mode,
    AudioMode currentMode,
    AppColors colors,
    VoidCallback onTap,
  ) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : colors.foreground,
          ),
        ),
      ),
    );
  }
}
