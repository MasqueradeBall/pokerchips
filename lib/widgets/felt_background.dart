import 'package:flutter/material.dart';

import '../core/theme.dart';

/// カジノフェルト調の背景。Home/Play/Waiting画面で共通利用する。
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [AppColors.feltGreenLight, AppColors.feltGreenDark],
        ),
      ),
      child: child,
    );
  }
}
