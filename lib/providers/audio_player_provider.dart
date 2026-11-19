import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../core/models/quran_types.dart';
import '../core/services/offline_audio_service.dart';
import '../core/services/ml_audio_segments_service.dart';
import 'service_providers.dart';
import 'quran_page_provider.dart';
import 'settings_provider.dart';
import 'gemini_toast_provider.dart';

class AudioPlayerState {
  final bool isPlaying;
  final bool isBuffering;
  final Reciter reciter;
  final AudioMode audioMode;
  final QuranRepeatMode repeatMode;
  final double arabicPlaybackRate;
  final double malayalamPlaybackRate;
  final String? currentVerseKey;
  final int currentAyahIndex;
  final Duration position;
  final Duration duration;
  final bool audioVisible;
  final bool segmentedMode;
  final int currentClauseIndex;
  final int totalClauses;
  final ClausePhase clausePhase;

  const AudioPlayerState({
    required this.isPlaying,
    required this.isBuffering,
    required this.reciter,
    required this.audioMode,
    required this.repeatMode,
    required this.arabicPlaybackRate,
    required this.malayalamPlaybackRate,
    this.currentVerseKey,
    this.currentAyahIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.audioVisible = true,
    this.segmentedMode = true,
    this.currentClauseIndex = 0,
    this.totalClauses = 1,
    this.clausePhase = ClausePhase.ml,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    Reciter? reciter,
    AudioMode? audioMode,
    QuranRepeatMode? repeatMode,
    double? arabicPlaybackRate,
    double? malayalamPlaybackRate,
    String? Function()? currentVerseKey,
    int? currentAyahIndex,
    Duration? position,
    Duration? duration,
    bool? audioVisible,
    bool? segmentedMode,
    int? currentClauseIndex,
    int? totalClauses,
    ClausePhase? clausePhase,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      reciter: reciter ?? this.reciter,
      audioMode: audioMode ?? this.audioMode,
      repeatMode: repeatMode ?? this.repeatMode,
      arabicPlaybackRate: arabicPlaybackRate ?? this.arabicPlaybackRate,
      malayalamPlaybackRate: malayalamPlaybackRate ?? this.malayalamPlaybackRate,
      currentVerseKey: currentVerseKey != null ? currentVerseKey() : this.currentVerseKey,
      currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      audioVisible: audioVisible ?? this.audioVisible,
      segmentedMode: segmentedMode ?? this.segmentedMode,
      currentClauseIndex: currentClauseIndex ?? this.currentClauseIndex,
      totalClauses: totalClauses ?? this.totalClauses,
      clausePhase: clausePhase ?? this.clausePhase,
    );
  }
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final Ref _ref;
  final AudioPlayer _arPlayer = AudioPlayer();
  final AudioPlayer _mlPlayer = AudioPlayer();

  StreamSubscription? _arStateSub;
  StreamSubscription? _arPosSub;
  StreamSubscription? _arDurSub;

  StreamSubscription? _mlStateSub;
  StreamSubscription? _mlPosSub;
  StreamSubscription? _mlDurSub;

  Timer? _transitionTimer;
  bool _isTransitioning = false;
  bool _pendingAutoPlayFirstAyah = false;

  int _targetArEndMs = 0;
  int _targetMlEndMs = 0;
  List<AyahClause> _currentClauses = [];
  String? _playingVerseKey;
  String? _completedVerseKey;

  List<AyahInfo> _currentAyahs = [];
  List<AyahSegments> _arabicSegments = [];
  Map<String, AyahSegments> _malayalamSegments = {};

  AudioPlayerNotifier(this._ref)
      : super(AudioPlayerState(
          isPlaying: false,
          isBuffering: false,
          reciter: RECITERS.firstWhere(
            (r) => r.id == _ref.read(localStorageServiceProvider).reciterId,
            orElse: () => RECITERS[0],
          ),
          audioMode: AudioMode.values.firstWhere(
            (m) => m.name == _ref.read(localStorageServiceProvider).audioMode,
            orElse: () => AudioMode.arabic,
          ),
          repeatMode: QuranRepeatMode.values.firstWhere(
            (m) => m.name == _ref.read(localStorageServiceProvider).repeatMode,
            orElse: () => QuranRepeatMode.none,
          ),
          arabicPlaybackRate: _ref.read(localStorageServiceProvider).arabicPlaybackRate,
          malayalamPlaybackRate: _ref.read(localStorageServiceProvider).malayalamPlaybackRate,
          segmentedMode: _ref.read(localStorageServiceProvider).segmentedMode,
        )) {
    _initAudioSession();
    _initAudioListeners();
    _initCurrentAyahs();
  }

  void _initCurrentAyahs() {
    final page = _ref.read(localStorageServiceProvider).currentPage;
    _ref.read(qvpPageServiceProvider).getPage(page).then((p) {
      if (p.ayahs.isNotEmpty && _currentAyahs.isEmpty) {
        final seen = <String>{};
        final ayahs = <AyahInfo>[];
        for (final a in p.ayahs) {
          final vk = '${a.surah}:${a.ayah}';
          if (seen.add(vk)) {
            ayahs.add(AyahInfo(
              number: a.ayah,
              text: '',
              numberInSurah: a.ayah,
              juz: 1,
              manzil: 1,
              ruku: 1,
              hizbQuarter: a.rubuAlHizb,
              sajda: false,
              surah: SurahInfo(
                number: a.surah,
                name: '',
                englishName: '',
                englishNameTranslation: '',
                numberOfAyahs: a.ayah,
                revelationType: '',
              ),
            ));
          }
        }
        _currentAyahs = ayahs;
      }
    }).catchError((_) {});
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (e) {
      debugPrint('AudioSession configuration notice: $e');
    }
  }

