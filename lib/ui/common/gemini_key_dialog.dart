import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/audio_player_provider.dart';

class GeminiKeyDialog extends ConsumerStatefulWidget {
  final AppColors colors;

  const GeminiKeyDialog({super.key, required this.colors});

  static void show(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);
    showDialog(
      context: context,
      builder: (ctx) => GeminiKeyDialog(colors: colors),
    );
  }

  @override
  ConsumerState<GeminiKeyDialog> createState() => _GeminiKeyDialogState();
}

class _GeminiKeyDialogState extends ConsumerState<GeminiKeyDialog> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(settingsProvider).geminiApiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(16),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect Gemini AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        'Clause Synchronization',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  color: colors.muted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'To enable intelligent audio segmentation and clause-by-clause synchronization, connect your Google Gemini API key.',
              style: TextStyle(
                fontSize: 12,
                color: colors.foreground.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              style: TextStyle(fontSize: 13, color: colors.foreground),
              decoration: InputDecoration(
                hintText: 'Enter AI Studio API Key',
                hintStyle: TextStyle(fontSize: 12, color: colors.muted),
                isDense: true,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                ),
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                prefixIconColor: colors.muted,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      color: colors.muted,
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _controller.text = data!.text!.trim();
                        }
                      },
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/app/apikey'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied link: https://aistudio.google.com/app/apikey'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    'Get free key at aistudio.google.com (tap to copy)',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF10B981).withValues(alpha: 0.9),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: colors.muted, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final key = _controller.text.trim();
                    ref.read(settingsProvider.notifier).setGeminiApiKey(key);
                    if (key.isNotEmpty) {
                      // Also enable segmented mode if it was off
                      if (!ref.read(audioPlayerProvider).segmentedMode) {
                        ref.read(audioPlayerProvider.notifier).toggleSegmentedMode();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gemini API Key connected! AI Synchronization enabled.'),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Save & Connect', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
