import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// [trigger] の値が変化するたびに全画面のオールイン演出を再生する。
///
/// 演出ステージ:
/// 1. インパクト  — 金色のフラッシュ + 画面シェイク
/// 2. バースト    — ポーカーチップが回転しながら放射状に飛散、衝撃波リング、光条
/// 3. タイトル    — "ALL IN" が勢いよくスラムイン、ゴールドシマーが走る
/// 4. フェード    — 全体が沈むように消える
class AllInEffect extends StatefulWidget {
  const AllInEffect({super.key, required this.trigger, required this.playerName});

  final Object? trigger;
  final String playerName;

  @override
  State<AllInEffect> createState() => _AllInEffectState();
}

class _AllInEffectState extends State<AllInEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _random = math.Random();
  bool _visible = false;
  List<_ChipParticle> _chips = const [];
  List<_Spark> _sparks = const [];

  static const _chipColors = [
    AppColors.chipRed,
    AppColors.chipBlue,
    AppColors.chipGreen,
    AppColors.gold,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  }

  @override
  void didUpdateWidget(covariant AllInEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && widget.trigger != null) {
      _play();
    }
  }

  void _play() {
    // パーティクルの初期パラメータは再生開始時に一度だけ生成する。
    _chips = List.generate(26, (i) {
      final angle = (i / 26) * math.pi * 2 + _random.nextDouble() * 0.4;
      return _ChipParticle(
        angle: angle,
        speed: 0.45 + _random.nextDouble() * 0.55,
        radius: 9.0 + _random.nextDouble() * 8.0,
        spin: (_random.nextDouble() * 2 - 1) * math.pi * 6,
        color: _chipColors[_random.nextInt(_chipColors.length)],
        delay: _random.nextDouble() * 0.08,
        wobble: _random.nextDouble() * math.pi * 2,
      );
    });
    _sparks = List.generate(36, (i) {
      final angle = _random.nextDouble() * math.pi * 2;
      return _Spark(
        angle: angle,
        speed: 0.5 + _random.nextDouble() * 0.7,
        size: 1.2 + _random.nextDouble() * 2.4,
        delay: _random.nextDouble() * 0.12,
        gold: _random.nextBool(),
      );
    });
    setState(() => _visible = true);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // 全体の透明度: 素早く立ち上がり、終盤で沈み込むように消える。
          final fadeIn = (t / 0.06).clamp(0.0, 1.0);
          final fadeOut = t > 0.82 ? (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0) : 1.0;
          final opacity = fadeIn * Curves.easeInOut.transform(fadeOut);

          // インパクト直後の減衰シェイク。
          final shakeEnv = math.exp(-t * 14) * 9.0;
          final shakeX = math.sin(t * 90) * shakeEnv;
          final shakeY = math.cos(t * 73) * shakeEnv * 0.6;

          // 金色フラッシュ (t≈0.05 でピーク)。
          final flash = t < 0.14 ? math.sin((t / 0.14) * math.pi) * 0.55 : 0.0;

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 暗転ビネット: 中央がわずかに明るい放射グラデーション。
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.1,
                        colors: [
                          AppColors.feltGreenDark.withValues(alpha: 0.62),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                  // 光条・衝撃波・チップ・スパークをまとめて描画。
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _AllInBurstPainter(t: t, chips: _chips, sparks: _sparks),
                    ),
                  ),
                  // タイトルテキスト。
                  Center(child: _buildTitle(t)),
                  // インパクトフラッシュ。
                  if (flash > 0)
                    ColoredBox(color: AppColors.goldLight.withValues(alpha: flash)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(double t) {
    // スラムイン: 大きい状態から勢いよく等倍へ (わずかにオーバーシュート)。
    final appear = ((t - 0.04) / 0.2).clamp(0.0, 1.0);
    final slam = Curves.easeOutBack.transform(appear);
    final scale = 2.4 - 1.4 * slam;
    if (appear <= 0) return const SizedBox.shrink();

    // シマー光: タイトル定着後にテキスト上を左から右へ走る。
    final shimmer = ((t - 0.28) / 0.4).clamp(0.0, 1.0);
    final shimmerX = -1.6 + shimmer * 3.2;

    // 余韻の鼓動: 定着後にごくわずかに脈打つ。
    final pulse = t > 0.3 ? 1.0 + math.sin((t - 0.3) * math.pi * 5) * 0.015 : 1.0;

    return Transform.scale(
      scale: scale * pulse,
      child: Opacity(
        opacity: appear,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(shimmerX - 0.7, -0.3),
                  end: Alignment(shimmerX + 0.7, 0.3),
                  colors: const [
                    AppColors.gold,
                    AppColors.goldLight,
                    Colors.white,
                    AppColors.goldLight,
                    AppColors.gold,
                  ],
                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                ).createShader(bounds);
              },
              child: const Text(
                'ALL IN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  height: 1.0,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 18, offset: Offset(0, 4)),
                    Shadow(color: AppColors.gold, blurRadius: 30),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _goldDivider(reversed: false),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.playerName,
                    style: const TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                ),
                _goldDivider(reversed: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _goldDivider({required bool reversed}) {
    return Container(
      width: 56,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reversed ? Alignment.centerRight : Alignment.centerLeft,
          end: reversed ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            AppColors.gold.withValues(alpha: 0),
            AppColors.goldLight,
          ],
        ),
      ),
    );
  }
}