  void _initAudioListeners() {
    // ── Arabic Player Listeners ──
    _arStateSub = _arPlayer.playerStateStream.listen((ps) {
      final isArActive = state.audioMode == AudioMode.arabic ||
          (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ar);

      if (isArActive) {
        final isPlaying = ps.playing && ps.processingState != ProcessingState.completed;
        final isBuffering = ps.processingState == ProcessingState.buffering ||
            ps.processingState == ProcessingState.loading;
        state = state.copyWith(isPlaying: isPlaying, isBuffering: isBuffering);
      }

      if (ps.processingState == ProcessingState.completed && isArActive) {
        if (state.audioMode == AudioMode.both && state.segmentedMode) {
          final isLastClause = _currentClauses.length <= 1 ||
              state.currentClauseIndex >= _currentClauses.length - 1;
          if (isLastClause) {
            _handleAyahCompleted();
          } else {
            _scheduleTransitionToNextClause(state.currentClauseIndex);
          }
        } else {
          _handleAyahCompleted();
        }
      }
    });

    _arPosSub = _arPlayer.positionStream.listen((pos) {
      final isArActive = state.audioMode == AudioMode.arabic ||
          (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ar);

      if (isArActive) {
        state = state.copyWith(
          position: pos,
          duration: _arPlayer.duration ?? state.duration,
        );
        _handleArabicPositionHighlight(pos);

        if (state.audioMode == AudioMode.both && state.segmentedMode && !_isTransitioning) {
          final isLastClause = _currentClauses.length <= 1 ||
              state.currentClauseIndex >= _currentClauses.length - 1;
          if (!isLastClause && _targetArEndMs > 0 && pos.inMilliseconds >= _targetArEndMs - 80) {
            _arPlayer.pause();
            _scheduleTransitionToNextClause(state.currentClauseIndex);
          }
        }
      }
    });

    _arDurSub = _arPlayer.durationStream.listen((dur) {
      if (state.audioMode == AudioMode.arabic ||
          (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ar)) {
        state = state.copyWith(duration: dur ?? Duration.zero);
      }
    });

    // ── Malayalam Player Listeners ──
    _mlStateSub = _mlPlayer.playerStateStream.listen((ps) {
      final isMlActive = state.audioMode == AudioMode.malayalam ||
          (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ml);

      if (isMlActive) {
        final isPlaying = ps.playing && ps.processingState != ProcessingState.completed;
        final isBuffering = ps.processingState == ProcessingState.buffering ||
            ps.processingState == ProcessingState.loading;
        state = state.copyWith(isPlaying: isPlaying, isBuffering: isBuffering);
      }

      if (ps.processingState == ProcessingState.completed && isMlActive) {
        if (state.audioMode == AudioMode.both) {
          if (state.segmentedMode) {
            _scheduleTransitionToAr(state.currentClauseIndex);
          } else {
            _scheduleTransitionToArFull();
          }
        } else {
          _handleAyahCompleted();
        }
      }
    });

    _mlPosSub = _mlPlayer.positionStream.listen((pos) {
      final isMlActive = state.audioMode == AudioMode.malayalam ||
          (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ml);

      if (isMlActive) {
        state = state.copyWith(
          position: pos,
          duration: _mlPlayer.duration ?? state.duration,
        );
        _handleMalayalamPositionHighlight(pos);

        if (state.audioMode == AudioMode.both && state.segmentedMode && !_isTransitioning) {
          if (_targetMlEndMs > 0 && pos.inMilliseconds >= _targetMlEndMs - 80) {
            _mlPlayer.pause();
            _scheduleTransitionToAr(state.currentClauseIndex);
          }
        }
      }
    });

    _mlDurSub = _mlPlayer.durationStream.listen((dur) {
      if (state.audioMode == AudioMode.malayalam ||
          (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ml)) {
        state = state.copyWith(duration: dur ?? Duration.zero);
      }
    });
  }

  void setAyahs(List<AyahInfo> ayahs) {
    final seen = <String>{};
    final uniqueAyahs = <AyahInfo>[];
    for (final a in ayahs) {
      if (seen.add(a.verseKey)) {
        uniqueAyahs.add(a);
      }
    }
    _currentAyahs = uniqueAyahs;
    if (_pendingAutoPlayFirstAyah && uniqueAyahs.isNotEmpty) {
      _pendingAutoPlayFirstAyah = false;
      playAyah(uniqueAyahs.first.verseKey);
    }
  }

  void setReciter(Reciter reciter) {
    state = state.copyWith(reciter: reciter);
    _ref.read(localStorageServiceProvider).reciterId = reciter.id;
    if (state.isPlaying && state.currentVerseKey != null) {
      playAyah(state.currentVerseKey!);
    }
  }

  void setAudioMode(AudioMode mode) {
    state = state.copyWith(audioMode: mode);
    _ref.read(localStorageServiceProvider).audioMode = mode.name;
    if (state.isPlaying && state.currentVerseKey != null) {
      playAyah(state.currentVerseKey!);
    }
  }

  void toggleSegmentedMode() {
    final next = !state.segmentedMode;
    state = state.copyWith(segmentedMode: next);
    _ref.read(localStorageServiceProvider).segmentedMode = next;
    if (state.isPlaying && state.audioMode == AudioMode.both && state.currentVerseKey != null) {
      playAyah(state.currentVerseKey!);
    }
  }

  void setArabicSpeed(double rate) {
    state = state.copyWith(arabicPlaybackRate: rate);
    _ref.read(localStorageServiceProvider).arabicPlaybackRate = rate;
    _arPlayer.setSpeed(rate);
  }

  void setMalayalamSpeed(double rate) {
    state = state.copyWith(malayalamPlaybackRate: rate);
    _ref.read(localStorageServiceProvider).malayalamPlaybackRate = rate;
    _mlPlayer.setSpeed(rate);
  }

