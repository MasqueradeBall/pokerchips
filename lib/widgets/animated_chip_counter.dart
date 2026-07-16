import 'package:flutter/material.dart';

/// 金額表示をカウントアップ/ダウンさせるテキスト。
class AnimatedChipCounter extends StatelessWidget {
  const AnimatedChipCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '\$',
  });

  final int value;
  final TextStyle? style;
  final String prefix;

  static String _format(int n) {
    final negative = n < 0;
    final digits = n.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value.toDouble(), end: value.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Text('$prefix${_format(val.round())}', style: style);
      },
    );
  }
}
