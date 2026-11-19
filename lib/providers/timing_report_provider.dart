import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/timing_report_service.dart';
import 'service_providers.dart';

class TimingReportState {
  final Set<String> reportedVerses;
  final bool isSubmitting;
  final String? lastError;

  const TimingReportState({
    this.reportedVerses = const {},
    this.isSubmitting = false,
    this.lastError,
  });

  TimingReportState copyWith({
    Set<String>? reportedVerses,
    bool? isSubmitting,
    String? lastError,
  }) {
    return TimingReportState(
      reportedVerses: reportedVerses ?? this.reportedVerses,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastError: lastError,
    );
  }

  bool isAyahReported(String verseKey) => reportedVerses.contains(verseKey);
}

class TimingReportNotifier extends StateNotifier<TimingReportState> {
  final TimingReportService _service;

  TimingReportNotifier(this._service)
      : super(TimingReportState(reportedVerses: _service.getLocalReportedKeys()));

  bool isAyahReported(String verseKey) {
    return state.isAyahReported(verseKey);
  }

  Future<bool> reportAyah({
    required int surahNumber,
    required int ayahNumber,
    required String issueType,
    String? note,
  }) async {
    state = state.copyWith(isSubmitting: true, lastError: null);

    final success = await _service.reportTimingIssue(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      issueType: issueType,
      note: note,
    );

    final verseKey = '$surahNumber:$ayahNumber';
    if (success) {
      final updatedSet = Set<String>.from(state.reportedVerses)..add(verseKey);
      state = state.copyWith(
        reportedVerses: updatedSet,
        isSubmitting: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isSubmitting: false,
        lastError: 'Failed to submit report. Please check your network connection.',
      );
      return false;
    }
  }
}

final timingReportProvider = StateNotifierProvider<TimingReportNotifier, TimingReportState>((ref) {
  final service = ref.watch(timingReportServiceProvider);
  return TimingReportNotifier(service);
});