  void setRepeatMode(QuranRepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
    _ref.read(localStorageServiceProvider).repeatMode = mode.name;
  }

  void toggleAudioVisible() {
    state = state.copyWith(audioVisible: !state.audioVisible);
  }

  Future<void> playAyah(String verseKey, {AudioMode? modeOverride, int? initialWordIndex}) async {
    _transitionTimer?.cancel();
    _isTransitioning = false;

    final mode = modeOverride ?? state.audioMode;
    if (modeOverride != null) {
      state = state.copyWith(audioMode: modeOverride);
      _ref.read(localStorageServiceProvider).audioMode = modeOverride.name;
    }

    final parts = verseKey.split(':');
    if (parts.length != 2) return;
    final surahNum = int.parse(parts[0]);
    final ayahNum = int.parse(parts[1]);

    if (_playingVerseKey != verseKey) {
      _completedVerseKey = null;
    }
    _playingVerseKey = verseKey;
    final ayahIdx = _currentAyahs.indexWhere((a) => a.verseKey == verseKey);

    state = state.copyWith(
      currentVerseKey: () => verseKey,
      currentAyahIndex: ayahIdx >= 0 ? ayahIdx : 0,
      currentClauseIndex: 0,
      clausePhase: (mode == AudioMode.arabic) ? ClausePhase.ar : ClausePhase.ml,
    );
    _ref.read(quranPageProvider.notifier).setHighlightVerseKey(verseKey);

    final offlineService = _ref.read(offlineAudioServiceProvider);

    if (mode == AudioMode.arabic) {
      try {
        await _arPlayer.stop();
        await _mlPlayer.stop();
      } catch (_) {}

      // Load Arabic segments if reciter has Quran.com segments
      if (state.reciter.quranComId != null) {
        _ref.read(audioSegmentsServiceProvider)
            .fetchChapterSegments(state.reciter.quranComId!, surahNum)
            .then((res) => _arabicSegments = res)
            .catchError((_) => <AyahSegments>[]);
      }

      try {
        final localPath = await offlineService.getLocalAudioPathIfExists(state.reciter.id, surahNum, ayahNum);
        if (_playingVerseKey != verseKey) return;
        if (localPath != null) {
          await _arPlayer.setFilePath(localPath);
        } else {
          final url = getRemoteAudioUrl(state.reciter, surahNum, ayahNum);
          try {
            await _arPlayer.setUrl(url);
          } catch (e) {
            await _arPlayer.stop();
            await Future.delayed(const Duration(milliseconds: 100));
            if (_playingVerseKey != verseKey) return;
            await _arPlayer.setUrl(url);
          }
          // Cache on-demand in background for future offline playback
          offlineService.cacheAyahAudio(
            reciter: state.reciter,
            reciterKey: state.reciter.id,
            surahNumber: surahNum,
            ayahNumber: ayahNum,
            isMalayalam: false,
          );
        }

        if (_playingVerseKey != verseKey) return;
        await _arPlayer.setSpeed(state.arabicPlaybackRate);
        final initialMs = initialWordIndex != null && initialWordIndex > 0
            ? _resolveArabicWordTimestamp(verseKey, initialWordIndex)
            : 0;
        await _arPlayer.seek(Duration(milliseconds: initialMs));
        await _arPlayer.play();
        if (initialWordIndex != null) {
          _ref.read(quranPageProvider.notifier).setHighlightWord(
            HighlightWord(verseKey: verseKey, wordIndex: initialWordIndex, bundle: false),
          );
        }

        _preCacheNextAyahs(offlineService, mode, surahNum, ayahNum);
      } catch (e) {
        debugPrint('[AudioPlayer] Error playing Arabic audio: $e');
        state = state.copyWith(isBuffering: false, isPlaying: false);
      }
    } else if (mode == AudioMode.malayalam) {
      try {
        await _arPlayer.stop();
        await _mlPlayer.stop();
      } catch (_) {}

      _loadMalayalamSegments(surahNum, ayahNum);

      try {
        final localPath = await offlineService.getLocalAudioPathIfExists('malayalam', surahNum, ayahNum);
        if (_playingVerseKey != verseKey) return;
        if (localPath != null) {
          await _mlPlayer.setFilePath(localPath);
        } else {
          final url = getRemoteMalayalamAudioUrl(surahNum, ayahNum);
          try {
            await _mlPlayer.setUrl(url);
          } catch (e) {
            debugPrint('[AudioPlayer] First setUrl attempt failed ($e), resetting player and retrying...');
            await _mlPlayer.stop();
            await Future.delayed(const Duration(milliseconds: 100));
            if (_playingVerseKey != verseKey) return;
            await _mlPlayer.setUrl(url);
          }
          // Cache on-demand in background for future offline playback
          offlineService.cacheAyahAudio(
            reciter: null,
            reciterKey: 'malayalam',
            surahNumber: surahNum,
            ayahNumber: ayahNum,
            isMalayalam: true,
          );
        }

        if (_playingVerseKey != verseKey) return;
        await _mlPlayer.setSpeed(state.malayalamPlaybackRate);
        final initialMs = initialWordIndex != null && initialWordIndex > 0
            ? _resolveMalayalamWordTimestamp(verseKey, initialWordIndex)
            : 0;
        await _mlPlayer.seek(Duration(milliseconds: initialMs));
        await _mlPlayer.play();
        if (initialWordIndex != null) {
          final ayahSeg = _malayalamSegments[verseKey];
          final clause = ayahSeg?.clauses?.where((c) => c.wordIndices.contains(initialWordIndex)).firstOrNull;
          if (clause != null && clause.wordIndices.isNotEmpty) {
            _ref.read(quranPageProvider.notifier).setHighlightWord(
              HighlightWord(
                verseKey: verseKey,
                wordIndex: clause.wordIndices.first,
                wordIndices: clause.wordIndices,
                bundle: true,
              ),
            );
          } else {
            _ref.read(quranPageProvider.notifier).setHighlightWord(
              HighlightWord(verseKey: verseKey, wordIndex: initialWordIndex, bundle: false),
            );
          }
        }

        _preCacheNextAyahs(offlineService, mode, surahNum, ayahNum);
      } catch (e) {
        debugPrint('[AudioPlayer] Error playing Malayalam audio: $e');
        state = state.copyWith(isBuffering: false, isPlaying: false);
      }
    } else {
      // ══════════════════════════════════════════════════════════════════════
      // AudioMode.both: DUAL AUDIO (Segmented or Full Interleaving)
      // ══════════════════════════════════════════════════════════════════════
      // Preload Arabic in background
      if (state.reciter.quranComId != null) {
        _ref.read(audioSegmentsServiceProvider)
            .fetchChapterSegments(state.reciter.quranComId!, surahNum)
            .then((res) => _arabicSegments = res)
            .catchError((_) => <AyahSegments>[]);
      }

      offlineService.getLocalAudioPathIfExists(state.reciter.id, surahNum, ayahNum).then((arPath) {
        if (_playingVerseKey != verseKey) return;
        try {
          if (arPath != null) {
            _arPlayer.setFilePath(arPath);
          } else {
            _arPlayer.setUrl(getRemoteAudioUrl(state.reciter, surahNum, ayahNum));
            offlineService.cacheAyahAudio(
              reciter: state.reciter,
              reciterKey: state.reciter.id,
              surahNumber: surahNum,
              ayahNumber: ayahNum,
              isMalayalam: false,
            );
          }
          _arPlayer.setSpeed(state.arabicPlaybackRate);
        } catch (_) {}
      });

      // Prepare Malayalam
      try {
        final mlLocalPath = await offlineService.getLocalAudioPathIfExists('malayalam', surahNum, ayahNum);
        if (_playingVerseKey != verseKey) return;
        if (mlLocalPath != null) {
          await _mlPlayer.setFilePath(mlLocalPath);
        } else {
          final url = getRemoteMalayalamAudioUrl(surahNum, ayahNum);
          await _mlPlayer.setUrl(url);
          offlineService.cacheAyahAudio(
            reciter: null,
            reciterKey: 'malayalam',
            surahNumber: surahNum,
            ayahNumber: ayahNum,
            isMalayalam: true,
          );
        }
        if (_playingVerseKey != verseKey) return;
        await _mlPlayer.setSpeed(state.malayalamPlaybackRate);
      } catch (e) {
        debugPrint('[AudioPlayer] Error preparing Malayalam audio in dual mode: $e');
      }

      _preCacheNextAyahs(offlineService, mode, surahNum, ayahNum);

      if (state.segmentedMode) {
        _currentClauses = [AyahClause(startMs: 0, endMs: 999999, wordIndices: const [])];
        final initialClause = initialWordIndex != null
            ? (_findClauseIndexForWord(initialWordIndex) ?? 0)
            : 0;
        state = state.copyWith(totalClauses: 1, currentClauseIndex: initialClause, clausePhase: ClausePhase.ml);

        _loadMalayalamSegments(surahNum, ayahNum, onReady: (ayahSeg) {
          if (_playingVerseKey != verseKey) return;
          final ayah = _currentAyahs.where((a) => a.verseKey == verseKey).firstOrNull;
          final extracted = (ayahSeg.clauses != null && ayahSeg.clauses!.isNotEmpty)
              ? ayahSeg.clauses!
              : extractAyahClauses(verseKey, ayahSeg.segments, arabicText: ayah?.text);
          final durMs = _mlPlayer.duration?.inMilliseconds;
          final sanitized = sanitizeClauses(extracted, durMs);
          _currentClauses = sanitized;
          state = state.copyWith(totalClauses: sanitized.length);

          final resolvedClause = initialWordIndex != null
              ? (_findClauseIndexForWord(initialWordIndex) ?? 0)
              : state.currentClauseIndex;

          if (state.clausePhase == ClausePhase.ml && resolvedClause < sanitized.length) {
            final c = sanitized[resolvedClause];
            _targetMlEndMs = (resolvedClause == sanitized.length - 1 && durMs != null && durMs > 0)
                ? durMs
                : c.endMs;
            if (c.wordIndices.isNotEmpty) {
              _ref.read(quranPageProvider.notifier).setHighlightWord(
                HighlightWord(
                  verseKey: verseKey,
                  wordIndex: c.wordIndices.first,
                  wordIndices: c.wordIndices,
                  bundle: true,
                ),
              );
            }
          }
        });

        _playMalayalamClause(initialClause);
      } else {
        state = state.copyWith(totalClauses: 1, currentClauseIndex: 0, clausePhase: ClausePhase.ml);
        _loadMalayalamSegments(surahNum, ayahNum);
        try {
          await _mlPlayer.play();
        } catch (e) {
          debugPrint('[AudioPlayer] Error starting full playback in dual mode: $e');
        }
      }
    }
  }

