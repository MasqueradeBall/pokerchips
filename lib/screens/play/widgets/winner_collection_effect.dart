import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/player.dart';
import 'table_geometry.dart';

/// ショーダウンで勝者が確定したとき、ポット(と各プレイヤーの前)から
/// チップが勝者のもとへ吸い寄せられていく「ディーラーがポットを押し出す」
/// 演出。
///
/// [trigger] の値が変化するたびに再生する (AllInEffect と同じ方式)。
/// 再生開始時点の [winnerIds] / [players] をスナップショットして飛行
/// パラメータを一度だけ生成するので、再生中に状態が変わっても乱れない。
///
/// このウィジェット自体はゲーム状態を一切変更しない。実際の
/// `awardPot` 呼び出しは呼び出し側が [duration] 経過後に行う。
class WinnerCollectionEffect extends StatefulWidget {
  const WinnerCollectionEffect({
    super.key,
    required this.trigger,
    required this.winnerIds,
    required this.players,
    required this.selfId,
  });

  /// 演出の全長。呼び出し側はこの時間の経過後に awardPot を呼ぶこと。
  static const Duration duration = Duration(milliseconds: 1500);

  final Object? trigger;
  final List<String> winnerIds;

  /// 着席中の全プレイヤー (_TableArea と同じ順序であること)。
  final List<Player> players;
  final String selfId;

  @override
  State<WinnerCollectionEffect> createState() => _WinnerCollectionEffectState();
}

