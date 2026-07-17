import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/animated_chip_counter.dart';

/// プレイヤーの前(テーブル上)に置かれる、現在ストリートのベット額を表す
/// チップスタック。
///
/// 実際のポーカーのように、ベットしたぶんのチップがプレイヤーの手前に
/// 積まれて見えるようにする。金額に応じて枚数が増え、金額が0になると
/// (ストリート終了でポットに回収されたとき)縮んで消える。
///
/// ベット中は盤面の再描画のたびに作り直されるため、描画は小さな
/// CustomPaint 1枚 + 金額ピルのみに抑えてある。
class BetChipStack extends StatelessWidget {
  const BetChipStack({super.key, required this.amount});

  /// このストリートでの現在ベット額。0以下なら非表示(縮小退場)。
  final int amount;

  /// 金額の桁数に応じたチップ枚数 (1〜5枚)。
  static int _chipCountFor(int amount) {
    if (amount <= 0) return 0;
    return amount.toString().length.clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    final visible = amount > 0;
    final chipCount = _chipCountFor(amount);

    return IgnorePointer(
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 260),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 金額が変わった瞬間に軽くポップさせる (keyの変更でリスタート)。
              TweenAnimationBuilder<double>(
                key: ValueKey(chipCount),
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: CustomPaint(
                  size: const Size(34, 36),
                  painter: _ChipStackPainter(chipCount: chipCount),
                ),
              ),
              const SizedBox(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                ),
                child: AnimatedChipCounter(
                  value: amount,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 斜め上から見たチップの積み重ねを描くペインタ。
///
/// ALL IN 演出と同じ「円盤 + 白いエッジマーク」のチップ意匠を、
/// 楕円(俯瞰)にして積み上げる。
class _ChipStackPainter extends CustomPainter {
  const _ChipStackPainter({required this.chipCount});

  final int chipCount;

  static const _colors = [
    AppColors.chipRed,
    AppColors.chipBlue,
    AppColors.chipGreen,
    AppColors.gold,
    AppColors.chipRed,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (chipCount <= 0) return;
    const rx = 11.0;
    const ry = 6.2;
    const lift = 4.6; // 1枚ごとの持ち上がり
    final cx = size.width / 2;
    final baseY = size.height - ry - 2;

    final fill = Paint();
    final edge = Paint();
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < chipCount; i++) {
      final cy = baseY - i * lift;
      final color = _colors[i % _colors.length];
      final faceRect =
          Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

      // チップの厚み(下側の暗い縁)。
      edge.color = AppColors.darken(color, 0.35);
      canvas.drawOval(faceRect.shift(const Offset(0, 2.2)), edge);
      // チップの面。
      fill.color = color;
      canvas.drawOval(faceRect, fill);

      // 白いエッジマーク (最上段のみ細部を描き、下段は省略して軽くする)。
      if (i == chipCount - 1) {
        rim
          ..strokeWidth = 2.6
          ..color = Colors.white.withValues(alpha: 0.9);
        final rimRect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: rx * 2 * 0.82,
          height: ry * 2 * 0.82,
        );
        for (var k = 0; k < 6; k++) {
          canvas.drawArc(rimRect, k * math.pi / 3, math.pi / 7, false, rim);
        }
        rim
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: 0.4);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: rx * 2 * 0.5,
            height: ry * 2 * 0.5,
          ),
          rim,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChipStackPainter oldDelegate) =>
      oldDelegate.chipCount != chipCount;
}
