import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/vocabulary_models.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vocabulary_provider.dart';

class QuizQuestion {
  final VocabularyWord word;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.word,
    required this.options,
    required this.correctIndex,
  });
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedOption;
  int _score = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  void _generateQuestions() {
    final vocabState = ref.read(vocabularyProvider);
    final words = List<VocabularyWord>.from(vocabState.filteredWords);
    if (words.length < 4) {
      setState(() => _isLoading = false);
      return;
    }

    words.shuffle();
    final questionWords = words.take(15).toList();

    final questions = <QuizQuestion>[];
    for (final word in questionWords) {
      final otherWords = words.where((w) => w.malayalam != word.malayalam).toList()..shuffle();
      final distractors = otherWords.take(3).map((w) => w.malayalam).toList();
      final options = [word.malayalam, ...distractors]..shuffle();

      questions.add(QuizQuestion(
        word: word,
        options: options,
        correctIndex: options.indexOf(word.malayalam),
      ));
    }

    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _handleSelectOption(int index) {
    if (_selectedOption != null) return;

    setState(() {
      _selectedOption = index;
    });

    final currentQ = _questions[_currentIndex];
    final isCorrect = index == currentQ.correctIndex;

    if (isCorrect) {
      _score++;
      ref.read(vocabularyProvider.notifier).markMastered(currentQ.word.arabic);
    } else {
      ref.read(vocabularyProvider.notifier).recordAnswer(currentQ.word.arabic, false);
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentIndex + 1 < _questions.length) {
        setState(() {
          _currentIndex++;
          _selectedOption = null;
        });
      } else {
        setState(() {
          _currentIndex++;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Vocabulary Quiz'),
          backgroundColor: colors.surface,
          foregroundColor: colors.foreground,
        ),
        body: Center(
          child: Text(
            'Need at least 4 words in this scope to start a quiz',
            style: TextStyle(color: colors.muted),
          ),
        ),
      );
    }

    final isFinished = _currentIndex >= _questions.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Vocabulary Quiz'),
        backgroundColor: colors.surface,
        foregroundColor: colors.foreground,
      ),
      body: SafeArea(
        child: isFinished
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, size: 72, color: colors.accent),
                      const SizedBox(height: 16),
                      Text(
                        'Quiz Finished!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score: $_score / ${_questions.length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Back to Vocabulary'),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} of ${_questions.length}',
                          style: TextStyle(fontSize: 13, color: colors.muted, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Score: $_score',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.accent),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Arabic Word Display
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Center(
                        child: Text(
                          _questions[_currentIndex].word.arabic,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 4 Options
                    ...List.generate(_questions[_currentIndex].options.length, (optIdx) {
                      final optionText = _questions[_currentIndex].options[optIdx];
                      final isSelected = _selectedOption == optIdx;
                      final isCorrect = optIdx == _questions[_currentIndex].correctIndex;

                      Color tileBg = colors.surface;
                      Color borderColor = colors.border;
                      Color textColor = colors.foreground;

                      if (_selectedOption != null) {
                        if (isCorrect) {
                          tileBg = colors.accent.withValues(alpha: 0.15);
                          borderColor = colors.accent;
                          textColor = colors.accent;
                        } else if (isSelected) {
                          tileBg = Colors.red.withValues(alpha: 0.15);
                          borderColor = Colors.red;
                          textColor = Colors.red;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _handleSelectOption(optIdx),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: tileBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: isSelected || (_selectedOption != null && isCorrect) ? 2 : 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + optIdx),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    optionText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}
