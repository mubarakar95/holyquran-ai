import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quran_dressing_catalog.dart';
import '../../core/models/quran_types.dart';
import '../../core/models/qcf4_models.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/quran_page_provider.dart';
import '../../providers/settings_provider.dart';
import '../downloads/download_manager_screen.dart';
import '../learn/learn_screen.dart';
import '../mushtabihat/mushtabihat_screen.dart';
import '../settings/quran_dressing_screen.dart';

const Map<int, int> SURAH_PAGE_MAP = {
  1: 1, 2: 2, 3: 22, 4: 77, 5: 106, 6: 128, 7: 151, 8: 177, 9: 187,
  10: 208, 11: 221, 12: 235, 13: 250, 14: 255, 15: 262, 16: 267, 17: 282,
  18: 293, 19: 305, 20: 312, 21: 322, 22: 332, 23: 342, 24: 350, 25: 359,
  26: 367, 27: 377, 28: 385, 29: 394, 30: 404, 31: 411, 32: 415, 33: 418,
  34: 428, 35: 434, 36: 440, 37: 446, 38: 453, 39: 458, 40: 467, 41: 477,
  42: 483, 43: 489, 44: 496, 45: 499, 46: 502, 47: 507, 48: 511, 49: 515,
  50: 518, 51: 522, 52: 526, 53: 528, 54: 531, 55: 531, 56: 534, 57: 537,
  58: 540, 59: 543, 60: 545, 61: 548, 62: 549, 63: 551, 64: 552, 65: 554,
  66: 555, 67: 557, 68: 559, 69: 562, 70: 564, 71: 567, 72: 569, 73: 571,
  74: 573, 75: 577, 76: 578, 77: 580, 78: 582, 79: 584, 80: 585, 81: 587,
  82: 588, 83: 589, 84: 591, 85: 592, 86: 593, 87: 594, 88: 594, 89: 595,
  90: 596, 91: 597, 92: 597, 93: 598, 94: 598, 95: 599, 96: 599, 97: 600,
  98: 600, 99: 600, 100: 600, 101: 601, 102: 601, 103: 601, 104: 601,
  105: 601, 106: 602, 107: 602, 108: 602, 109: 603, 110: 603, 111: 603,
  112: 604, 113: 604, 114: 604,
};

class SidebarDrawer extends ConsumerStatefulWidget {
  const SidebarDrawer({super.key});

  @override
  ConsumerState<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends ConsumerState<SidebarDrawer> {
  int _activeTab = 0; // 0: Navigate, 1: Settings
  int _navSubTab = 0; // 0: Surah, 1: Juz, 2: Page
  final TextEditingController _pageInputController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageInputController.text = ref.read(quranPageProvider).currentPage.toString();
    _geminiKeyController.text = ref.read(settingsProvider).geminiApiKey;
  }

