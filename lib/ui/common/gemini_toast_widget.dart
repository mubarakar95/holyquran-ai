import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/gemini_toast_event.dart';
import '../../providers/gemini_toast_provider.dart';
import 'gemini_key_dialog.dart';

class GeminiToastWidget extends ConsumerWidget {
  const GeminiToastWidget({super.key});

  Color _getBorderColor(GeminiToastStatus status) {
    switch (status) {
      case GeminiToastStatus.loading:
        return Colors.blue.withValues(alpha: 0.5);
      case GeminiToastStatus.fallback:
        return Colors.amber.withValues(alpha: 0.6);
      case GeminiToastStatus.success:
        return const Color(0xFF10B981).withValues(alpha: 0.6);
      case GeminiToastStatus.error:
        return Colors.red.withValues(alpha: 0.6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(geminiToastProvider);
    if (toast == null) return const SizedBox.shrink();

    final isPrompt = toast.actionLabel != null || toast.id == 'connect-gemini-prompt';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: isPrompt
                ? () {
                    ref.read(geminiToastProvider.notifier).dismiss();
                    GeminiKeyDialog.show(context, ref);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF171717).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getBorderColor(toast.status), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _buildStatusIcon(toast.status),
                  ),
                  const SizedBox(width: 10),

                  // Title, Model Tag & Message
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              toast.title,
                              style: const TextStyle(
                                color: Color(0xFFE5E5E5),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (toast.model != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262626),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF404040)),
                                ),
                                child: Text(
                                  toast.model!,
                                  style: const TextStyle(
                                    color: Color(0xFF93C5FD),
                                    fontSize: 9,
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          toast.message,
                          style: const TextStyle(
                            color: Color(0xFFD4D4D4),
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                        if (toast.actionLabel != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              ref.read(geminiToastProvider.notifier).dismiss();
                              GeminiKeyDialog.show(context, ref);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.key_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    toast.actionLabel!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Dismiss Button
                  GestureDetector(
                    onTap: () => ref.read(geminiToastProvider.notifier).dismiss(),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4, top: 1),
                      child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(GeminiToastStatus status) {
    switch (status) {
      case GeminiToastStatus.loading:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF60A5FA),
          ),
        );
      case GeminiToastStatus.fallback:
        return const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFBBF24));
      case GeminiToastStatus.success:
        return const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF34D399));
      case GeminiToastStatus.error:
        return const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF87171));
    }
  }
}
