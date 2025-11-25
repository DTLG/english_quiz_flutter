import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'flashcard_quiz_page.dart';
import 'progress_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _client = Supabase.instance.client;
  late Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();
  }

  Future<List<String>> _fetchCategories() async {
    final response = await _client
        .schema('english_quiz')
        .from('words')
        .select('category')
        .not('category', 'is', null);

    final rows =
        (response as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((row) => (row['category'] as String).trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return rows;
  }

  Future<void> _refreshCategories() async {
    setState(() {
      _categoriesFuture = _fetchCategories();
    });
    await _categoriesFuture;
  }

  void _openQuiz({String? category, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardQuizPage(category: category, title: title),
      ),
    );
  }

  void _openProgress() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProgressPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9AD5FF), Color(0xFFE4F3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'English Quest',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Вибери пригоду та вчися граючись!',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                _MenuButton(
                  color: Colors.orange.shade300,
                  title: '🎲 Випадковий тест',
                  description: 'Слова з усіх категорій',
                  onTap: () =>
                      _openQuiz(category: null, title: 'Випадкові слова'),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Не вдалося завантажити категорії',
                            style: theme.textTheme.titleMedium,
                          ),
                        );
                      }
                      final categories = snapshot.data ?? [];
                      if (categories.isEmpty) {
                        return Center(
                          child: Text(
                            'Категорії ще не додані.',
                            style: theme.textTheme.titleMedium,
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: _refreshCategories,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Text(
                              'Категорії',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: categories
                                  .map(
                                    (category) => _CategoryCard(
                                      label: category,
                                      onTap: () => _openQuiz(
                                        category: category,
                                        title: category,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openProgress,
                    icon: const Icon(Icons.show_chart_rounded),
                    label: const Text('Мій прогрес'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
  });

  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded, size: 42),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
