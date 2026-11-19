# HolyQuran AI

[![CI](https://github.com/mubarakar95/holyquran-ai/actions/workflows/ci.yml/badge.svg)](https://github.com/mubarakar95/holyquran-ai/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)

A Flutter mobile app for reading and studying the Quran with Malayalam translation, word-by-word meanings and synchronized audio.

## Features

- **Mushaf reader** with page-accurate rendering (604 pages), a two-page spread mode for tablets, and selectable page frame, surah header and ayah marker styles.
- **QVP vector pages**: pages rendered from precomputed vector data for crisp text at any screen size.
- **Malayalam translation** shown alongside the Arabic text.
- **Word-by-word mode** with swipeable cards for meanings and vocabulary practice.
- **Audio playback** with multiple reciters, Arabic, Malayalam or both, clause-level segmented playback and word highlighting that follows the audio.
- **Offline audio**: download whole surahs and manage them from a downloads screen.
- **Gemini-assisted audio alignment** for word timings. This uses your own Gemini API key, entered in the app settings.
- **Mushtabihat** (similar verses) browsing and bookmarks.

## Tech stack

| Area | Choice |
| --- | --- |
| Framework | Flutter (Dart 3) |
| State management | Riverpod |
| Audio | just_audio, audio_session |
| Backend | Supabase |
| Local storage | sqflite, shared_preferences |
| AI | Google Generative AI (Gemini) |

## Project structure

```
lib/
  core/        models, services, theme, utils
  providers/   Riverpod providers (audio, pages, settings, downloads, ...)
  ui/          screens and widgets (mushaf, audio, learn, downloads, settings, ...)
assets/        fonts, page data, ornaments, images
scripts/       Python helpers for precomputing audio segments
test/          unit and widget tests
```

## Getting started

Requirements: the Flutter stable SDK and a connected device or emulator.

```bash
git clone https://github.com/mubarakar95/holyquran-ai.git
cd holyquran-ai
flutter pub get
flutter run
```

The app talks to a Supabase project configured in `lib/core/services/supabase_service.dart`. To use your own backend, replace the URL and publishable key there.

## Tests

```bash
flutter analyze
flutter test
```

Both commands run on every push and pull request through GitHub Actions (`.github/workflows/ci.yml`).

## Scripts

The Python scripts in `scripts/` precompute word-level audio segments. Install their dependencies with `pip install -r scripts/requirements.txt`.

## License

No license has been specified yet. All rights reserved by the author.