  void _loadMalayalamSegments(int surahNum, int ayahNum, {void Function(AyahSegments)? onReady}) {
    final pageNum = _ref.read(quranPageProvider).currentPage;
    final geminiKey = _ref.read(settingsProvider).geminiApiKey;
    final vk = '$surahNum:$ayahNum';

    // If already in memory cache, return immediately
    final cached = _malayalamSegments[vk];
    if (cached != null) {
      if (onReady != null) onReady(cached);
      return;
    }

    // In Malayalam-only mode without segmentation, linear playback doesn't need AI generation
    if (state.audioMode == AudioMode.malayalam && !state.segmentedMode) {
      return;
    }

    _ref.read(mlAudioSegmentsServiceProvider)
        .fetchPageSegments(
          pageNum,
          _currentAyahs.map((a) => a.verseKey).toList(),
          targetVerseKey: vk,
          geminiApiKey: geminiKey,
          onToast: (toast) {
            _ref.read(geminiToastProvider.notifier).emit(toast);
          },
        )
        .then((res) {
          _malayalamSegments = res;
          final vk = '$surahNum:$ayahNum';
          final ayahSeg = res[vk];
          if (ayahSeg != null && onReady != null) {
            onReady(ayahSeg);
          }

          // Immediately update highlight if playback already started
          if (state.isPlaying &&
              (state.audioMode == AudioMode.malayalam ||
                  (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ml))) {
            _handleMalayalamPositionHighlight(_mlPlayer.position);
          }
        })
        .catchError((e) {
          debugPrint('Failed to load Malayalam segments: $e');
        });
  }

