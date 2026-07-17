import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 本物のカジノテーブルのイラスト風に描いた楕円テーブル面。
///
/// レイヤー構成 (外側から内側へ):
///   1. テーブル下の落ち影
///   2. レザー調のパッド付きレール (上から光が当たった立体的な断面)
///   3. ゴールドのピンストライプ付きダークウッドのインレイリング
///   4. フェルト面 (上方からのライティング + 繊維ノイズテクスチャ)
///   5. フェルト端のアンビエントオクルージョン影
///   6. 破線のベッティングライン・淡いスートモチーフ・センターメダリオン
///
/// 完全に静的な背景なので [RepaintBoundary] で分離し、
/// 親の再ビルド (ゲーム状態の変化ごとに起きる) では再描画しない。
class CasinoTableSurface extends StatelessWidget {
  const CasinoTableSurface({
    super.key,
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: const _CasinoTablePainter(),
      ),
    );
  }
}

class _CasinoTablePainter extends CustomPainter {
  const _CasinoTablePainter();

  // レザーレールの色。ゴールド/グリーンの世界観に合うダークブラウン。
  static const _leatherHi = Color(0xFF5A4430);
  static const _railTop = Color(0xFF55402C);
  static const _railBottom = Color(0xFF16100A);
  static const _inlayTop = Color(0xFF10201A);
  static const _inlayBottom = Color(0xFF060D09);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final minR = min(rect.width, rect.height) / 2;

    // 各リングの太さ。小さな画面でも潰れないようにクランプする。
    final railW = (minR * 0.30).clamp(11.0, 22.0);
    final inlayW = (railW * 0.42).clamp(4.0, 9.0);
    final outer = rect;
    final railInner = outer.deflate(railW);
    final felt = outer.deflate(railW + inlayW);
    if (felt.width <= 0 || felt.height <= 0) return;

