import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/mushtabihat_provider.dart';
import '../../providers/settings_provider.dart';

class MushtabihatScreen extends ConsumerStatefulWidget {
  const MushtabihatScreen({super.key});

  @override
  ConsumerState<MushtabihatScreen> createState() => _MushtabihatScreenState();
}

class _MushtabihatScreenState extends ConsumerState<MushtabihatScreen> {
  int _activeTab = 0; // 0: Quiz, 1: Saved, 2: Hidden, 3: Discover Search
  int _quizIndex = 0;
  bool _revealed = false;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await ref.read(mushtabihatProvider.notifier).searchQuranText(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mushtState = ref.watch(mushtabihatProvider);
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    final mushtNotifier = ref.read(mushtabihatProvider.notifier);

    if (mushtState.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Mushtabihat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Mushtabihat (Similar Verses)'),
        backgroundColor: colors.surface,
        foregroundColor: colors.foreground,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildTabPill('Quiz', 0, colors),
                const SizedBox(width: 6),
                _buildTabPill('Saved (${mushtState.bookmarks.length})', 1, colors),
                const SizedBox(width: 6),
                _buildTabPill('Hidden (${mushtState.hidden.length})', 2, colors),
                const SizedBox(width: 6),
                _buildTabPill('Discover', 3, colors),
              ],
            ),
          ),
        ),
      ),
      body: _activeTab == 0
          ? _buildQuizView(context, colors, mushtState, mushtNotifier)
          : _activeTab == 1
              ? _buildSavedView(context, colors, mushtState, mushtNotifier)
              : _activeTab == 2
                  ? _buildHiddenView(context, colors, mushtState, mushtNotifier)
                  : _buildDiscoverView(context, colors),
    );
  }

  Widget _buildTabPill(String label, int index, AppColors colors) {
    final isSel = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
            if (index == 0) {
              ref.read(mushtabihatProvider.notifier).startQuiz();
              _quizIndex = 0;
              _revealed = false;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? colors.foreground : colors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSel ? colors.foreground : colors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? colors.background : colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizView(
    BuildContext context,
    AppColors colors,
    MushtabihatState state,
    MushtabihatNotifier notifier,
  ) {
    if (state.quizPairs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Select Juz Range for Revision:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.foreground),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Juz ${state.startJuz}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.accent)),
                RangeSlider(
                  values: RangeValues(state.startJuz.toDouble(), state.endJuz.toDouble()),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: colors.accent,
                  onChanged: (vals) {
                    notifier.setJuzRange(vals.start.toInt(), vals.end.toInt());
                  },
                ),
                Text('Juz ${state.endJuz}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.accent)),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: notifier.startQuiz,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Similar Verses Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final currentPair = state.quizPairs[_quizIndex];
    final isBookmarked = state.bookmarks.contains(currentPair.pairKey);

    return Column(
      children: [
        // Top Toolbar (Counter, Bookmark, Hide)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pair ${_quizIndex + 1} of ${state.quizPairs.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.muted),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => notifier.toggleBookmark(currentPair),
                    icon: Icon(
                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: isBookmarked ? colors.accent : colors.muted,
                    ),
                  ),
                  IconButton(
                    onPressed: () => notifier.toggleHidden(currentPair),
                    icon: const Icon(Icons.visibility_off_outlined),
                    color: colors.muted,
                    tooltip: 'Hide pair',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Verses comparison card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Ayah 1
                  _buildAyahCard(
                    title: 'Ayah 1 (${currentPair.ayah1})',
                    juz: currentPair.juz1,
                    verseKey: currentPair.ayah1,
                    colors: colors,
                  ),

                  const SizedBox(height: 16),

                  // Ayah 2
                  if (_revealed)
                    _buildAyahCard(
                      title: 'Ayah 2 (${currentPair.ayah2})',
                      juz: currentPair.juz2,
                      verseKey: currentPair.ayah2,
                      note: currentPair.note,
                      colors: colors,
                      isRevealed: true,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.help_outline_rounded, size: 40, color: colors.muted),
                          const SizedBox(height: 12),
                          Text(
                            'Can you recall the similar verse?',
                            style: TextStyle(fontSize: 13, color: colors.muted),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() => _revealed = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Reveal Matching Verse'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Next / Previous Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _quizIndex > 0
                    ? () {
                        setState(() {
                          _quizIndex--;
                          _revealed = false;
                        });
                      }
                    : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              IconButton(
                onPressed: _quizIndex + 1 < state.quizPairs.length
                    ? () {
                        setState(() {
                          _quizIndex++;
                          _revealed = false;
                        });
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAyahCard({
    required String title,
    required int juz,
    required String verseKey,
    String? note,
    required AppColors colors,
    bool isRevealed = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.accent)),
              Text('Juz $juz', style: TextStyle(fontSize: 11, color: colors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Verse: $verseKey',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.foreground),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                note,
                style: TextStyle(fontSize: 12, color: colors.muted, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedView(
    BuildContext context,
    AppColors colors,
    MushtabihatState state,
    MushtabihatNotifier notifier,
  ) {
    final bookmarkedPairs = state.allPairs.where((p) => state.bookmarks.contains(p.pairKey)).toList();
    if (bookmarkedPairs.isEmpty) {
      return Center(
        child: Text('No bookmarked verse pairs yet', style: TextStyle(color: colors.muted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarkedPairs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final pair = bookmarkedPairs[idx];
        return ListTile(
          tileColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('${pair.ayah1} ↔ ${pair.ayah2}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Category: ${pair.category} • Juz ${pair.juz1} & ${pair.juz2}'),
          trailing: IconButton(
            icon: const Icon(Icons.bookmark_remove_rounded, color: Colors.red),
            onPressed: () => notifier.toggleBookmark(pair),
          ),
        );
      },
    );
  }

  Widget _buildHiddenView(
    BuildContext context,
    AppColors colors,
    MushtabihatState state,
    MushtabihatNotifier notifier,
  ) {
    final hiddenPairs = state.allPairs.where((p) => state.hidden.contains(p.pairKey)).toList();
    if (hiddenPairs.isEmpty) {
      return Center(
        child: Text('No hidden pairs', style: TextStyle(color: colors.muted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: hiddenPairs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final pair = hiddenPairs[idx];
        return ListTile(
          tileColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('${pair.ayah1} ↔ ${pair.ayah2}'),
          trailing: TextButton(
            onPressed: () => notifier.toggleHidden(pair),
            child: const Text('Unhide'),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverView(BuildContext context, AppColors colors) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'Search Arabic phrase (e.g. إِنَّ الَّذِينَ كَفَرُوا)',
              hintTextDirection: TextDirection.rtl,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: _onSearch,
          ),
        ),
        if (_isSearching)
          const Center(child: CircularProgressIndicator())
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final item = _searchResults[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ayah ${item['verseKey']}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.accent),
                      ),
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          item['text'],
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 18,
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
