import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../domain/game_state.dart';
import '../../domain/poker_chip_engine.dart';
import '../../models/enums.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../room_repository.dart';
import '../room_snapshot.dart';
import 'bot_player.dart';

/// 1台のデバイスで完結するデモ/オフラインモード実装。
/// ホスト(自分) + Bot(totalPlayers-1体)でハンドを最初から最後まで
/// プレイでき、Undo/キック/借金/ハート/広告待ちなど全ロジックを確認できる。
///
/// オンライン対戦(Supabase Realtime)は次フェーズで [RoomRepository] の
/// 別実装として追加する想定。
class LocalRoomRepository implements RoomRepository {
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  final StreamController<RoomSnapshot> _controller = StreamController.broadcast();

  GameState? _state;
  GameState? _previousState;
  RoomSnapshot? _latestSnapshot;
  Timer? _adTimer;
  Timer? _botTimer;
  bool _disposed = false;
  String _selfPlayerId = '';

  /// broadcast StreamはlistenするタイミングよりHome→Play画面遷移の間に
  /// createRoom/startNextHandが完了してしまうため、購読開始時に
  /// 直近のスナップショットを再送してからその後の更新に切り替える。
  @override
  Stream<RoomSnapshot> watch() async* {
    final cached = _latestSnapshot;
    if (cached != null) yield cached;
    yield* _controller.stream;
  }

  @override
  Future<String> createRoom({required String hostName, int totalPlayers = 4}) async {
    final hostId = _uuid.v4();
    _selfPlayerId = hostId;

    final players = <Player>[
      Player(
        id: hostId,
        name: hostName.trim().isEmpty ? 'あなた' : hostName.trim(),
        chips: GameConstants.initialStack,
        isHost: true,
      ),
      for (var i = 1; i < totalPlayers; i++)
        Player(
          id: _uuid.v4(),
          name: 'Bot $i',
          chips: GameConstants.initialStack,
          isBot: true,
        ),
    ];

    final code = (10000 + _random.nextInt(90000)).toString();
    final room = Room(
      code: code,
      hostPlayerId: hostId,
      smallBlind: GameConstants.defaultSmallBlind,
      bigBlind: GameConstants.defaultBigBlind,
      ante: GameConstants.defaultAnte,
      startingStack: GameConstants.initialStack,
    );
    // オンライン版と挙動を揃えるため、ロビーで止めてホストが「ゲームを開始」を
    // 押すまで待つ(ブラインド等の設定画面をデモでも試せるようにするため)。
    _setState(GameState(room: room, players: players), recordHistory: false);
    return hostId;
  }

  @override
  Future<String> joinRoom({required String playerName, required String roomCode}) {
    throw UnimplementedError('オフラインBot対戦モードではルーム参加はサポートされていません');
  }

  @override
  void performAction(String playerId, ActionType action, {int amount = 0}) {
    final current = _state;
    if (current == null) return;
    final next = PokerChipEngine.applyAction(
      current,
      playerId: playerId,
      action: action,
      amount: amount,
    );
    _setState(next, recordHistory: true);
  }

  @override
  void undo() {
    if (_previousState == null) return;
    _state = _previousState;
    _previousState = null;
    _emit();
    _scheduleAdTimeoutIfNeeded();
    _scheduleBotActionIfNeeded();
  }

  @override
  void kickPlayer(String playerId) {
    final current = _state;
    if (current == null) return;
    _setState(PokerChipEngine.kickPlayer(current, playerId), recordHistory: false);
  }

  @override
  void borrowChips(String playerId) {
    final current = _state;
    if (current == null) return;
    _setState(PokerChipEngine.borrow(current, playerId), recordHistory: false);
  }

  @override
  void applySecretWord(String playerId, String word) {
    final current = _state;
    if (current == null) return;
    _setState(
      PokerChipEngine.applySecretWord(current, playerId, word),
      recordHistory: false,
    );
  }

  @override
  void startNextHand() {
    final current = _state;
    if (current == null) return;
    _setState(PokerChipEngine.startHand(current), recordHistory: false);
  }

  @override
  void updateSettings({
    int? smallBlind,
    int? bigBlind,
    int? ante,
    int? startingStack,
  }) {
    final current = _state;
    if (current == null) return;
    _setState(
      PokerChipEngine.updateSettings(
        current,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        ante: ante,
        startingStack: startingStack,
      ),
      recordHistory: false,
    );
  }

  @override
  void awardPot(List<String> winnerIds) {
    final current = _state;
    if (current == null) return;
    _setState(PokerChipEngine.awardPot(current, winnerIds), recordHistory: false);
  }

  @override
  void resolveAdWatched(String playerId) {
    final current = _state;
    if (current == null) return;
    _setState(
      PokerChipEngine.resolveAdWatched(current, playerId),
      recordHistory: false,
    );
  }

  void _setState(GameState next, {required bool recordHistory}) {
    _previousState = recordHistory ? _state : null;
    _state = next;
    _emit();
    _scheduleAdTimeoutIfNeeded();
    _scheduleBotActionIfNeeded();
  }

  void _emit() {
    if (_disposed || _state == null) return;
    final snapshot = RoomSnapshot(
      state: _state!,
      canUndo: _previousState != null,
      selfPlayerId: _selfPlayerId,
    );
    _latestSnapshot = snapshot;
    _controller.add(snapshot);
  }

  void _scheduleAdTimeoutIfNeeded() {
    _adTimer?.cancel();
    final room = _state?.room;
    final waitingId = room?.adWaitingPlayerId;
    final deadline = room?.adWaitingDeadline;
    if (waitingId == null || deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    _adTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_disposed) return;
      final current = _state;
      if (current == null || current.room.adWaitingPlayerId != waitingId) return;
      _setState(PokerChipEngine.resolveAdTimeout(current), recordHistory: false);
    });
  }

  void _scheduleBotActionIfNeeded() {
    _botTimer?.cancel();
    final current = _state;
    if (current == null) return;
    final turnId = current.room.currentTurnPlayerId;
    if (turnId == null) return;

    final Player initialBot;
    try {
      initialBot = current.playerById(turnId);
    } catch (_) {
      return;
    }
    if (!initialBot.isBot) return;

    final delay = Duration(milliseconds: 500 + _random.nextInt(700));
    _botTimer = Timer(delay, () {
      if (_disposed) return;
      final latest = _state;
      if (latest == null || latest.room.currentTurnPlayerId != turnId) return;
      // スケジュール時点ではなく発火時点の最新プレイヤー情報で判断する
      // (途中でUndo等により状態が変わっている可能性があるため)。
      final Player freshBot;
      try {
        freshBot = latest.playerById(turnId);
      } catch (_) {
        return;
      }
      if (!freshBot.isBot || freshBot.status != PlayerStatus.active) return;
      final decision = BotPlayer.decide(latest, freshBot);
      try {
        performAction(turnId, decision.action, amount: decision.amount);
      } catch (_) {
        // 手番不一致などで拒否された場合は何もしない(次回のスケジュールに委ねる)。
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _adTimer?.cancel();
    _botTimer?.cancel();
    _controller.close();
  }
}