  @override
  void dispose() {
    _pageInputController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = AppColors.fromMode(settings.theme);
    final quranState = ref.watch(quranPageProvider);
    final quranNotifier = ref.read(quranPageProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Drawer(
      backgroundColor: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header with Menu Title and Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: colors.muted,
                  ),
                ],
              ),
            ),

            // Main Tab Switcher (Navigate vs Settings)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? colors.foreground : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Navigate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 0 ? colors.background : colors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? colors.foreground : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _activeTab == 1 ? colors.background : colors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: _activeTab == 0
                  ? _buildNavigateTab(context, colors, quranState, quranNotifier)
                  : _buildSettingsTab(context, colors, settings, settingsNotifier, quranState, quranNotifier),
            ),

            // Links to Vocabulary, Mushtabihat, Audio Downloads
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                children: [
                  _buildNavFeatureTile(
                    context,
                    title: 'Download Audio Manager',
                    subtitle: 'Manage offline Surahs & reciters',
                    icon: Icons.download_rounded,
                    color: colors.accent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DownloadManagerScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildNavFeatureTile(
                    context,
                    title: 'Learn Vocabulary',
                    subtitle: 'Flashcards & Mastery Quiz',
                    icon: Icons.school_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LearnVocabularyScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildNavFeatureTile(
                    context,
                    title: 'Mushtabihat',
                    subtitle: 'Similar verses study & search',
                    icon: Icons.compare_arrows_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MushtabihatScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigateTab(
    BuildContext context,
    AppColors colors,
    QuranPageState quranState,
    QuranPageNotifier quranNotifier,
  ) {
    return Column(
      children: [
        // Sub-tabs (Surah, Juz, Page)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Surah', 'Juz', 'Page'].asMap().entries.map((entry) {
              final idx = entry.key;
              final label = entry.value;
              final isSel = _navSubTab == idx;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _navSubTab = idx),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? colors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSel ? colors.border : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? colors.foreground : colors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: _navSubTab == 0
              ? _buildSurahList(context, colors, quranState, quranNotifier)
              : _navSubTab == 1
                  ? _buildJuzList(context, colors, quranState, quranNotifier)
                  : _buildPageJump(context, colors, quranNotifier),
        ),
      ],
    );
  }

  Widget _buildSurahList(
    BuildContext context,
    AppColors colors,
    QuranPageState quranState,
    QuranPageNotifier quranNotifier,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 114,
      itemBuilder: (context, idx) {
        final surahNum = idx + 1;
        final info = SURAH_NAMES[surahNum];
        final startPage = SURAH_PAGE_MAP[surahNum] ?? 1;
        final isCurrent = quranState.currentPage >= startPage &&
            (surahNum == 114 || quranState.currentPage < (SURAH_PAGE_MAP[surahNum + 1] ?? 605));

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          selected: isCurrent,
          selectedTileColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Text(
            '$surahNum',
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
          title: Text(
            info?.englishName ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          trailing: Text(
            info?.name ?? '',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          onTap: () {
            quranNotifier.goToPage(startPage);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildJuzList(
    BuildContext context,
    AppColors colors,
    QuranPageState quranState,
    QuranPageNotifier quranNotifier,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: JUZ_DATA.length,
      itemBuilder: (context, idx) {
        final juz = JUZ_DATA[idx];
        final nextStart = idx + 1 < JUZ_DATA.length ? JUZ_DATA[idx + 1].startPage : 605;
        final isCurrent = quranState.currentPage >= juz.startPage && quranState.currentPage < nextStart;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          selected: isCurrent,
          selectedTileColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Text(
            '${juz.number}',
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
          title: Text(
            juz.nameEn,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          trailing: Text(
            juz.name,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          onTap: () {
            quranNotifier.goToPage(juz.startPage);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildPageJump(
    BuildContext context,
    AppColors colors,
    QuranPageNotifier quranNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Go to page (1–$TOTAL_PAGES)',
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _pageInputController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
              onSubmitted: (val) {
                final page = int.tryParse(val);
                if (page != null && page >= 1 && page <= TOTAL_PAGES) {
                  quranNotifier.goToPage(page);
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(_pageInputController.text);
              if (page != null && page >= 1 && page <= TOTAL_PAGES) {
                quranNotifier.goToPage(page);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Go to Page'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    AppColors colors,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
    QuranPageState quranState,
    QuranPageNotifier quranNotifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Theme Switcher
        Text('Theme', style: TextStyle(fontSize: 11, color: colors.muted)),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildThemeOption('Light', AppThemeMode.light, settings.theme, colors, () {
              settingsNotifier.setTheme(AppThemeMode.light);
            }),
            const SizedBox(width: 6),
            _buildThemeOption('Creme', AppThemeMode.creme, settings.theme, colors, () {
              settingsNotifier.setTheme(AppThemeMode.creme);
            }),
            const SizedBox(width: 6),
            _buildThemeOption('Dark', AppThemeMode.dark, settings.theme, colors, () {
              settingsNotifier.setTheme(AppThemeMode.dark);
            }),
          ],
        ),

        const SizedBox(height: 16),

        // Quran Dressing & Ornaments (Dedicated Page Navigation)
        InkWell(
          onTap: () {
            Navigator.of(context).pop(); // Close drawer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuranDressingScreen(
                  previewPageNumber: ref.read(quranPageProvider).currentPage,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome_mosaic_rounded, size: 20, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quran Dressing & Ornaments',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${settings.frameDress == 'none' ? 'Borderless' : (settings.frameDress == 'minimal' ? 'Minimal Gold' : QuranDressingCatalog.getFrameMeta(settings.frameDress).name.split('(').first.trim())} • ${settings.ayahDress == 'classic' ? 'Classic Ring' : QuranDressingCatalog.getAyahMarkerMeta(settings.ayahDress).name.split('(').first.trim()}',
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.muted),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Toggles
        _buildToggleTile(
          title: 'Full Screen',
          subtitle: 'Immersive reading without distraction',
          value: quranState.isFullScreen,
          onChanged: (_) => quranNotifier.toggleFullScreen(),
          colors: colors,
        ),
        _buildToggleTile(
          title: 'Word by Word',
          subtitle: 'Malayalam meanings under Arabic words',
          value: quranState.showWordByWord,
          onChanged: (_) => quranNotifier.toggleWordByWord(),
          colors: colors,
        ),
        _buildToggleTile(
          title: 'Swipe Mode',
          subtitle: 'Ayah-by-ayah word swipe learning card',
          value: quranState.showSwipeWBW,
          onChanged: (_) => quranNotifier.toggleSwipeWBW(),
          colors: colors,
        ),
        _buildToggleTile(
          title: 'Translation',
          subtitle: 'Ayah-by-ayah Malayalam translation',
          value: quranState.showTranslation,
          onChanged: (_) => quranNotifier.toggleTranslation(),
          colors: colors,
        ),
        _buildToggleTile(
          title: 'Two Page Mode',
          subtitle: 'Dual-page book spread',
          value: quranState.twoPageMode,
          onChanged: (_) => quranNotifier.toggleTwoPageMode(),
          colors: colors,
        ),

        const SizedBox(height: 16),

        // Word Hover Meaning Settings
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Word Hover Meaning',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 10),

              // Popup Speed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Popup Speed', style: TextStyle(fontSize: 11, color: colors.muted)),
                  Text(
                    settings.hoverDelay == 0
                        ? 'Instant (0ms)'
                        : (settings.hoverDelay <= 80 ? 'Fast (80ms)' : 'Normal (200ms)'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.foreground),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildHoverPill('Instant', 0, settings.hoverDelay, colors, () {
                    settingsNotifier.setHoverDelay(0);
                  }),
                  const SizedBox(width: 4),
                  _buildHoverPill('Fast', 80, settings.hoverDelay, colors, () {
                    settingsNotifier.setHoverDelay(80);
                  }),
                  const SizedBox(width: 4),
                  _buildHoverPill('Normal', 200, settings.hoverDelay, colors, () {
                    settingsNotifier.setHoverDelay(200);
                  }),
                ],
              ),
              const SizedBox(height: 12),

              // Label Size
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Label Size', style: TextStyle(fontSize: 11, color: colors.muted)),
                  Text(
                    settings.hoverFontSize <= 14
                        ? 'Medium (14px)'
                        : (settings.hoverFontSize <= 18 ? 'Large (18px)' : 'X-Large (22px)'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.foreground),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildHoverPill('Medium', 14, settings.hoverFontSize, colors, () {
                    settingsNotifier.setHoverFontSize(14);
                  }),
                  const SizedBox(width: 4),
                  _buildHoverPill('Large', 18, settings.hoverFontSize, colors, () {
                    settingsNotifier.setHoverFontSize(18);
                  }),
                  const SizedBox(width: 4),
                  _buildHoverPill('X-Large', 22, settings.hoverFontSize, colors, () {
                    settingsNotifier.setHoverFontSize(22);
                  }),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Font Sliders
        Text(
          'Arabic Font Scale (${settings.arFontSize}%)',
          style: TextStyle(fontSize: 11, color: colors.muted),
        ),
        Slider(
          value: settings.arFontSize.toDouble(),
          min: 60,
          max: 200,
          activeColor: colors.accent,
          onChanged: (val) => settingsNotifier.setArFontSize(val.toInt()),
        ),

        Text(
          'Malayalam Font Scale (${settings.mlFontSize}%)',
          style: TextStyle(fontSize: 11, color: colors.muted),
        ),
        Slider(
          value: settings.mlFontSize.toDouble(),
          min: 60,
          max: 200,
          activeColor: colors.accent,
          onChanged: (val) => settingsNotifier.setMlFontSize(val.toInt()),
        ),

        const SizedBox(height: 12),

        // Gemini API Key Input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gemini API Key', style: TextStyle(fontSize: 11, color: colors.muted)),
            if (settings.geminiApiKey.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Saved',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              )
            else
              const Text(
                'Not set',
                style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _geminiKeyController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Enter API Key for live AI alignment',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_rounded, size: 18),
              onPressed: () {
                settingsNotifier.setGeminiApiKey(_geminiKeyController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gemini API key saved!')),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    String label,
    AppThemeMode mode,
    AppThemeMode current,
    AppColors colors,
    VoidCallback onTap,
  ) {
    final isSel = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? colors.foreground : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSel ? colors.background : colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required AppColors colors,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.foreground)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: colors.muted)),
      value: value,
      activeTrackColor: colors.accent,
      onChanged: onChanged,
    );
  }

  Widget _buildNavFeatureTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
    );
  }

  Widget _buildHoverPill(
    String label,
    int value,
    int currentValue,
    AppColors colors,
    VoidCallback onTap,
  ) {
    final isSel = value == currentValue;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? colors.foreground : colors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSel ? colors.foreground : colors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? colors.background : colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