  void _scheduleTransitionToAr(int cIdx) {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _transitionTimer?.cancel();
    _mlPlayer.pause();
    _ref.read(quranPageProvider.notifier).setHighlightWord(null);

    _transitionTimer = Timer(const Duration(milliseconds: 220), () {
      _isTransitioning = false;
      _playArabicClause(cIdx);
    });
  }

  Future<void> _playArabicClause(int cIdx) async {
    if (_playingVerseKey == null) return;
    final vk = _playingVerseKey!;
    state = state.copyWith(currentClauseIndex: cIdx, clausePhase: ClausePhase.ar);

    final clause = cIdx < _currentClauses.length ? _currentClauses[cIdx] : null;
    final isLastClause = _currentClauses.length <= 1 || cIdx >= _currentClauses.length - 1;

    final ayah = _currentAyahs.where((a) => a.verseKey == vk).firstOrNull;
    final totalWords = ayah != null && ayah.text.isNotEmpty
        ? ayah.text.trim().split(RegExp(r'\s+')).length
        : 0;

    final arDurationSec = (_arPlayer.duration?.inMilliseconds ?? 0) / 1000.0;

    int startMs = 0;
    int endMs = _arPlayer.duration?.inMilliseconds ?? 999999;

    if (state.segmentedMode && _currentClauses.length > 1 && clause != null) {
      final timings = _ref.read(audioSegmentsServiceProvider).getArabicClauseTimings(
        verseKey: vk,
        wordIndices: clause.wordIndices,
        reciterSegments: _arabicSegments,
        arabicAudioDurationSec: arDurationSec,
        totalWordsInAyah: totalWords,
      );
      startMs = timings.arStartMs;
      endMs = (isLastClause && _arPlayer.duration != null && _arPlayer.duration!.inMilliseconds > 0)
          ? _arPlayer.duration!.inMilliseconds
          : timings.arEndMs;
    }

    _targetArEndMs = endMs;

    try {
      await _arPlayer.seek(Duration(milliseconds: startMs));
      await _arPlayer.play();
    } catch (e) {
      debugPrint('[AudioPlayer] Error playing Arabic clause: $e');
    }
  }

  void _scheduleTransitionToNextClause(int cIdx) {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _transitionTimer?.cancel();
    _arPlayer.pause();
    _ref.read(quranPageProvider.notifier).setHighlightWord(null);

    final nextIdx = cIdx + 1;
    if (nextIdx >= _currentClauses.length) {
      _isTransitioning = false;
      _handleAyahCompleted();
      return;
    }

    _transitionTimer = Timer(const Duration(milliseconds: 250), () {
      _isTransitioning = false;
      _playMalayalamClause(nextIdx);
    });
  }

  Future<void> _playMalayalamClause(int cIdx) async {
    if (_playingVerseKey == null) return;
    state = state.copyWith(currentClauseIndex: cIdx, clausePhase: ClausePhase.ml);

    final clause = cIdx < _currentClauses.length ? _currentClauses[cIdx] : null;
    int startMs = 0;

    if (state.segmentedMode && _currentClauses.length > 1 && clause != null) {
      if (cIdx > 0 && _currentClauses[cIdx - 1].endMs > 0) {
        final minStartMs = _currentClauses[cIdx - 1].endMs;
        startMs = max(clause.startMs, minStartMs);
      } else {
        startMs = clause.startMs;
      }
    }

    final isLastClause = _currentClauses.length <= 1 || cIdx >= _currentClauses.length - 1;
    _targetMlEndMs = (isLastClause && _mlPlayer.duration != null && _mlPlayer.duration!.inMilliseconds > 0)
        ? _mlPlayer.duration!.inMilliseconds
        : (clause != null ? clause.endMs : 999999);

    try {
      await _mlPlayer.seek(Duration(milliseconds: startMs));

      if (clause != null && clause.wordIndices.isNotEmpty) {
        _ref.read(quranPageProvider.notifier).setHighlightWord(
          HighlightWord(
            verseKey: _playingVerseKey!,
            wordIndex: clause.wordIndices.first,
            wordIndices: clause.wordIndices,
            bundle: true,
          ),
        );
      }

      await _mlPlayer.play();
    } catch (e) {
      debugPrint('[AudioPlayer] Error playing Malayalam clause: $e');
    }
  }

  void _scheduleTransitionToArFull() {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _transitionTimer?.cancel();
    _mlPlayer.pause();
    _ref.read(quranPageProvider.notifier).setHighlightWord(null);

    _transitionTimer = Timer(const Duration(milliseconds: 220), () {
      _isTransitioning = false;
      state = state.copyWith(clausePhase: ClausePhase.ar);
      _arPlayer.seek(Duration.zero);
      _arPlayer.play();
    });
  }

