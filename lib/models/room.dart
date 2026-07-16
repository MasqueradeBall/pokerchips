import 'action_log.dart';
import 'enums.dart';

class Room {
  Room({
    required this.code,
    required this.hostPlayerId,
    this.phase = GamePhase.lobby,
    this.pot = 0,
    this.highestBet = 0,
    this.turnOrder = const [],
    this.pendingToActPlayerIds = const [],
    this.lastAction,
    this.systemMessage,
    this.adWaitingPlayerId,
    this.adWaitingDeadline,
  });

  final String code;
  final String hostPlayerId;
  final GamePhase phase;
  final int pot;
  final int highestBet;
  final List<String> turnOrder;
  final List<String> pendingToActPlayerIds;
  final ActionLog? lastAction;
  final String? systemMessage;
  final String? adWaitingPlayerId;
  final DateTime? adWaitingDeadline;

  String? get currentTurnPlayerId =>
      pendingToActPlayerIds.isEmpty ? null : pendingToActPlayerIds.first;

  Room copyWith({
    GamePhase? phase,
    int? pot,
    int? highestBet,
    List<String>? turnOrder,
    List<String>? pendingToActPlayerIds,
    ActionLog? lastAction,
    bool clearLastAction = false,
    String? systemMessage,
    bool clearSystemMessage = false,
    String? adWaitingPlayerId,
    bool clearAdWaiting = false,
    DateTime? adWaitingDeadline,
  }) {
    return Room(
      code: code,
      hostPlayerId: hostPlayerId,
      phase: phase ?? this.phase,
      pot: pot ?? this.pot,
      highestBet: highestBet ?? this.highestBet,
      turnOrder: turnOrder ?? this.turnOrder,
      pendingToActPlayerIds: pendingToActPlayerIds ?? this.pendingToActPlayerIds,
      lastAction: clearLastAction ? null : (lastAction ?? this.lastAction),
      systemMessage:
          clearSystemMessage ? null : (systemMessage ?? this.systemMessage),
      adWaitingPlayerId:
          clearAdWaiting ? null : (adWaitingPlayerId ?? this.adWaitingPlayerId),
      adWaitingDeadline:
          clearAdWaiting ? null : (adWaitingDeadline ?? this.adWaitingDeadline),
    );
  }
}
