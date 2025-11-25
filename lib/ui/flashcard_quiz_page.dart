import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/flashcard_quiz_controller.dart';
import '../widgets/answer_button.dart';
import '../widgets/stat_chip.dart';
import '../widgets/streak_indicator.dart';
import '../widgets/answer_feedback.dart';

class FlashcardQuizPage extends StatefulWidget {
  const FlashcardQuizPage({
    super.key,
    this.category,
    this.title = 'English Flash Cards',
  });

  final String? category;
  final String title;

  @override
  State<FlashcardQuizPage> createState() => _FlashcardQuizPageState();
}

class _FlashcardQuizPageState extends State<FlashcardQuizPage> {
  late final FlashcardQuizController _controller;
  bool _isReady = false;
  bool _showFeedback = false;
  bool? _lastAnswerCorrect;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = FlashcardQuizController(category: widget.category);
    _initializeController();
  }

  Future<void> _initializeController() async {
    await _controller.init();
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  void _handleAnswer(String option) {
    final isCorrect = _controller.submitAnswer(option);
    _feedbackTimer?.cancel();
    setState(() {
      _lastAnswerCorrect = isCorrect;
      _showFeedback = true;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: _isReady
          ? OrientationBuilder(
              builder: (context, orientation) {
                final content = _buildQuizContent(orientation);
                return Stack(
                  children: [
                    content,
                    if (_showFeedback && _lastAnswerCorrect != null)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: _showFeedback ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: AnswerFeedback(
                            isCorrect: _lastAnswerCorrect!,
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildQuizContent(Orientation orientation) {
    final contentChildren = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StatChip(
            label: 'Correct',
            value: _controller.correctAnswers,
            color: Colors.green.shade600,
          ),
          StreakIndicator(
            currentStreak: _controller.currentStreak,
            bestStreak: _controller.bestStreak,
          ),
          StatChip(
            label: 'Wrong',
            value: _controller.wrongAnswers,
            color: Colors.red.shade600,
          ),
        ],
      ),
      const SizedBox(height: 36),
      Align(
        alignment: Alignment.center,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              widget.category?.toUpperCase() ?? 'RANDOM MIX',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.indigo.shade600),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        _controller.currentCard.english,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displayMedium,
      ),
      const SizedBox(height: 12),
      Text(
        _controller.currentCard.example,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 32),
    ];

    final padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32);

    if (orientation == Orientation.landscape) {
      return SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...contentChildren,
              Center(
                child: _AnswerRow(
                  options: _controller.currentOptions,
                  onSelected: _handleAnswer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...contentChildren,
          const Spacer(),
          _AnswerRow(
            options: _controller.currentOptions,
            onSelected: _handleAnswer,
          ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.options,
    required this.onSelected,
  });

  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const horizontalPadding = 24.0 * 2;
    const gap = 12.0;

    final availableWidth = (size.width - horizontalPadding).clamp(0.0, double.infinity);
    final widthPerButton =
        ((availableWidth - gap * (options.length - 1)) / options.length).clamp(48.0, availableWidth);
    final buttonSize = math.max(64.0, math.min(widthPerButton, size.height * 0.22));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(options.length, (index) {
        final option = options[index];
        return Padding(
          padding: EdgeInsets.only(right: index == options.length - 1 ? 0 : gap),
          child: SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: AnswerButton(
              label: option,
              onTap: () => onSelected(option),
            ),
          ),
        );
      }),
    );
  }
}

