import 'package:flutter/material.dart';

import '../core/theme.dart';

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.name,
    this.size = 44,
    this.isSelf = false,
    this.isCurrentTurn = false,
    this.dimmed = false,
  });

  final String name;
  final double size;
  final bool isSelf;
  final bool isCurrentTurn;
  final bool dimmed;

  static const _palette = [
    Color(0xFF2980B9),
    Color(0xFF8E44AD),
    Color(0xFFC0392B),
    Color(0xFF16A085),
    Color(0xFFD35400),
    Color(0xFF34495E),
  ];

  Color _colorForName(String value) {
    final sum = value.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[sum % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final base = isSelf ? AppColors.goldLight : _colorForName(name);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 左上から光が当たったような立体感のあるグラデーション。
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lighten(base, 0.18),
            AppColors.darken(base, 0.25),
          ],
        ),
        border: Border.all(
          color: isCurrentTurn
              ? AppColors.goldLight
              : Colors.white.withValues(alpha: dimmed ? 0.3 : 0.7),
          width: isCurrentTurn ? 3 : 1.5,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: AppColors.goldLight.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Text(
          initial,
          style: TextStyle(
            color: isSelf ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
