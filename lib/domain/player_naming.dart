/// ルーム内で表示するプレイヤー名を決める。
///
/// - 名前が未入力なら「プレイヤー1」「プレイヤー2」…のうち未使用の最小番号を割り当てる。
/// - 入力された名前が既に使われていれば「名前(2)」「名前(3)」…と番号を付けて区別する。
String resolvePlayerName(String requested, Iterable<String> takenNames) {
  final taken = takenNames.toSet();
  final base = requested.trim();
  if (base.isEmpty) {
    for (var n = 1;; n++) {
      final candidate = 'プレイヤー$n';
      if (!taken.contains(candidate)) return candidate;
    }
  }
  if (!taken.contains(base)) return base;
  for (var n = 2;; n++) {
    final candidate = '$base($n)';
    if (!taken.contains(candidate)) return candidate;
  }
}
