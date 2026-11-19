class TimingReport {
  final int surahNumber;
  final int ayahNumber;
  final String issueType;
  final String? note;
  final String status; // 'pending' | 'resolved'
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? appVersion;

  const TimingReport({
    required this.surahNumber,
    required this.ayahNumber,
    this.issueType = 'timing_mismatch',
    this.note,
    this.status = 'pending',
    required this.reportedAt,
    this.resolvedAt,
    this.appVersion,
  });

  String get verseKey => '$surahNumber:$ayahNumber';

  Map<String, dynamic> toJson() => {
    'surah_number': surahNumber,
    'ayah_number': ayahNumber,
    'issue_type': issueType,
    'note': note ?? '',
    'status': status,
    'reported_at': reportedAt.toUtc().toIso8601String(),
    if (resolvedAt != null) 'resolved_at': resolvedAt!.toUtc().toIso8601String(),
    'app_version': appVersion ?? '1.0.0+8',
  };

  factory TimingReport.fromJson(Map<String, dynamic> json) {
    return TimingReport(
      surahNumber: json['surah_number'] as int? ?? 0,
      ayahNumber: json['ayah_number'] as int? ?? 0,
      issueType: json['issue_type'] as String? ?? 'timing_mismatch',
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'pending',
      reportedAt: DateTime.tryParse(json['reported_at'] as String? ?? '') ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
      appVersion: json['app_version'] as String?,
    );
  }
}