  void seek(Duration pos) {
    if (state.audioMode == AudioMode.malayalam ||
        (state.audioMode == AudioMode.both && state.clausePhase == ClausePhase.ml)) {
      _mlPlayer.seek(pos);
    } else {
      _arPlayer.seek(pos);
    }
  }

  int _resolveArabicWordTimestamp(String verseKey, int wordIndex) {
    if (wordIndex <= 0) return 0;

    // 1. Check loaded chapter segments
    final ayahSeg = _arabicSegments.where((s) => s.verseKey == verseKey).firstOrNull;
    if (ayahSeg != null && ayahSeg.segments.isNotEmpty) {
      final startMs = _ref.read(audioSegmentsServiceProvider).findWordStartMs([ayahSeg], verseKey, wordIndex);
      if (startMs != null) return startMs;
    }

    // 2. Check service memory cache
    final parts = verseKey.split(':');
    if (parts.length == 2 && state.reciter.quranComId != null) {
      final surahNum = int.tryParse(parts[0]);
      if (surahNum != null) {
        final cached = _ref.read(audioSegmentsServiceProvider).getCachedSegments(state.reciter.quranComId!, surahNum);
        if (cached != null) {
          final startMs = _ref.read(audioSegmentsServiceProvider).findWordStartMs(cached, verseKey, wordIndex);
          if (startMs != null) return startMs;
        }
      }
    }

    // 3. Fallback: Proportional calculation from audio duration and total words
    final durMs = _arPlayer.duration?.inMilliseconds ?? 0;
    final ayah = _currentAyahs.where((a) => a.verseKey == verseKey).firstOrNull;
    final wordsCount = ayah != null && ayah.text.isNotEmpty
        ? ayah.text.trim().split(RegExp(r'\s+')).length
        : 0;
    if (wordsCount > 0 && durMs > 0) {
      return ((wordIndex / wordsCount) * durMs).round().clamp(0, durMs);
    }

    return 0;
  }

  int _resolveMalayalamWordTimestamp(String verseKey, int wordIndex) {
    if (wordIndex <= 0) return 0;

    final ayahSeg = _malayalamSegments[verseKey];
    if (ayahSeg != null) {
      // 1. Check clauses
      if (ayahSeg.clauses != null && ayahSeg.clauses!.isNotEmpty) {
        final clause = ayahSeg.clauses!.where((c) => c.wordIndices.contains(wordIndex)).firstOrNull;
        if (clause != null) {
          return clause.startMs;
        }
      }

      // 2. Check word segments
      if (ayahSeg.segments.isNotEmpty) {
        final seg = ayahSeg.segments.where((s) => s.wordIndex == wordIndex || s.wordIndex == wordIndex + 1).firstOrNull;
        if (seg != null) {
          return seg.startMs;
        }
      }
    }

    // 3. Fallback: Proportional calculation
    final durMs = _mlPlayer.duration?.inMilliseconds ?? 0;
    final ayah = _currentAyahs.where((a) => a.verseKey == verseKey).firstOrNull;
    final wordsCount = ayah != null && ayah.text.isNotEmpty
        ? ayah.text.trim().split(RegExp(r'\s+')).length
        : 0;
    if (wordsCount > 0 && durMs > 0) {
      return ((wordIndex / wordsCount) * durMs).round().clamp(0, durMs);
    }

    return 0;
  }

  int? _findClauseIndexForWord(int wordIndex) {
    if (_currentClauses.isEmpty) return null;
    final idx = _currentClauses.indexWhere((c) => c.wordIndices.contains(wordIndex));
    if (idx >= 0) return idx;
    for (int i = 0; i < _currentClauses.length; i++) {
      final c = _currentClauses[i];
      if (c.wordIndices.isNotEmpty && c.wordIndices.first > wordIndex) {
        return max(0, i - 1);
      }
    }
    return _currentClauses.length - 1;
  }

  /// Automatically seeks playhead to the timestamp of the double-tapped word and ensures it plays.
  Future<void> seekToWord(String verseKey, int wordIndex) async {
    _transitionTimer?.cancel();
    _isTransitioning = false;

    final isSameAyah = _playingVerseKey == verseKey;
    final activePlayer = state.audioMode == AudioMode.malayalam ? _mlPlayer : _arPlayer;
    final isLoaded = isSameAyah && activePlayer.audioSource != null;

    if (!isLoaded) {
      await playAyah(verseKey, initialWordIndex: wordIndex);
      return;
    }

    _ref.read(quranPageProvider.notifier).setHighlightVerseKey(verseKey);

    if (state.audioMode == AudioMode.arabic) {
      final targetMs = _resolveArabicWordTimestamp(verseKey, wordIndex);
      await _arPlayer.seek(Duration(milliseconds: targetMs));
      await _arPlayer.play();
      state = state.copyWith(
        isPlaying: true,
        isBuffering: false,
        position: Duration(milliseconds: targetMs),
      );
      _ref.read(quranPageProvider.notifier).setHighlightWord(
        HighlightWord(
          verseKey: verseKey,
          wordIndex: wordIndex,
          bundle: false,
        ),
      );
    } else if (state.audioMode == AudioMode.malayalam) {
      final targetMs = _resolveMalayalamWordTimestamp(verseKey, wordIndex);
      await _mlPlayer.seek(Duration(milliseconds: targetMs));
      await _mlPlayer.play();
      state = state.copyWith(
        isPlaying: true,
        isBuffering: false,
        position: Duration(milliseconds: targetMs),
      );

      final ayahSeg = _malayalamSegments[verseKey];
      final clause = ayahSeg?.clauses?.where((c) => c.wordIndices.contains(wordIndex)).firstOrNull;
      if (clause != null && clause.wordIndices.isNotEmpty) {
        _ref.read(quranPageProvider.notifier).setHighlightWord(
          HighlightWord(
            verseKey: verseKey,
            wordIndex: clause.wordIndices.first,
            wordIndices: clause.wordIndices,
            bundle: true,
          ),
        );
      } else {
        _ref.read(quranPageProvider.notifier).setHighlightWord(
          HighlightWord(
            verseKey: verseKey,
            wordIndex: wordIndex,
            bundle: false,
          ),
        );
      }
    } else {
      // AudioMode.both
      if (state.segmentedMode && _currentClauses.isNotEmpty) {
        final cIdx = _findClauseIndexForWord(wordIndex) ?? 0;
        if (state.clausePhase == ClausePhase.ar) {
          await _playArabicClause(cIdx);
        } else {
          await _playMalayalamClause(cIdx);
        }
      } else {
        // Full interleaving mode
        if (state.clausePhase == ClausePhase.ml) {
          final targetMs = _resolveMalayalamWordTimestamp(verseKey, wordIndex);
          await _mlPlayer.seek(Duration(milliseconds: targetMs));
          await _mlPlayer.play();
          state = state.copyWith(isPlaying: true, isBuffering: false, position: Duration(milliseconds: targetMs));
        } else {
          final targetMs = _resolveArabicWordTimestamp(verseKey, wordIndex);
          await _arPlayer.seek(Duration(milliseconds: targetMs));
          await _arPlayer.play();
          state = state.copyWith(isPlaying: true, isBuffering: false, position: Duration(milliseconds: targetMs));
        }
      }
    }
  }

