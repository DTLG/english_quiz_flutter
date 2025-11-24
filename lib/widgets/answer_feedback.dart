import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({
    super.key,
    required this.isCorrect,
  });

  final bool isCorrect;

  static const _correctAsset = 'assets/animations/correct.json';
  static const _wrongAsset = 'assets/animations/wrong.json';

  @override
  Widget build(BuildContext context) {
    final asset = isCorrect ? _correctAsset : _wrongAsset;
    final background = isCorrect
        ? Colors.green.withOpacity(0.2)
        : Colors.red.withOpacity(0.2);

    return IgnorePointer(
      ignoring: true,
      child: Container(
        color: background,
        alignment: Alignment.center,
        child: SizedBox(
          width: 220,
          height: 220,
          child: Lottie.asset(
            asset,
            repeat: false,
          ),
        ),
      ),
    );
  }
}

