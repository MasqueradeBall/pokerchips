import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/animated_chip_counter.dart';

class PotDisplay extends StatelessWidget {
  const PotDisplay({super.key, required this.pot});

  final int pot;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'POT',
          style: TextStyle(
            color: AppColors.goldLight,
            letterSpacing: 3,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        AnimatedChipCounter(
          value: pot,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}
