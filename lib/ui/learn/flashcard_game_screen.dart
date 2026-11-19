import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/vocabulary_models.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vocabulary_provider.dart';

class FlashcardGameScreen extends ConsumerStatefulWidget {
  const FlashcardGameScreen({super.key});

  @override
  ConsumerState<FlashcardGameScreen> createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends ConsumerState<FlashcardGameScreen> with SingleTickerProviderStateMixin {
  late List<VocabularyWord> _queue;
  int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  int _knownCount = 0;
  int _learningCount = 0;

  @override
  void initState() {
    super.initState();
    final vocabState = ref.read(vocabularyProvider);
    _queue = List<VocabularyWord>.from(vocabState.filteredWords);
    _queue.shuffle();
    if (_queue.length > 50) _queue = _queue.sublist(0, 50);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _handleAnswer(bool isKnown) {
    if (_currentIndex >= _queue.length) return;
    final currentWord = _queue[_currentIndex];

    ref.read(vocabularyProvider.notifier).recordAnswer(currentWord.arabic, isKnown);

    if (isKnown) {
      _knownCount++;
    } else {
      _learningCount++;
    }

    if (_currentIndex + 1 < _queue.length) {
      if (_isFlipped) {
        _flipController.reverse();
        _isFlipped = false;
      }
      setState(() {
        _currentIndex++;
      });
    } else {
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);

    final isFinished = _currentIndex >= _queue.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Flashcards'),
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
                      Icon(Icons.emoji_events_rounded, size: 64, color: colors.accent),
                      const SizedBox(height: 16),
                      Text(
                        'Session Complete!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_knownCount Known • $_learningCount Still Learning',
                        style: TextStyle(fontSize: 14, color: colors.muted),
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
            : Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Word ${_currentIndex + 1} of ${_queue.length}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.muted),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '✓ $_knownCount',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.accent),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '↺ $_learningCount',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Flippable Flashcard
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _flipCard,
                        child: AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final angle = _flipAnimation.value * pi;
                            final isUnder = angle > pi / 2;

                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              child: Container(
                                width: min(340, MediaQuery.of(context).size.width - 48),
                                height: 320,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isUnder
                                      ? Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()..rotateY(pi),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _queue[_currentIndex].malayalam,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.foreground,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Tap to flip back',
                                                style: TextStyle(fontSize: 11, color: colors.muted),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _queue[_currentIndex].arabic,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: 'Amiri',
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: colors.foreground,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Tap to reveal meaning',
                                              style: TextStyle(fontSize: 11, color: colors.muted),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleAnswer(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Still Learning'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAnswer(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('I Know It'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