  void setHighlightVerse(String? key) {
    if (key == null) return;
    final ayahIdx = _currentAyahs.indexWhere((a) => a.verseKey == key);
    state = state.copyWith(
      currentVerseKey: () => key,
      currentAyahIndex: ayahIdx >= 0 ? ayahIdx : 0,
    );
    if (state.isPlaying) {
      playAyah(key);
    }
  }

  Future<void> pause() async {
    _transitionTimer?.cancel();
    _isTransitioning = false;
    await _arPlayer.pause();
    await _mlPlayer.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    final highlightedKey = _ref.read(quranPageProvider).highlightVerseKey;
    final targetKey = highlightedKey ??
        state.currentVerseKey ??
        (_currentAyahs.isNotEmpty ? _currentAyahs.first.verseKey : null);

    if (targetKey == null) {
      final page = _ref.read(quranPageProvider).currentPage;
      try {
        final p = await _ref.read(qvpPageServiceProvider).getPage(page);
        if (p.ayahs.isNotEmpty) {
          final first = p.ayahs.first;
          await playAyah('${first.surah}:${first.ayah}');
        }
      } catch (_) {}
      return;
    }

    final activePlayer = state.audioMode == AudioMode.malayalam ? _mlPlayer : _arPlayer;
    final isLoaded = _playingVerseKey == targetKey && activePlayer.audioSource != null;

    if (!isLoaded) {
      await playAyah(targetKey);
      return;
    }

    try {
      if (state.audioMode == AudioMode.both) {
        if (state.clausePhase == ClausePhase.ml) {
          if (_mlPlayer.processingState == ProcessingState.completed) {
            await _mlPlayer.seek(Duration.zero);
          }
          await _mlPlayer.play();
        } else {
          if (_arPlayer.processingState == ProcessingState.completed) {
            await _arPlayer.seek(Duration.zero);
          }
          await _arPlayer.play();
        }
      } else if (state.audioMode == AudioMode.malayalam) {
        if (_mlPlayer.processingState == ProcessingState.completed) {
          await _mlPlayer.seek(Duration.zero);
        }
        await _mlPlayer.play();
      } else {
        if (_arPlayer.processingState == ProcessingState.completed) {
          await _arPlayer.seek(Duration.zero);
        }
        await _arPlayer.play();
      }
      state = state.copyWith(isPlaying: true, isBuffering: false);
    } catch (e) {
      debugPrint('[AudioPlayer] Error resuming audio: $e, reloading track...');
      await playAyah(targetKey);
    }
  }

  Future<void> stop() async {
    _transitionTimer?.cancel();
    _isTransitioning = false;
    _playingVerseKey = null;
    await _arPlayer.stop();
    await _mlPlayer.stop();
    state = state.copyWith(isPlaying: false, currentVerseKey: () => null);
    _ref.read(quranPageProvider.notifier).setHighlightVerseKey(null);
    _ref.read(quranPageProvider.notifier).setHighlightWord(null);
  }

  void nextAyah() {
    if (_currentAyahs.isEmpty) return;
    final nextIdx = state.currentAyahIndex + 1;
    if (nextIdx < _currentAyahs.length) {
      playAyah(_currentAyahs[nextIdx].verseKey);
    } else {
      _pendingAutoPlayFirstAyah = state.isPlaying;
      _ref.read(quranPageProvider.notifier).nextPage();
    }
  }

  void prevAyah() {
    if (_currentAyahs.isEmpty) return;
    final prevIdx = state.currentAyahIndex - 1;
    if (prevIdx >= 0) {
      playAyah(_currentAyahs[prevIdx].verseKey);
    } else {
      _pendingAutoPlayFirstAyah = state.isPlaying;
      _ref.read(quranPageProvider.notifier).prevPage();
    }
  }

