import '../core/constants.dart';
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
    this.revealMessage,
    this.adWaitingPlayerId,
    this.adWaitingDeadline,
    this.smallBlind = 0,
    this.bigBlind = 0,
    this.ante = 0,
    this.startingStack = GameConstants.initialStack,
    this.smallBlindPlayerId,
    this.bigBlindPlayerId,
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
  /// コミュニティカードをめくるタイミングの案内。画面全体を暗くして表示するため
  /// [systemMessage](小さいトースト)とは別フィールドで持ち、
  /// プレイヤーが確認するまで(ローカルでの明示的な操作まで)保持される。
  final String? revealMessage;
  final String? adWaitingPlayerId;
  final DateTime? adWaitingDeadline;

  /// スモールブラインド/ビッグブラインド額。0なら無効(ブラインドなしで開始)。
  /// ロビー中([GamePhase.lobby])のみホストが変更できる
  /// ([PokerChipEngine.updateSettings]参照)。
  final int smallBlind;
  final int bigBlind;

  /// アンティ(全員が毎ハンド強制的に払う額)。0なら無効。
  final int ante;

  /// 新規参加者が着席する際の初期チップ枚数。
  final int startingStack;

  /// 直近に開始したハンドでSB/BBを払ったプレイヤーID
  /// (UI表示用。次のstartHandで上書き、ハンド終了時にクリアされる)。
  final String? smallBlindPlayerId;
  final String? bigBlindPlayerId;

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
    String? revealMessage,
    bool clearRevealMessage = false,
    String? adWaitingPlayerId,
    bool clearAdWaiting = false,
    DateTime? adWaitingDeadline,
    int? smallBlind,
    int? bigBlind,
    int? ante,
    int? startingStack,
    String? smallBlindPlayerId,
    String? bigBlindPlayerId,
    bool clearBlindPlayers = false,
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
      revealMessage:
          clearRevealMessage ? null : (revealMessage ?? this.revealMessage),
      adWaitingPlayerId:
          clearAdWaiting ? null : (adWaitingPlayerId ?? this.adWaitingPlayerId),
      adWaitingDeadline:
          clearAdWaiting ? null : (adWaitingDeadline ?? this.adWaitingDeadline),
      smallBlind: smallBlind ?? this.smallBlind,
      bigBlind: bigBlind ?? this.bigBlind,
      ante: ante ?? this.ante,
      startingStack: startingStack ?? this.startingStack,
      smallBlindPlayerId: clearBlindPlayers
          ? null
          : (smallBlindPlayerId ?? this.smallBlindPlayerId),
      bigBlindPlayerId: clearBlindPlayers
          ? null
          : (bigBlindPlayerId ?? this.bigBlindPlayerId),
    );
  }
}
