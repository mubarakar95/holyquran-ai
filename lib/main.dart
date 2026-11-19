import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/qvp_dress.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/service_providers.dart';
import 'providers/settings_provider.dart';
import 'ui/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system orientations and navigation bar overlays
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize Local Storage
  final localStorage = await LocalStorageService.create();

  // Initialize Supabase client
  try {
    await SupabaseService.initialize();
  } catch (_) {
    // Supabase can initialize offline without blocking app start
  }

  // Pre-warm active Quran manuscript ornaments into GPU memory
  // so app launch and the initial page border render 100% instantaneously (0ms) offline
  try {
    await QvpFrameDress.load(localStorage.frameDress);
  } catch (e) {
    debugPrint('Frame pre-warm note: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
      ],
      child: const QuranEasyApp(),
    ),
  );
}

class QuranEasyApp extends ConsumerWidget {
  const QuranEasyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Quran Easy Malayalam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(settings.theme),
      home: const HomeScreen(),
    );
  }
}