    _paintDropShadow(canvas, outer);
    _paintRail(canvas, outer, railInner, railW);
    _paintInlay(canvas, railInner, felt);
    _paintFelt(canvas, felt, railW);
    _paintFeltDecoration(canvas, felt, minR);
  }

  /// 1. テーブル全体の落ち影。床から浮いているように見せる。
  void _paintDropShadow(Canvas canvas, Rect outer) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(outer.shift(const Offset(0, 7)).inflate(2), paint);
  }

  /// 2. パッド付きレザーレール。上端にハイライト・下端に深い影を入れ、
  /// 断面が丸く盛り上がって見えるようにする。
  void _paintRail(Canvas canvas, Rect outer, Rect railInner, double railW) {
    final ring = Path()
      ..addOval(outer)
      ..addOval(railInner)
      ..fillType = PathFillType.evenOdd;

    // ベースのレザーグラデーション (上から光が当たる)。
    canvas.drawPath(
      ring,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_railTop, Color(0xFF2C1F13), _railBottom],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(outer),
    );

    canvas.save();
    canvas.clipPath(ring);

    // 上縁のスペキュラーハイライト: レール断面の丸みを出す。
    canvas.drawOval(
      outer.deflate(railW * 0.28),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = railW * 0.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _leatherHi.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.18, 0.55],
        ).createShader(outer)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 下側の照り返し (ゴールドの環境光をほんのり反射)。
    canvas.drawOval(
      outer.deflate(railW * 0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = railW * 0.4
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.gold.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4],
        ).createShader(outer)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // レール内縁の折り返し影 (パッドが内側に落ちる継ぎ目)。
    canvas.drawOval(
      railInner.inflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();

    // 外縁のゴールドトリム。
    canvas.drawOval(
      outer.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.gold.withValues(alpha: 0.45),
    );
  }

  /// 3. レールとフェルトの間のダークウッド調インレイリング。
  void _paintInlay(Canvas canvas, Rect railInner, Rect felt) {
    final ring = Path()
      ..addOval(railInner)
      ..addOval(felt)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      ring,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_inlayTop, _inlayBottom],
        ).createShader(railInner),
    );

    // インレイ両側のゴールドピンストライプ。
    final pinstripe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.gold.withValues(alpha: 0.32);
    canvas.drawOval(railInner.deflate(0.8), pinstripe);
    canvas.drawOval(felt.inflate(0.8), pinstripe);
  }

  /// 4. フェルト面。楕円に沿ったラジアルグラデーション + 繊維ノイズ。
  void _paintFelt(Canvas canvas, Rect felt, double railW) {
    final feltPath = Path()..addOval(felt);
    final c = felt.center;
    final rx = felt.width / 2;
    final ry = felt.height / 2;

    canvas.save();
    canvas.clipPath(feltPath);

    // 楕円形のラジアルグラデーション: 座標系をスケールして円→楕円に変換。
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1.0, ry / rx);
    canvas.drawCircle(
      Offset(0, -rx * 0.12),
      rx * 1.15,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(0, -rx * 0.12),
          rx * 1.15,
          [
            const Color(0xFF227A41),
            AppColors.feltGreenLight,
            AppColors.feltGreen,
            AppColors.feltGreenDark,
          ],
          [0.0, 0.38, 0.78, 1.0],
        ),
    );
    canvas.restore();

    _paintFeltNoise(canvas, felt);

    // 5. フェルト端のアンビエントオクルージョン。
    // クリップ済みなのでストロークの内側半分だけが写り、内影になる。
    canvas.drawOval(
      felt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = railW * 1.3
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.restore();
  }

  /// フェルトの織り目を思わせる決定論的なノイズテクスチャ。
  /// シード固定なのでリビルドしても模様は変わらない。
  void _paintFeltNoise(Canvas canvas, Rect felt) {
    final rng = Random(20260717);
    final c = felt.center;
    final rx = felt.width / 2;
    final ry = felt.height / 2;

    bool inside(double x, double y) {
      final nx = (x - c.dx) / rx;
      final ny = (y - c.dy) / ry;
      return nx * nx + ny * ny <= 1.0;
    }

    final lightDots = <Offset>[];
    final darkDots = <Offset>[];
    for (var i = 0; i < 1400; i++) {
      final x = felt.left + rng.nextDouble() * felt.width;
      final y = felt.top + rng.nextDouble() * felt.height;
      if (!inside(x, y)) continue;
      (i.isEven ? lightDots : darkDots).add(Offset(x, y));
    }
    canvas.drawPoints(
      ui.PointMode.points,
      lightDots,
      Paint()
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.028),
    );
    canvas.drawPoints(
      ui.PointMode.points,
      darkDots,
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.05),
    );

    // 短い繊維ストローク。方向をわずかに散らして布らしさを出す。
    final fibers = <Offset>[];
    for (var i = 0; i < 320; i++) {
      final x = felt.left + rng.nextDouble() * felt.width;
      final y = felt.top + rng.nextDouble() * felt.height;
      if (!inside(x, y)) continue;
      final angle = rng.nextDouble() * pi;
      final len = 2.5 + rng.nextDouble() * 4.0;
      final d = Offset(cos(angle), sin(angle)) * (len / 2);
      fibers
        ..add(Offset(x, y) - d)
        ..add(Offset(x, y) + d);
    }
    canvas.drawPoints(
      ui.PointMode.lines,
      fibers,
      Paint()
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.02),
    );
  }

  /// 6. ベッティングライン・スートモチーフ・センターメダリオン。
  void _paintFeltDecoration(Canvas canvas, Rect felt, double minR) {
    final c = felt.center;

    // 破線のベッティングライン。
    final lineRect = Rect.fromCenter(
      center: c,
      width: felt.width * 0.80,
      height: felt.height * 0.74,
    );
    final dashed = _dashPath(Path()..addOval(lineRect), 10, 7);
    canvas.drawPath(
      dashed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold.withValues(alpha: 0.20),
    );

    // 四隅に淡いスートモチーフ。ポットやバッジと競合しないよう極薄に。
    final suitSize = (minR * 0.22).clamp(9.0, 15.0);
    final sx = lineRect.width / 2 * 0.72;
    final sy = lineRect.height / 2 * 0.62;
    final suitPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;
    _drawSuit(canvas, c + Offset(-sx, -sy), suitSize, _Suit.spade, suitPaint);
    _drawSuit(canvas, c + Offset(sx, -sy), suitSize, _Suit.heart, suitPaint);
    _drawSuit(canvas, c + Offset(-sx, sy), suitSize, _Suit.club, suitPaint);
    _drawSuit(canvas, c + Offset(sx, sy), suitSize, _Suit.diamond, suitPaint);

    // センター手前 (ポットの下側) にごく淡いゴールドのメダリオン。
    final mCenter = c + Offset(0, felt.height / 2 * 0.52);
    final mRadius = (minR * 0.30).clamp(13.0, 22.0);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.gold.withValues(alpha: 0.13);
    canvas.drawCircle(mCenter, mRadius, ringPaint);
    canvas.drawCircle(
      mCenter,
      mRadius * 0.78,
      ringPaint..color = AppColors.gold.withValues(alpha: 0.08),
    );
    _drawSuit(
      canvas,
      mCenter,
      mRadius * 0.85,
      _Suit.spade,
      Paint()..color = AppColors.gold.withValues(alpha: 0.09),
    );
  }

  Path _dashPath(Path source, double dashLen, double gapLen) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        out.addPath(
          metric.extractPath(d, min(d + dashLen, metric.length)),
          Offset.zero,
        );
        d += dashLen + gapLen;
      }
    }
    return out;
  }

  /// スートのシルエットを円と三角形の組み合わせで近似して描く。
  void _drawSuit(
    Canvas canvas,
    Offset center,
    double s,
    _Suit suit,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    switch (suit) {
      case _Suit.diamond:
        final p = Path()
          ..moveTo(0, -s * 0.5)
          ..lineTo(s * 0.36, 0)
          ..lineTo(0, s * 0.5)
          ..lineTo(-s * 0.36, 0)
          ..close();
        canvas.drawPath(p, paint);
      case _Suit.heart:
        final r = s * 0.24;
        canvas.drawCircle(Offset(-s * 0.2, -s * 0.16), r, paint);
        canvas.drawCircle(Offset(s * 0.2, -s * 0.16), r, paint);
        final p = Path()
          ..moveTo(-s * 0.43, -s * 0.06)
          ..lineTo(s * 0.43, -s * 0.06)
          ..lineTo(0, s * 0.5)
          ..close();
        canvas.drawPath(p, paint);
      case _Suit.spade:
        final r = s * 0.24;
        canvas.drawCircle(Offset(-s * 0.19, s * 0.04), r, paint);
        canvas.drawCircle(Offset(s * 0.19, s * 0.04), r, paint);
        final body = Path()
          ..moveTo(0, -s * 0.5)
          ..lineTo(-s * 0.4, s * 0.08)
          ..lineTo(s * 0.4, s * 0.08)
          ..close();
        canvas.drawPath(body, paint);
        _drawStem(canvas, s, paint);
      case _Suit.club:
        final r = s * 0.21;
        canvas.drawCircle(Offset(0, -s * 0.24), r, paint);
        canvas.drawCircle(Offset(-s * 0.2, s * 0.02), r, paint);
        canvas.drawCircle(Offset(s * 0.2, s * 0.02), r, paint);
        _drawStem(canvas, s, paint);
    }
    canvas.restore();
  }

  void _drawStem(Canvas canvas, double s, Paint paint) {
    final stem = Path()
      ..moveTo(0, s * 0.02)
      ..lineTo(-s * 0.16, s * 0.5)
      ..lineTo(s * 0.16, s * 0.5)
      ..close();
    canvas.drawPath(stem, paint);
  }

  // 完全に静的な絵なので、同一サイズでの再描画は不要。
  // サイズが変わった場合は RenderCustomPaint がレイアウト経由で
  // 自動的に再ペイントを行うため、ここは常に false でよい。
  @override
  bool shouldRepaint(covariant _CasinoTablePainter oldDelegate) => false;
}

enum _Suit { spade, heart, diamond, club }
