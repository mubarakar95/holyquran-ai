import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/quran_data_service.dart';
import '../core/services/qcf4_font_service.dart';
import '../core/services/qvp_page_service.dart';
import '../core/services/offline_audio_service.dart';
import '../core/services/audio_segments_service.dart';
import '../core/services/ml_audio_segments_service.dart';
import '../core/services/ar_ml_alignments_service.dart';
import '../core/services/gemini_alignment_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/timing_report_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden in ProviderScope');
});

final quranDataServiceProvider = Provider<QuranDataService>((ref) {
  return QuranDataService();
});

final qcf4FontServiceProvider = Provider<Qcf4FontService>((ref) {
  return Qcf4FontService();
});

final qvpPageServiceProvider = Provider<QvpPageService>((ref) {
  return QvpPageService();
});

final offlineAudioServiceProvider = Provider<OfflineAudioService>((ref) {
  return OfflineAudioService();
});

final audioSegmentsServiceProvider = Provider<AudioSegmentsService>((ref) {
  return AudioSegmentsService();
});

final geminiAlignmentServiceProvider = Provider<GeminiAlignmentService>((ref) {
  final qds = ref.watch(quranDataServiceProvider);
  final oas = ref.watch(offlineAudioServiceProvider);
  return GeminiAlignmentService(qds, oas);
});

final arMlAlignmentsServiceProvider = Provider<ArMlAlignmentsService>((ref) {
  final qds = ref.watch(quranDataServiceProvider);
  final gas = ref.watch(geminiAlignmentServiceProvider);
  return ArMlAlignmentsService(qds, gas);
});

final mlAudioSegmentsServiceProvider = Provider<MlAudioSegmentsService>((ref) {
  final qds = ref.watch(quranDataServiceProvider);
  final ams = ref.watch(arMlAlignmentsServiceProvider);
  final gas = ref.watch(geminiAlignmentServiceProvider);
  return MlAudioSegmentsService(qds, ams, gas);
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final timingReportServiceProvider = Provider<TimingReportService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return TimingReportService(storage.prefs);
});