class _WinnerCollectionEffectState extends State<WinnerCollectionEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WinnerCollectionEffect.duration,
  );
  final math.Random _random = math.Random();

  bool _visible = false;
  List<_ChipFlight> _flights = const [];
  List<double> _winnerAngles = const [];

  static const _chipColors = [
    AppColors.chipRed,
    AppColors.chipBlue,
    AppColors.chipGreen,
    AppColors.gold,
  ];

  @override
  void didUpdateWidget(covariant WinnerCollectionEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && widget.trigger != null) {
      _play();
    }
  }

  void _play() {
    // バッジ配置と同じロジックでプレイヤーID→角度を解決する。
    final others =
        widget.players.where((p) => p.id != widget.selfId).toList();
    final angles = TableGeometry.otherAngles(others.length);
    double? angleFor(String id) {
      if (id == widget.selfId) return TableGeometry.selfAngle;
      final i = others.indexWhere((p) => p.id == id);
      return i < 0 ? null : angles[i];
    }

    final winnerAngles = widget.winnerIds
        .map(angleFor)
        .whereType<double>()
        .toList();
    if (winnerAngles.isEmpty) return;

    // 発生源: ポット中央 (null) + ハンドに残っている敗者たちの席。
    final sourceAngles = <double?>[null];
    for (final p in widget.players) {
      if (!p.isInHand || widget.winnerIds.contains(p.id)) continue;
      final a = angleFor(p.id);
      if (a != null) sourceAngles.add(a);
    }

    // 飛行パラメータは再生開始時に一度だけ生成する。
    final flights = <_ChipFlight>[];
    var w = 0;
    for (final src in sourceAngles) {
      final count = src == null ? 16 : 3;
      for (var i = 0; i < count; i++) {
        flights.add(
          _ChipFlight(
            sourceAngle: src,
            targetAngle: winnerAngles[w++ % winnerAngles.length],
            scatter: Offset(
              (_random.nextDouble() * 2 - 1) * (src == null ? 30 : 18),
              (_random.nextDouble() * 2 - 1) * (src == null ? 16 : 10),
            ),
            bend: (_random.nextDouble() * 2 - 1) * 64,
            delay: _random.nextDouble() * 0.3,
            radius: 7.0 + _random.nextDouble() * 4.0,
            spin: (_random.nextDouble() * 2 - 1) * math.pi * 4,
            wobble: _random.nextDouble() * math.pi * 2,
            color: _chipColors[_random.nextInt(_chipColors.length)],
          ),
        );
      }
    }

    _flights = flights;
    _winnerAngles = winnerAngles;
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
          // 終盤はふわっと消える (直後に実際のチップ移動/フェーズ遷移が来る)。
          final fadeOut =
              t > 0.9 ? (1 - (t - 0.9) / 0.1).clamp(0.0, 1.0) : 1.0;
          return Opacity(
            opacity: Curves.easeOut.transform(fadeOut),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _CollectionPainter(
                  t: t,
                  flights: _flights,
                  winnerAngles: _winnerAngles,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// チップ 1 枚分の飛行パラメータ (再生開始時に確定)。
class _ChipFlight {
  const _ChipFlight({
    required this.sourceAngle,
    required this.targetAngle,
    required this.scatter,
    required this.bend,
    required this.delay,
    required this.radius,
    required this.spin,
    required this.wobble,
    required this.color,
  });

  /// 発生源の席の角度。null ならポット中央から。
  final double? sourceAngle;
  final double targetAngle;

  /// 発生源まわりの散らばり。
  final Offset scatter;

  /// 軌道の膨らみ (進行方向に対して垂直方向のオフセット)。
  final double bend;
  final double delay;
  final double radius;
  final double spin;
  final double wobble;
  final Color color;
}

/// ポット発光 → チップ飛行 → 勝者の金色グロー/リングを 1 パスで描画する。
class _CollectionPainter extends CustomPainter {
  _CollectionPainter({
    required this.t,
    required this.flights,
    required this.winnerAngles,
  });

  final double t;
  final List<_ChipFlight> flights;
  final List<double> winnerAngles;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = TableGeometry(size.width, size.height);

    _paintPotPulse(canvas, geo);
    _paintChips(canvas, geo);
    _paintWinnerGlow(canvas, geo);
  }

  Offset _sourcePoint(TableGeometry geo, double? angle) => angle == null
      ? geo.center
      : Offset.lerp(geo.positionFor(angle), geo.center, 0.22)!;

  /// 冒頭、ポットからチップが浮き上がる合図の金色リング。
  void _paintPotPulse(Canvas canvas, TableGeometry geo) {
    final p = (t / 0.25).clamp(0.0, 1.0);
    if (p <= 0 || p >= 1) return;
    final eased = Curves.easeOutCubic.transform(p);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1 - eased) * 4 + 1
      ..color = AppColors.goldLight.withValues(alpha: (1 - eased) * 0.7);
    canvas.drawCircle(geo.center, 18 + 46 * eased, paint);
  }

  /// 発生源から勝者へ、二次ベジェの弧を描いて飛ぶチップ。
  void _paintChips(Canvas canvas, TableGeometry geo) {
    final basePaint = Paint();
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final flight in flights) {
      final p = ((t - flight.delay) / 0.62).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final eased = Curves.easeInOutCubic.transform(p);

      final s = _sourcePoint(geo, flight.sourceAngle) + flight.scatter;
      final e = geo.positionFor(flight.targetAngle);
      final delta = e - s;
      final len = delta.distance;
      final normal = len < 1e-3
          ? Offset.zero
          : Offset(-delta.dy / len, delta.dx / len);
      final ctrl = s + delta / 2 + normal * flight.bend;

      // 二次ベジェ補間。
      final u = 1 - eased;
      final pos = s * (u * u) + ctrl * (2 * u * eased) + e * (eased * eased);

      final fadeIn = (p / 0.15).clamp(0.0, 1.0);
      final absorb = p > 0.85 ? ((1 - p) / 0.15).clamp(0.0, 1.0) : 1.0;
      final alpha = fadeIn * (0.35 + 0.65 * absorb);
      final scale = (0.7 + 0.3 * fadeIn) * (0.55 + 0.45 * absorb);
      final rot = flight.spin * p;
      // 回転に合わせて縦に潰し、チップが翻る立体感を出す (ALL IN と同じ意匠)。
      final flip =
          0.4 + 0.6 * math.cos(p * math.pi * 2 + flight.wobble).abs();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot);
      canvas.scale(scale, scale * flip);

      basePaint.color = flight.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset.zero, flight.radius, basePaint);

      rimPaint
        ..strokeWidth = flight.radius * 0.3
        ..color = Colors.white.withValues(alpha: alpha * 0.9);
      final rimRect =
          Rect.fromCircle(center: Offset.zero, radius: flight.radius * 0.84);
      for (var i = 0; i < 6; i++) {
        canvas.drawArc(rimRect, i * math.pi / 3, math.pi / 7, false, rimPaint);
      }

      innerPaint.color = Colors.white.withValues(alpha: alpha * 0.45);
      canvas.drawCircle(Offset.zero, flight.radius * 0.52, innerPaint);

      canvas.restore();
    }
  }

  /// チップが集まってきた勝者の席に灯る金色のグローと祝福リング。
  void _paintWinnerGlow(Canvas canvas, TableGeometry geo) {
    final glow = Curves.easeIn.transform(((t - 0.3) / 0.45).clamp(0.0, 1.0));
    if (glow <= 0) return;

    for (final angle in winnerAngles) {
      final target = geo.positionFor(angle);

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.goldLight.withValues(alpha: 0.4 * glow),
            AppColors.gold.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: target, radius: 62));
      canvas.drawCircle(target, 62, glowPaint);

      // 終盤に外へ広がるリング。
      final rp = ((t - 0.74) / 0.26).clamp(0.0, 1.0);
      if (rp > 0 && rp < 1) {
        final eased = Curves.easeOutCubic.transform(rp);
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - eased) * 4.5 + 0.8
          ..color = AppColors.goldLight.withValues(alpha: (1 - eased) * 0.85);
        canvas.drawCircle(target, 20 + 52 * eased, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CollectionPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.flights != flights ||
      oldDelegate.winnerAngles != winnerAngles;
}
