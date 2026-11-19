enum GeminiToastStatus {
  loading,
  fallback,
  success,
  error,
}

class GeminiToastEvent {
  final String id;
  final String title;
  final String message;
  final GeminiToastStatus status;
  final String? model;
  final String? actionLabel;
  final DateTime timestamp;

  GeminiToastEvent({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    this.model,
    this.actionLabel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
