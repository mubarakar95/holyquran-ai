import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ShortcutLegendDialog extends StatelessWidget {
  final AppColors colors;

  const ShortcutLegendDialog({super.key, required this.colors});

  static void show(BuildContext context, AppColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => ShortcutLegendDialog(colors: colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.keyboard_rounded,
                      size: 20,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: colors.muted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 12),
            _buildRow('Play / Pause', 'Space', colors),
            _buildRow('Next Ayah', 'W / ↓', colors),
            _buildRow('Prev Ayah', 'S / ↑', colors),
            _buildRow('Repeat Mode', 'R', colors),
            _buildRow('Playback Speed', 'P', colors),
            _buildRow('Switch Voice', 'E', colors),
            _buildRow('Turn Page', '← / →', colors),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String keyLabel, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              keyLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
