import '../domain/game_state.dart';

/// UIに配信する1画面分のスナップショット。
/// canUndo は「直前の1手」を取り消せるかどうか(ローカル実装ではベットアクション後のみtrue)。
class RoomSnapshot {
  const RoomSnapshot({
    required this.state,
    required this.canUndo,
    required this.selfPlayerId,
  });

  final GameState state;
  final bool canUndo;
  final String selfPlayerId;
}
