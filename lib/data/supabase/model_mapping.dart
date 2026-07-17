import '../../core/constants.dart';
import '../../domain/game_state.dart';
import '../../models/action_log.dart';
import '../../models/enums.dart';
import '../../models/player.dart';
import '../../models/room.dart';

/// Supabaseの行(Map)とドメインモデルを相互変換するヘルパー。
/// キー名はDBの実カラム名(snake_case)と一致させており、
/// previous_snapshot(jsonb)にもそのまま同じキー名で保存することで
/// 1組の関数でDB行/スナップショットJSONの両方を扱えるようにしている。

Map<String, dynamic> actionLogToJson(ActionLog log) => {
      'playerId': log.playerId,
      'playerName': log.playerName,
      'actionType': log.actionType.name,
      'displayText': log.displayText,
    };

ActionLog actionLogFromJson(Map<String, dynamic> json) => ActionLog(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      actionType: ActionType.values.byName(json['actionType'] as String),
      displayText: json['displayText'] as String,
    );

Player playerFromRow(Map<String, dynamic> row) {
  return Player(
    id: row['id'] as String,
    name: row['name'] as String,
    chips: row['chips'] as int,
    currentBet: row['current_bet'] as int,
    handContribution: row['hand_contribution'] as int,
    hearts: row['hearts'] as int,
    isAdFree: row['is_ad_free'] as bool,
    borrowCount: row['borrow_count'] as int,
    status: PlayerStatus.values.byName(row['status'] as String),
    isHost: row['is_host'] as bool,
  );
}

/// playerの可変フィールドをUPDATE/スナップショット保存用のMapにする。
/// id/room_idは呼び出し側で必要に応じて追加する。
Map<String, dynamic> playerToRow(Player player) => {
      'id': player.id,
      'name': player.name,
      'chips': player.chips,
      'current_bet': player.currentBet,
      'hand_contribution': player.handContribution,
      'hearts': player.hearts,
      'is_ad_free': player.isAdFree,
      'borrow_count': player.borrowCount,
      'status': player.status.name,
      'is_host': player.isHost,
    };

Room roomFromRow(Map<String, dynamic> row) {
  return Room(
    code: row['room_code'] as String,
    hostPlayerId: row['host_player_id'] as String? ?? '',
    phase: GamePhase.values.byName(row['phase'] as String),
    pot: row['pot'] as int,
    highestBet: row['highest_bet'] as int,
    turnOrder: (row['turn_order'] as List).cast<String>(),
    pendingToActPlayerIds: (row['pending_to_act'] as List).cast<String>(),
    lastAction: row['last_action'] == null
        ? null
        : actionLogFromJson(row['last_action'] as Map<String, dynamic>),
    systemMessage: row['system_message'] as String?,
    revealMessage: row['reveal_message'] as String?,
    adWaitingPlayerId: row['ad_waiting_player_id'] as String?,
    adWaitingDeadline: row['ad_waiting_deadline'] == null
        ? null
        : DateTime.parse(row['ad_waiting_deadline'] as String).toLocal(),
    // as int? ?? デフォルト値: マイグレーション前の古いroom行にも耐えるようにする。
    smallBlind: row['small_blind'] as int? ?? 0,
    bigBlind: row['big_blind'] as int? ?? 0,
    ante: row['ante'] as int? ?? 0,
    startingStack: row['starting_stack'] as int? ?? GameConstants.initialStack,
    smallBlindPlayerId: row['small_blind_player_id'] as String?,
    bigBlindPlayerId: row['big_blind_player_id'] as String?,
  );
}

/// roomの可変フィールドをUPDATE/スナップショット保存用のMapにする。
Map<String, dynamic> roomToRow(Room room) => {
      'room_code': room.code,
      'host_player_id': room.hostPlayerId,
      'phase': room.phase.name,
      'pot': room.pot,
      'highest_bet': room.highestBet,
      'turn_order': room.turnOrder,
      'pending_to_act': room.pendingToActPlayerIds,
      'last_action': room.lastAction == null ? null : actionLogToJson(room.lastAction!),
      'system_message': room.systemMessage,
      'reveal_message': room.revealMessage,
      'ad_waiting_player_id': room.adWaitingPlayerId,
      'ad_waiting_deadline': room.adWaitingDeadline?.toUtc().toIso8601String(),
      'small_blind': room.smallBlind,
      'big_blind': room.bigBlind,
      'ante': room.ante,
      'starting_stack': room.startingStack,
      'small_blind_player_id': room.smallBlindPlayerId,
      'big_blind_player_id': room.bigBlindPlayerId,
    };

/// Undo用にGameState全体をJSONへ変換する。
Map<String, dynamic> gameStateToSnapshotJson(GameState state) => {
      'room': roomToRow(state.room),
      'players': state.players.map(playerToRow).toList(),
    };

GameState gameStateFromSnapshotJson(Map<String, dynamic> json) {
  final room = roomFromRow(json['room'] as Map<String, dynamic>);
  final players = (json['players'] as List)
      .map((p) => playerFromRow(p as Map<String, dynamic>))
      .toList();
  return GameState(room: room, players: players);
}
