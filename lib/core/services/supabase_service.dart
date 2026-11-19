import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vocabulary_models.dart';

const String SUPABASE_URL = "https://ktgbycvwpaspwusphmap.supabase.co";
const String SUPABASE_ANON_KEY = "sb_publishable_JpRABmZi52XJChQX9t-gBw_kicbkn8p";

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SUPABASE_URL,
      publishableKey: SUPABASE_ANON_KEY,
    );
  }

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithPassword(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) {
    return client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithOtp(String email) {
    return client.auth.signInWithOtp(email: email);
  }

  Future<void> signOut() {
    return client.auth.signOut();
  }

  // ── Sync Vocabulary Progress ─────────────────────────────────────────────
  Future<void> syncWordProgress(String userId, Map<String, WordProgress> progress) async {
    final rows = progress.entries.map((e) => {
      'user_id': userId,
      'word_id': e.key,
      'arabic': e.key,
      'malayalam': '',
      'status': e.value.status.value,
      'correct_count': e.value.correct,
      'wrong_count': e.value.wrong,
      'last_reviewed': DateTime.fromMillisecondsSinceEpoch(e.value.lastReviewed).toIso8601String(),
    }).toList();

    if (rows.isNotEmpty) {
      await client.from('user_word_progress').upsert(rows);
    }
  }

  Future<Map<String, WordProgress>> loadWordProgress(String userId) async {
    final rows = await client
        .from('user_word_progress')
        .select()
        .eq('user_id', userId);

    final result = <String, WordProgress>{};
    for (final row in rows) {
      final wordId = row['word_id'] as String;
      final status = WordStatus.fromString(row['status'] as String? ?? 'new');
      final correct = row['correct_count'] as int? ?? 0;
      final wrong = row['wrong_count'] as int? ?? 0;
      final reviewedStr = row['last_reviewed'] as String?;
      final lastReviewed = reviewedStr != null
          ? DateTime.tryParse(reviewedStr)?.millisecondsSinceEpoch ?? 0
          : 0;

      result[wordId] = WordProgress(
        status: status,
        correct: correct,
        wrong: wrong,
        lastReviewed: lastReviewed,
      );
    }
    return result;
  }

  // ── Mushtabihat Bookmarks & Hidden ─────────────────────────────────────────
  Future<void> syncBookmarks(String userId, List<String> pairKeys) async {
    await client.from('user_mushtabihat_bookmarks').delete().eq('user_id', userId);
    final rows = pairKeys.map((pk) {
      final parts = pk.split('|');
      return {
        'user_id': userId,
        'ayah1': parts.isNotEmpty ? parts[0] : '',
        'ayah2': parts.length > 1 ? parts[1] : '',
      };
    }).toList();
    if (rows.isNotEmpty) {
      await client.from('user_mushtabihat_bookmarks').insert(rows);
    }
  }

  Future<List<String>> loadBookmarks(String userId) async {
    final rows = await client
        .from('user_mushtabihat_bookmarks')
        .select('ayah1, ayah2')
        .eq('user_id', userId);
    return rows.map((r) => '${r['ayah1']}|${r['ayah2']}').toList();
  }

  Future<void> syncHidden(String userId, List<String> pairKeys) async {
    await client.from('user_mushtabihat_hidden').delete().eq('user_id', userId);
    final rows = pairKeys.map((pk) {
      final parts = pk.split('|');
      return {
        'user_id': userId,
        'ayah1': parts.isNotEmpty ? parts[0] : '',
        'ayah2': parts.length > 1 ? parts[1] : '',
      };
    }).toList();
    if (rows.isNotEmpty) {
      await client.from('user_mushtabihat_hidden').insert(rows);
    }
  }

  Future<List<String>> loadHidden(String userId) async {
    final rows = await client
        .from('user_mushtabihat_hidden')
        .select('ayah1, ayah2')
        .eq('user_id', userId);
    return rows.map((r) => '${r['ayah1']}|${r['ayah2']}').toList();
  }
}