/// 飛散するポーカーチップ 1 枚分の初期パラメータ。
class _ChipParticle {
  const _ChipParticle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.spin,
    required this.color,
    required this.delay,
    required this.wobble,
  });

  final double angle;
  final double speed;
  final double radius;
  final double spin;
  final Color color;
  final double delay;
  final double wobble;
}

/// 小さな火花パーティクルの初期パラメータ。
class _Spark {
  const _Spark({
    required this.angle,
    required this.speed,
    required this.size,
    required this.delay,
    required this.gold,
  });

  final double angle;
  final double speed;
  final double size;
  final double delay;
  final bool gold;
}

/// 光条・衝撃波リング・チップ・スパークを 1 パスで描画するペインタ。
class _AllInBurstPainter extends CustomPainter {
  _AllInBurstPainter({required this.t, required this.chips, required this.sparks});

  final double t;
  final List<_ChipParticle> chips;
  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height) / 2;

    _paintRays(canvas, center, maxR);
    _paintShockwaves(canvas, center, maxR);
    _paintChips(canvas, center, maxR);
    _paintSparks(canvas, center, maxR);
  }

  /// 中央から放射する回転光条。
  void _paintRays(Canvas canvas, Offset center, double maxR) {
    final visible = ((t - 0.08) / 0.15).clamp(0.0, 1.0);
    if (visible <= 0) return;
    final fade = t > 0.7 ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
    final alpha = 0.14 * visible * fade;
    if (alpha <= 0.004) return;

    const rayCount = 12;
    final rotation = t * 0.6;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.goldLight.withValues(alpha: alpha),
          AppColors.gold.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    for (var i = 0; i < rayCount; i++) {
      final a = (i / rayCount) * math.pi * 2;
      const halfWidth = 0.075;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a - halfWidth) * maxR,
          center.dy + math.sin(a - halfWidth) * maxR,
        )
        ..lineTo(
          center.dx + math.cos(a + halfWidth) * maxR,
          center.dy + math.sin(a + halfWidth) * maxR,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  /// 拡大しながら消える二重の衝撃波リング。
  void _paintShockwaves(Canvas canvas, Offset center, double maxR) {
    for (var i = 0; i < 2; i++) {
      final start = 0.03 + i * 0.09;
      final progress = ((t - start) / 0.55).clamp(0.0, 1.0);
      if (progress <= 0 || progress >= 1) continue;
      final eased = Curves.easeOutCubic.transform(progress);
      final radius = maxR * 0.9 * eased;
      final alpha = (1 - eased) * (i == 0 ? 0.85 : 0.5);
      final stroke = (1 - eased) * (i == 0 ? 7.0 : 4.0) + 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = (i == 0 ? AppColors.goldLight : AppColors.gold).withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }
  }

  /// 回転しながら放射状に飛散するポーカーチップ。
  void _paintChips(Canvas canvas, Offset center, double maxR) {
    final basePaint = Paint();
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final chip in chips) {
      final tp = ((t - 0.06 - chip.delay) / 0.8).clamp(0.0, 1.0);
      if (tp <= 0 || tp >= 1) continue;
      final eased = Curves.easeOutCubic.transform(tp);
      final dist = maxR * chip.speed * eased;
      // わずかな重力落下と横揺れで軌道に表情を付ける。
      final gravity = 90.0 * tp * tp;
      final sway = math.sin(chip.wobble + tp * math.pi * 2) * 6.0;
      final pos = Offset(
        center.dx + math.cos(chip.angle) * dist + sway,
        center.dy + math.sin(chip.angle) * dist + gravity,
      );
      final alpha = tp > 0.65 ? ((1 - tp) / 0.35).clamp(0.0, 1.0) : 1.0;
      final rot = chip.spin * tp;
      // 回転に合わせて縦に潰し、コインが翻る立体感を出す。
      final flip = 0.35 + 0.65 * math.cos(tp * math.pi * 3 + chip.wobble).abs();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot);
      canvas.scale(1.0, flip);

      basePaint.color = chip.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset.zero, chip.radius, basePaint);

      // チップ縁の白いエッジマーク。
      rimPaint
        ..strokeWidth = chip.radius * 0.3
        ..color = Colors.white.withValues(alpha: alpha * 0.9);
      final rimRect = Rect.fromCircle(center: Offset.zero, radius: chip.radius * 0.84);
      for (var i = 0; i < 6; i++) {
        canvas.drawArc(rimRect, i * math.pi / 3, math.pi / 7, false, rimPaint);
      }

      innerPaint.color = Colors.white.withValues(alpha: alpha * 0.45);
      canvas.drawCircle(Offset.zero, chip.radius * 0.52, innerPaint);

      canvas.restore();
    }
  }

  /// 金色の小さな火花。
  void _paintSparks(Canvas canvas, Offset center, double maxR) {
    final paint = Paint();
    for (final spark in sparks) {
      final tp = ((t - 0.04 - spark.delay) / 0.6).clamp(0.0, 1.0);
      if (tp <= 0 || tp >= 1) continue;
      final eased = Curves.easeOutQuart.transform(tp);
      final dist = maxR * spark.speed * eased;
      final pos = Offset(
        center.dx + math.cos(spark.angle) * dist,
        center.dy + math.sin(spark.angle) * dist + 40.0 * tp * tp,
      );
      final alpha = (1 - tp) * 0.9;
      paint.color = (spark.gold ? AppColors.goldLight : Colors.white).withValues(alpha: alpha);
      canvas.drawCircle(pos, spark.size * (1 - tp * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AllInBurstPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.chips != chips || oldDelegate.sparks != sparks;
  }
}
