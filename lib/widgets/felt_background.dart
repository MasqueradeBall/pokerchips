import 'package:flutter/material.dart';

import '../core/theme.dart';

/// カジノフェルト調の背景。Home/Play/Waiting画面で共通利用する。
/// 上部から差すスポットライト + 周辺減光(ビネット)で奥行きを出す。
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
      child: DecoratedBox(
        // 周辺をわずかに沈ませるビネット。中央のコンテンツに視線を集める。
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.4,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.32),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
        child: child,
      ),
    );
  }
}
