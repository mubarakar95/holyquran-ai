import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/qcf4_models.dart';
import '../../core/models/quran_types.dart';
import '../../core/services/offline_audio_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';

class DownloadManagerScreen extends ConsumerStatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  ConsumerState<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends ConsumerState<DownloadManagerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);
    final downloadNotifier = ref.read(downloadProvider.notifier);

    // Filter surahs by search and status
    final filteredSurahs = <int>[];
    for (int s = 1; s <= 114; s++) {
      final info = SURAH_NAMES[s];
      final query = downloadState.searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchesNum = s.toString() == query;
        final matchesEng = (info?.englishName.toLowerCase().contains(query) ?? false);
        final matchesAr = (info?.name.contains(query) ?? false);
        if (!matchesNum && !matchesEng && !matchesAr) continue;
      }

      final surahDownload = downloadState.surahInfoMap[s];
      final isComplete = surahDownload?.isComplete ?? false;

      if (downloadState.statusFilter == DownloadFilter.downloaded && !isComplete) {
        continue;
      }
      if (downloadState.statusFilter == DownloadFilter.notDownloaded && isComplete) {
        continue;
      }

      filteredSurahs.add(s);
    }

    final totalDownloadedCount = downloadState.downloadedSurahs.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'Offline Audio Manager',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.foreground,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            onPressed: downloadNotifier.refreshStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Storage Overview Card (Zero Horizontal Overflow) ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL AUDIO STORAGE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: colors.muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            _formatBytes(downloadState.totalStorageBytes),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalDownloadedCount / 114 Surahs',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        downloadState.isMalayalam
                            ? 'Malayalam: ${_formatBytes(downloadState.reciterStorageBytes)}'
                            : '${downloadState.selectedReciter.name}: ${_formatBytes(downloadState.reciterStorageBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: colors.muted),
                  color: colors.surface,
                  onSelected: (val) async {
                    if (val == 'clear_current') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: colors.surface,
                          title: const Text('Delete This Audio?'),
                          content: Text(
                            downloadState.isMalayalam
                                ? 'Delete all downloaded Malayalam audio files?'
                                : 'Delete all audio for ${downloadState.selectedReciter.name}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await downloadNotifier.deleteCurrentReciterStorage();
                      }
                    } else if (val == 'clear_all') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: colors.surface,
                          title: const Text('Clear All Offline Audio?'),
                          content: const Text(
                            'This will delete all downloaded audio files across all reciters and Malayalam. You will need network connectivity to listen again.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete All'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await downloadNotifier.clearAllCache();
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'clear_current',
                      child: Text(
                        downloadState.isMalayalam
                            ? 'Clear Malayalam Audio'
                            : 'Clear ${downloadState.selectedReciter.name} Audio',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Text(
                        'Clear All Audio Storage',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Language Selector (Arabic Reciter vs Malayalam) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Arabic Recitation', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.record_voice_over_rounded, size: 15),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Malayalam Audio', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.translate_rounded, size: 15),
                      ),
                    ],
                    selected: {downloadState.isMalayalam},
                    onSelectionChanged: (set) {
                      downloadNotifier.toggleMalayalam(set.first);
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colors.accent,
                      selectedForegroundColor: Colors.white,
                      backgroundColor: colors.surface,
                      foregroundColor: colors.foreground,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Reciter Dropdown (when Arabic selected - Overflow Protected) ──
          if (!downloadState.isMalayalam) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Reciter>(
                    value: downloadState.selectedReciter,
                    isExpanded: true,
                    dropdownColor: colors.surface,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: RECITERS.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              r.arabicName,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 13,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (r) {
                      if (r != null) downloadNotifier.selectReciter(r);
                    },
                  ),
                ),
              ),
            ),
          ],

          // ── Batch Download Bar (Overflow Protected) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: downloadState.isBatchDownloading
                      ? colors.accent.withValues(alpha: 0.5)
                      : colors.border,
                ),
              ),
              child: downloadState.isBatchDownloading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Downloading Surah ${downloadState.downloadingSurah ?? ''} (${downloadState.batchCompletedSurahs}/${downloadState.batchTotalSurahs})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: downloadNotifier.cancelDownload,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Cancel Batch', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: downloadState.totalProgress > 0
                                ? downloadState.currentProgress / downloadState.totalProgress
                                : null,
                            minHeight: 4,
                            backgroundColor: colors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ayah ${downloadState.currentProgress} of ${downloadState.totalProgress}',
                          style: TextStyle(fontSize: 10, color: colors.muted),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Download Full Quran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.foreground,
                                ),
                              ),
                              Text(
                                totalDownloadedCount == 114
                                    ? 'All 114 surahs are offline'
                                    : '${114 - totalDownloadedCount} surahs pending',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: colors.muted),
                              ),
                            ],
                          ),
                        ),
                        if (totalDownloadedCount < 114) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: downloadState.downloadingSurah != null
                                ? null
                                : downloadNotifier.downloadAllSurahs,
                            icon: const Icon(Icons.cloud_download_rounded, size: 15),
                            label: const Text('Download All', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          // ── Search & Filter Chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: downloadNotifier.setSearchQuery,
                      style: TextStyle(fontSize: 13, color: colors.foreground),
                      decoration: InputDecoration(
                        hintText: 'Search surah...',
                        hintStyle: TextStyle(fontSize: 12, color: colors.muted),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.muted),
                        suffixIcon: downloadState.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  downloadNotifier.setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<DownloadFilter>(
                    value: downloadState.statusFilter,
                    dropdownColor: colors.surface,
                    style: TextStyle(fontSize: 12, color: colors.foreground),
                    items: const [
                      DropdownMenuItem(
                        value: DownloadFilter.all,
                        child: Text('All (114)'),
                      ),
                      DropdownMenuItem(
                        value: DownloadFilter.downloaded,
                        child: Text('Offline'),
                      ),
                      DropdownMenuItem(
                        value: DownloadFilter.notDownloaded,
                        child: Text('Pending'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) downloadNotifier.setStatusFilter(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Error Banner if any ──
          if (downloadState.errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      downloadState.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),

          // ── 114 Surahs List with Download Status & Size (Zero Overflow) ──
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: filteredSurahs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final surahNum = filteredSurahs[idx];
                final info = SURAH_NAMES[surahNum];
                final ayahCount = SURAH_AYAH_COUNTS[surahNum - 1];

                final surahDownload = downloadState.surahInfoMap[surahNum];
                final isComplete = surahDownload?.isComplete ?? false;
                final isPartial = surahDownload?.isPartial ?? false;
                final downloadedBytes = surahDownload?.totalBytes ?? 0;
                final isDownloading = downloadState.downloadingSurah == surahNum;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isComplete
                          ? colors.accent.withValues(alpha: 0.35)
                          : isDownloading
                              ? colors.accent
                              : colors.border,
                      width: isDownloading ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Surah Number Badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? colors.accent.withValues(alpha: 0.15)
                              : colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isComplete
                                ? colors.accent.withValues(alpha: 0.4)
                                : colors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$surahNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isComplete ? colors.accent : colors.foreground,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Surah Name info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    info?.englishName ?? 'Surah $surahNum',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($ayahCount)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  info?.name ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 13,
                                    color: colors.muted,
                                  ),
                                ),
                                if (isComplete && downloadedBytes > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${_formatBytes(downloadedBytes)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: colors.accent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Action Button (Downloading / Completed / Partial / Download)
                      if (isDownloading) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                value: downloadState.totalProgress > 0
                                    ? downloadState.currentProgress / downloadState.totalProgress
                                    : null,
                                strokeWidth: 2.0,
                                color: colors.accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${downloadState.currentProgress}/$ayahCount',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                              ),
                            ),
                            IconButton(
                              onPressed: downloadNotifier.cancelDownload,
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: Colors.red,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Cancel download',
                            ),
                          ],
                        ),
                      ] else if (isComplete) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 13, color: colors.accent),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Offline',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => downloadNotifier.deleteSurah(surahNum),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              color: colors.muted,
                              padding: const EdgeInsets.only(left: 6),
                              constraints: const BoxConstraints(),
                              tooltip: 'Delete offline audio',
                            ),
                          ],
                        ),
                      ] else if (isPartial) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => downloadNotifier.downloadSurah(surahNum),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.amber.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Resume (${surahDownload?.downloadedCount}/$ayahCount)',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: () => downloadNotifier.deleteSurah(surahNum),
                              icon: const Icon(Icons.delete_outline_rounded, size: 15),
                              color: colors.muted,
                              padding: const EdgeInsets.only(left: 4),
                              constraints: const BoxConstraints(),
                              tooltip: 'Delete partial audio',
                            ),
                          ],
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => downloadNotifier.downloadSurah(surahNum),
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text('Download', style: TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.background,
                            foregroundColor: colors.foreground,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: colors.border),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