  void _preCacheNextAyahs(OfflineAudioService offlineService, AudioMode mode, int surahNum, int ayahNum) {
    if (_currentAyahs.isEmpty) return;
    final curIdx = _currentAyahs.indexWhere((a) => a.verseKey == '$surahNum:$ayahNum');
    if (curIdx < 0) return;
    for (int offset = 1; offset <= 2; offset++) {
      final nextIdx = curIdx + offset;
      if (nextIdx < _currentAyahs.length) {
        final nextParts = _currentAyahs[nextIdx].verseKey.split(':');
        if (nextParts.length == 2) {
          final nSurah = int.tryParse(nextParts[0]);
          final nAyah = int.tryParse(nextParts[1]);
          if (nSurah != null && nAyah != null) {
            if (mode == AudioMode.arabic || mode == AudioMode.both) {
              offlineService.cacheAyahAudio(
                reciter: state.reciter,
                reciterKey: state.reciter.id,
                surahNumber: nSurah,
                ayahNumber: nAyah,
                isMalayalam: false,
              );
            }
            if (mode == AudioMode.malayalam || mode == AudioMode.both) {
              offlineService.cacheAyahAudio(
                reciter: null,
                reciterKey: 'malayalam',
                surahNumber: nSurah,
                ayahNumber: nAyah,
                isMalayalam: true,
              );
            }
          }
        }
      }
    }
  }

  void _handleAyahCompleted() {
    final vk = _playingVerseKey;
    if (vk == null) return;
    if (_completedVerseKey == vk) return;
    _completedVerseKey = vk;

    _transitionTimer?.cancel();
    _isTransitioning = false;

    // 100ms delay allows the native audio player pipeline to cleanly finalize EOF before loading next track
    _transitionTimer = Timer(const Duration(milliseconds: 100), () {
      if (state.repeatMode == QuranRepeatMode.ayah && _playingVerseKey != null) {
        _completedVerseKey = null;
        playAyah(_playingVerseKey!);
        return;
      }

      if (_currentAyahs.isEmpty) return;
      final curIdx = _currentAyahs.indexWhere((a) => a.verseKey == vk);
      final nextIdx = (curIdx >= 0 ? curIdx : state.currentAyahIndex) + 1;
      if (nextIdx < _currentAyahs.length) {
        playAyah(_currentAyahs[nextIdx].verseKey);
      } else {
        if (state.repeatMode == QuranRepeatMode.page) {
          playAyah(_currentAyahs[0].verseKey);
        } else {
          _pendingAutoPlayFirstAyah = true;
          _ref.read(quranPageProvider.notifier).nextPage();
        }
      }
    });
  }

  void _handleArabicPositionHighlight(Duration pos) {
    final vk = state.currentVerseKey;
    if (vk == null) return;
    final posMs = pos.inMilliseconds;

    final ayahSeg = _arabicSegments.where((s) => s.verseKey == vk).firstOrNull;
    if (ayahSeg != null && ayahSeg.segments.isNotEmpty) {
      // 60ms lookahead compensation for hardware audio output & bluetooth buffer latency
      final effectiveMs = posMs + 60;
      for (int i = 0; i < ayahSeg.segments.length; i++) {
        final seg = ayahSeg.segments[i];
        final nextStart = i + 1 < ayahSeg.segments.length ? ayahSeg.segments[i + 1].startMs : seg.endMs;
        if (effectiveMs >= seg.startMs && effectiveMs < nextStart) {
          _ref.read(quranPageProvider.notifier).setHighlightWord(
            HighlightWord(
              verseKey: vk,
              wordIndex: seg.wordIndex, // 0-based in page (seg.wordIndex is already 0-based)
              bundle: false,
            ),
          );
          return;
        }
      }
    } else {
      // Fallback proportional word timing
      final ayah = _currentAyahs.where((a) => a.verseKey == vk).firstOrNull;
      final durMs = _arPlayer.duration?.inMilliseconds ?? 0;
      if (ayah != null && ayah.text.isNotEmpty && durMs > 0) {
        final wordsCount = ayah.text.trim().split(RegExp(r'\s+')).length;
        if (wordsCount > 0) {
          final wordDurMs = durMs / wordsCount;
          final idx = min(wordsCount - 1, max(0, ((posMs + 60) / wordDurMs).floor()));
          _ref.read(quranPageProvider.notifier).setHighlightWord(
            HighlightWord(
              verseKey: vk,
              wordIndex: idx,
              bundle: false,
            ),
          );
        }
      }
    }
  }

  void _handleMalayalamPositionHighlight(Duration pos) {
    final vk = state.currentVerseKey;
    if (vk == null) return;
    final posMs = pos.inMilliseconds;

    final ayahSeg = _malayalamSegments[vk];
    if (ayahSeg != null) {
      if (ayahSeg.clauses != null && ayahSeg.clauses!.isNotEmpty) {
        for (final clause in ayahSeg.clauses!) {
          if (clause.wordIndices.isNotEmpty && posMs >= clause.startMs && posMs < clause.endMs) {
            _ref.read(quranPageProvider.notifier).setHighlightWord(
              HighlightWord(
                verseKey: vk,
                wordIndex: clause.wordIndices.first,
                wordIndices: clause.wordIndices,
                bundle: true,
              ),
            );
            return;
          }
        }
      }

      // Check individual word segments
      if (ayahSeg.segments.isNotEmpty) {
        final words = <int>[];
        for (final seg in ayahSeg.segments) {
          if (posMs >= seg.startMs && posMs < seg.endMs) {
            words.add(seg.wordIndex);
          }
        }
        if (words.isNotEmpty) {
          _ref.read(quranPageProvider.notifier).setHighlightWord(
            HighlightWord(
              verseKey: vk,
              wordIndex: words.first,
              wordIndices: words,
              bundle: true,
            ),
          );
          return;
        }
      }
    }

    // No accurate speech timing available: clear word highlight (full ayah remains highlighted cleanly)
    _ref.read(quranPageProvider.notifier).setHighlightWord(null);
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _arPosSub?.cancel();
    _arStateSub?.cancel();
    _arDurSub?.cancel();
    _mlPosSub?.cancel();
    _mlStateSub?.cancel();
    _mlDurSub?.cancel();
    _arPlayer.dispose();
    _mlPlayer.dispose();
    super.dispose();
  }
}

final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  return AudioPlayerNotifier(ref);
});
