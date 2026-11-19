import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/vocabulary_models.dart';
import '../../core/models/qcf4_models.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vocabulary_provider.dart';
import 'flashcard_game_screen.dart';
import 'quiz_screen.dart';

class LearnVocabularyScreen extends ConsumerWidget {
  const LearnVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabState = ref.watch(vocabularyProvider);
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    final vocabNotifier = ref.read(vocabularyProvider.notifier);

    if (vocabState.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Learn Vocabulary'),
          backgroundColor: colors.surface,
          foregroundColor: colors.foreground,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF059669)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Learn Vocabulary'),
        backgroundColor: colors.surface,
        foregroundColor: colors.foreground,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scope Selector Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Learning Scope',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Scope Type Selector
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ScopeType>(
                            value: vocabState.scopeType,
                            dropdownColor: colors.surface,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.foreground),
                            items: const [
                              DropdownMenuItem(value: ScopeType.surah, child: Text('Surah')),
                              DropdownMenuItem(value: ScopeType.juz, child: Text('Juz')),
                              DropdownMenuItem(value: ScopeType.page, child: Text('Page')),
                              DropdownMenuItem(value: ScopeType.all, child: Text('All Words')),
                            ],
                            onChanged: (newType) {
                              if (newType != null) {
                                vocabNotifier.setScope(newType, newType == ScopeType.all ? 0 : 1);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Scope Value Selector
                    if (vocabState.scopeType != ScopeType.all)
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: vocabState.scopeValue,
                              dropdownColor: colors.surface,
                              isExpanded: true,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.foreground),
                              items: vocabState.scopeType == ScopeType.surah
                                  ? List.generate(114, (idx) {
                                      final sNum = idx + 1;
                                      final sName = SURAH_NAMES[sNum]?.englishName ?? 'Surah $sNum';
                                      return DropdownMenuItem(
                                        value: sNum,
                                        child: Text('$sNum. $sName'),
                                      );
                                    })
                                  : vocabState.scopeType == ScopeType.juz
                                      ? List.generate(30, (idx) {
                                          final jNum = idx + 1;
                                          return DropdownMenuItem(
                                            value: jNum,
                                            child: Text('Juz $jNum'),
                                          );
                                        })
                                      : List.generate(604, (idx) {
                                          final pNum = idx + 1;
                                          return DropdownMenuItem(
                                            value: pNum,
                                            child: Text('Page $pNum'),
                                          );
                                        }),
                              onChanged: (newVal) {
                                if (newVal != null) {
                                  vocabNotifier.setScope(vocabState.scopeType, newVal);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Overview Statistics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vocabulary Progress',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.foreground),
                    ),
                    Text(
                      '${vocabState.stats.total} total words',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatPill('Mastered', '${vocabState.stats.mastered}', Colors.green, colors),
                    const SizedBox(width: 8),
                    _buildStatPill('Learned', '${vocabState.stats.learned}', Colors.blue, colors),
                    const SizedBox(width: 8),
                    _buildStatPill('Learning', '${vocabState.stats.learning}', Colors.orange, colors),
                    const SizedBox(width: 8),
                    _buildStatPill('New', '${vocabState.stats.newWords}', colors.muted, colors),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Games Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: vocabState.filteredWords.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FlashcardGameScreen()),
                          );
                        },
                  icon: const Icon(Icons.style_rounded, size: 18),
                  label: const Text('Flashcards'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vocabState.filteredWords.length < 4
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QuizScreen()),
                          );
                        },
                  icon: const Icon(Icons.quiz_rounded, size: 18),
                  label: const Text('Start Quiz'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accent,
                    side: BorderSide(color: colors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Surah Mastery Overview Section
          Text(
            'Surah Mastery (114 Surahs)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.foreground),
          ),
          const SizedBox(height: 10),

          ...vocabState.surahMastery.map((m) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${m.number}. ${m.englishName}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.foreground),
                      ),
                      Text(
                        '${m.mastered}/${m.total} mastered',
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: m.percent,
                      minHeight: 6,
                      backgroundColor: colors.background,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String count, Color accentColor, AppColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
