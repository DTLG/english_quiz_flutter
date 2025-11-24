import 'package:flutter/material.dart';

class StreakIndicator extends StatelessWidget {
  const StreakIndicator({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  final int currentStreak;
  final int bestStreak;

  static const _flameKeyOff = ValueKey('flame-off');

  @override
  Widget build(BuildContext context) {
    final showFlame = currentStreak >= 3;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
            child: showFlame
                ? _FlameBadge(
                    key: ValueKey<int>(currentStreak),
                    streak: currentStreak,
                  )
                : const _FlamePlaceholder(key: _flameKeyOff),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Streak: $currentStreak',
          style: textTheme.titleMedium,
        ),
        Text(
          'Best: $bestStreak',
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _FlameBadge extends StatelessWidget {
  const _FlameBadge({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade400,
            Colors.red.shade400,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              color: colorScheme.onPrimary,
              size: 28,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlamePlaceholder extends StatelessWidget {
  const _FlamePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Icon(
        Icons.local_fire_department,
        color: Colors.grey.shade400,
        size: 28,
      ),
    );
  }
}

