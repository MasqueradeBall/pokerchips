import 'enums.dart';

/// 直近アクションの表示用ログ。Undoボタンは
/// 「room.lastAction?.playerId のバッジ」にのみ表示される。
class ActionLog {
  const ActionLog({
    required this.playerId,
    required this.playerName,
    required this.actionType,
    required this.displayText,
  });

  final String playerId;
  final String playerName;
  final ActionType actionType;
  final String displayText;
}
