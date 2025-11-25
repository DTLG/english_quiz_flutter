import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/flashcards.dart';

const _kBestStreakKey = 'best_streak';
const _kUserIdKey = 'flashcard_user_id';

class FlashcardQuizController {
  FlashcardQuizController({SupabaseClient? client, this.category})
    : _supabase = client ?? Supabase.instance.client;

  final String? category;
  final SupabaseClient _supabase;
  final Random _random = Random();
  SharedPreferences? _prefs;

  late List<Flashcard> _flashcards;
  late Flashcard _currentCard;
  late List<String> _currentOptions;
  late String _userId;
  late String _currentDayIso;

  int correctAnswers = 0;
  int wrongAnswers = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _dailyBestStreak = 0;
  int _sessionCount = 0;

  String get _categoryKey => category ?? 'all';

  Flashcard get currentCard => _currentCard;
  List<String> get currentOptions => List.unmodifiable(_currentOptions);
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureUserId();
    _bestStreak = _prefs?.getInt(_kBestStreakKey) ?? 0;
    await _loadFlashcards();
    await _loadDailyProgress();
    _loadNextQuestion();
  }

  bool submitAnswer(String selection) {
    final isCorrect = selection == _currentCard.ukrainian;
    if (isCorrect) {
      correctAnswers++;
      _currentStreak++;
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
        _prefs?.setInt(_kBestStreakKey, _bestStreak);
      }
      if (_currentStreak > _dailyBestStreak) {
        _dailyBestStreak = _currentStreak;
      }
      _loadNextQuestion();
    } else {
      wrongAnswers++;
      _currentStreak = 0;
    }

    unawaited(_syncDailyResults());
    return isCorrect;
  }

  Future<void> _ensureUserId() async {
    final storedId = _prefs?.getString(_kUserIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      _userId = storedId;
      return;
    }
    final newId = const Uuid().v4();
    await _prefs?.setString(_kUserIdKey, newId);
    _userId = newId;
  }

  Future<void> _loadFlashcards() async {
    var request = _supabase
        .schema('english_quiz')
        .from('words')
        .select('english, ukrainian, example, category, created_at');

    if (category != null) {
      request = request.eq('category', category!);
    }

    final data = await request.order('created_at', ascending: false);

    final cards = (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => Flashcard(
            english: (row['english'] as String?)?.trim() ?? '',
            ukrainian: (row['ukrainian'] as String?)?.trim() ?? '',
            example: (row['example'] as String?)?.trim() ?? '',
            category: (row['category'] as String?)?.trim() ?? 'uncategorized',
          ),
        )
        .where((card) => card.english.isNotEmpty && card.ukrainian.isNotEmpty)
        .toList();

    if (cards.length < 4) {
      throw StateError(
        'Need at least 4 entries in english_quiz.words to run the quiz.',
      );
    }

    _flashcards = cards;
  }

  Future<void> _loadDailyProgress() async {
    final now = DateTime.now().toUtc();
    _currentDayIso = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).toIso8601String().split('T').first;

    try {
      final existing = await _supabase
          .schema('english_quiz')
          .from('daily_results')
          .select()
          .eq('user_id', _userId)
          .eq('day', _currentDayIso)
          .eq('category', _categoryKey)
          .maybeSingle();

      if (existing != null) {
        correctAnswers = (existing['correct_count'] as int?) ?? 0;
        wrongAnswers = (existing['wrong_count'] as int?) ?? 0;
        _dailyBestStreak = (existing['best_streak'] as int?) ?? 0;
        _sessionCount = ((existing['session_count'] as int?) ?? 0) + 1;
        unawaited(_syncDailyResults());
        return;
      }

      _sessionCount = 1;
      correctAnswers = 0;
      wrongAnswers = 0;
      _dailyBestStreak = 0;

      await _supabase.schema('english_quiz').from('daily_results').insert({
        'user_id': _userId,
        'day': _currentDayIso,
        'category': _categoryKey,
        'correct_count': 0,
        'wrong_count': 0,
        'best_streak': 0,
        'session_count': _sessionCount,
      });
    } catch (_) {
      _sessionCount = 1;
      correctAnswers = 0;
      wrongAnswers = 0;
      _dailyBestStreak = 0;
    }
  }

  Future<void> _syncDailyResults() async {
    final payload = {
      'user_id': _userId,
      'day': _currentDayIso,
      'category': _categoryKey,
      'correct_count': correctAnswers,
      'wrong_count': wrongAnswers,
      'best_streak': _dailyBestStreak,
      'session_count': _sessionCount,
      'last_updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _supabase
          .schema('english_quiz')
          .from('daily_results')
          .upsert(payload, onConflict: 'day,category');
    } catch (_) {
      // Ignore sync failures; data will be retried on the next update.
    }
  }

  void _loadNextQuestion() {
    _currentCard = _flashcards[_random.nextInt(_flashcards.length)];

    final optionsPool =
        _flashcards
            .where((card) => card != _currentCard)
            .map((card) => card.ukrainian)
            .toList()
          ..shuffle(_random);

    _currentOptions = [_currentCard.ukrainian, ...optionsPool.take(3)]
      ..shuffle(_random);
  }
}
