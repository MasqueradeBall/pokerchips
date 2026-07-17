import 'dart:math';
import 'dart:ui';

/// プレイ画面のテーブル楕円まわりの座標計算。
///
/// _TableArea のバッジ配置と、ベットチップ表示・勝者へのチップ回収演出が
/// まったく同じ座標系を共有できるよう、楕円の中心/半径/角度→座標変換を
/// ここに一元化する。値を変えるとバッジとエフェクトの位置が同時にずれるので
/// 必ず両方を確認すること。
class TableGeometry {
  TableGeometry(this.width, this.height)
      : center = Offset(width / 2, height / 2 - 10),
        radiusX = max(width / 2 - 60, 60.0),
        radiusY = max(height / 2 - 70, 70.0);

  final double width;
  final double height;
  final Offset center;
  final double radiusX;
  final double radiusY;

  /// 自分のバッジは常に楕円の真下(90度)に置く。
  static const double selfAngle = 90;

  /// 角度(度)から楕円上のバッジアンカー座標を求める。
  /// バッジ(幅92)が画面外にはみ出さないよう座標をクランプする。
  Offset positionFor(double angleDeg) {
    final theta = angleDeg * pi / 180;
    final raw = center + Offset(radiusX * cos(theta), radiusY * sin(theta));
    return Offset(
      raw.dx.clamp(50.0, max(width - 50.0, 50.0)),
      raw.dy.clamp(64.0, max(height - 78.0, 64.0)),
    );
  }

  /// バッジアンカーからテーブル中央へ寄せた「ベットチップ置き場」の座標。
  Offset betPositionFor(double angleDeg) =>
      Offset.lerp(positionFor(angleDeg), center, 0.38)!;

  /// 他プレイヤーを楕円上に配置する角度リスト。
  /// 人数が多いほど扇を広げ、バッジ同士の重なりを減らす。
  static List<double> otherAngles(int count) {
    if (count == 0) return [];
    if (count == 1) return [270];
    final spread = count <= 3
        ? 150.0
        : count <= 5
            ? 190.0
            : 220.0;
    final start = 270 - spread / 2;
    final step = spread / (count - 1);
    return [for (var i = 0; i < count; i++) start + step * i];
  }
}
