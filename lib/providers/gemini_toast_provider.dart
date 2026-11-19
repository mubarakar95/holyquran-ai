import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/gemini_toast_event.dart';

class GeminiToastNotifier extends StateNotifier<GeminiToastEvent?> {
  Timer? _dismissTimer;

  GeminiToastNotifier() : super(null);

  void emit(GeminiToastEvent? toast, {int? autoDismissMs}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    state = toast;

    if (toast != null) {
      final delay = autoDismissMs ??
          (toast.status == GeminiToastStatus.loading
              ? 8000
              : (toast.status == GeminiToastStatus.success || toast.status == GeminiToastStatus.fallback
                  ? 3500
                  : 5000));
      _dismissTimer = Timer(Duration(milliseconds: delay), () {
        state = null;
        _dismissTimer = null;
      });
    }
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    state = null;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

final geminiToastProvider = StateNotifierProvider<GeminiToastNotifier, GeminiToastEvent?>((ref) {
  return GeminiToastNotifier();
});
