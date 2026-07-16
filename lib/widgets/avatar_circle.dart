import 'package:flutter/material.dart';

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelf ? const Color(0xFFF1C40F) : _colorForName(name),
        border: Border.all(
          color: isCurrentTurn ? const Color(0xFFF1C40F) : Colors.white70,
          width: isCurrentTurn ? 3 : 1.5,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: const Color(0xFFF1C40F).withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
