import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/game_state.dart';
import '../../domain/poker_chip_engine.dart';
import '../../models/enums.dart';
import '../../models/room.dart';
import '../room_repository.dart';
import '../room_snapshot.dart';
import 'model_mapping.dart';

/// Supabase(Postgres + Realtime)を使ったオンライン対戦実装。
///
/// 「クライアント主導」方式: アクションを行ったクライアントが
/// [PokerChipEngine] でローカルに次の状態を計算し、その結果を
/// rooms/players テーブルにそのまま書き込む。他クライアントはRealtimeで
/// 変更を受け取って画面を更新する。サーバー側で不正なアクションを
/// 検証するPostgres関数は用意していないため、悪意のあるクライアントに
/// よる不正な書き込みは防げない(友人内でのプレイを想定した簡易実装)。
class SupabaseRoomRepository implements RoomRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  final StreamController<RoomSnapshot> _controller = StreamController.broadcast();

  String? _roomId;
  String _selfPlayerId = '';
  Map<String, dynamic>? _roomRow;
  List<Map<String, dynamic>> _playerRows = [];
  StreamSubscription<List<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<List<Map<String, dynamic>>>? _playersSub;
  Timer? _adTimer;
  RoomSnapshot? _latestSnapshot;
  bool _disposed = false;

  @override
  Stream<RoomSnapshot> watch() async* {
    final cached = _latestSnapshot;
    if (cached != null) yield cached;
    yield* _controller.stream;
  }

  @override
  Future<String> createRoom({required String hostName}) async {
    final hostId = _uuid.v4();
    _selfPlayerId = hostId;
    final code = (10000 + _random.nextInt(90000)).toString();

    final roomRow = await _client
        .from('rooms')
        .insert({
          'room_code': code,
          'host_player_id': hostId,
          'phase': GamePhase.lobby.name,
        })
        .select()
        .single();
    final roomId = roomRow['id'] as String;

    await _client.from('players').insert({
      'id': hostId,
      'room_id': roomId,
      'name': hostName.trim().isEmpty ? 'あなた' : hostName.trim(),
      'is_host': true,
    });

    _roomId = roomId;
    _subscribe(roomId);
    return hostId;
  }

  @override
  Future<String> joinRoom({required String playerName, required String roomCode}) async {
    final roomRow = await _client
        .from('rooms')
        .select()
        .eq('room_code', roomCode.trim())
        .maybeSingle();
    if (roomRow == null) {
      throw StateError('ルームID「$roomCode」が見つかりません');
    }
    final roomId = roomRow['id'] as String;
    if (roomRow['phase'] != GamePhase.lobby.name) {
      throw StateError('このルームは既にゲームが開始されているため参加できません');
    }

    final playerId = _uuid.v4();
    await _client.from('players').insert({
      'id': playerId,
      'room_id': roomId,
      'name': playerName.trim().isEmpty ? 'あなた' : playerName.trim(),
      'is_host': false,
    });

    _selfPlayerId = playerId;
    _roomId = roomId;
    _subscribe(roomId);
    return playerId;
  }

  void _subscribe(String roomId) {
    _roomSub?.cancel();
    _playersSub?.cancel();
    _roomSub = _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((rows) {
      if (rows.isEmpty) return;
      _roomRow = rows.first;
      _emit();
    });
    _playersSub = _client
        .from('players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .listen((rows) {
      _playerRows = rows;
      _emit();
    });
  }

  List<Map<String, dynamic>> get _sortedPlayerRows => [..._playerRows]
    ..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));

  GameState? get _currentState {
    final roomRow = _roomRow;
    if (roomRow == null) return null;
    return GameState(
      room: roomFromRow(roomRow),
      players: _sortedPlayerRows.map(playerFromRow).toList(),
    );
  }

  void _emit() {
    if (_disposed) return;
    final roomRow = _roomRow;
    final state = _currentState;
    if (roomRow == null || state == null) return;
    final snapshot = RoomSnapshot(
      state: state,
      canUndo: roomRow['previous_snapshot'] != null,
      selfPlayerId: _selfPlayerId,
    );
    _latestSnapshot = snapshot;
    _controller.add(snapshot);
    _scheduleAdTimeoutIfNeeded(state.room);
  }

  Future<void> _writeState(GameState next, {required bool recordHistory}) async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final previous = recordHistory ? _currentState : null;
      final roomUpdate = roomToRow(next.room)..remove('room_code');
      roomUpdate['previous_snapshot'] =
          previous == null ? null : gameStateToSnapshotJson(previous);

      await _client.from('rooms').update(roomUpdate).eq('id', roomId);
      await _client.from('players').upsert(next.players.map(playerToRow).toList());
    } catch (e) {
      debugPrint('SupabaseRoomRepository write failed: $e');
    }
  }

  @override
  void performAction(String playerId, ActionType action, {int amount = 0}) {
    final current = _currentState;
    if (current == null) return;
    final next = PokerChipEngine.applyAction(
      current,
      playerId: playerId,
      action: action,
      amount: amount,
    );
    unawaited(_writeState(next, recordHistory: true));
  }

  @override
  void undo() {
    final roomRow = _roomRow;
    if (roomRow == null || roomRow['previous_snapshot'] == null) return;
    final restored = gameStateFromSnapshotJson(
      roomRow['previous_snapshot'] as Map<String, dynamic>,
    );
    unawaited(_writeState(restored, recordHistory: false));
  }

  @override
  void kickPlayer(String playerId) {
    final current = _currentState;
    if (current == null) return;
    unawaited(_writeState(PokerChipEngine.kickPlayer(current, playerId), recordHistory: false));
  }

  @override
  void borrowChips(String playerId) {
    final current = _currentState;
    if (current == null) return;
    unawaited(_writeState(PokerChipEngine.borrow(current, playerId), recordHistory: false));
  }

  @override
  void applySecretWord(String playerId, String word) {
    final current = _currentState;
    if (current == null) return;
    unawaited(_writeState(
      PokerChipEngine.applySecretWord(current, playerId, word),
      recordHistory: false,
    ));
  }

  @override
  void startNextHand() {
    final current = _currentState;
    if (current == null) return;
    unawaited(_writeState(PokerChipEngine.startHand(current), recordHistory: false));
  }

  @override
  void awardPot(List<String> winnerIds) {
    final current = _currentState;
    if (current == null) return;
    unawaited(_writeState(PokerChipEngine.awardPot(current, winnerIds), recordHistory: false));
  }

  @override
  void resolveAdWatched(String playerId) {
    final current = _currentState;
    if (current == null) return;
    unawaited(_writeState(
      PokerChipEngine.resolveAdWatched(current, playerId),
      recordHistory: false,
    ));
  }

  void _scheduleAdTimeoutIfNeeded(Room room) {
    _adTimer?.cancel();
    final waitingId = room.adWaitingPlayerId;
    final deadline = room.adWaitingDeadline;
    if (waitingId == null || deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    _adTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_disposed) return;
      final current = _currentState;
      if (current == null || current.room.adWaitingPlayerId != waitingId) return;
      unawaited(_writeState(PokerChipEngine.resolveAdTimeout(current), recordHistory: false));
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _adTimer?.cancel();
    unawaited(_roomSub?.cancel());
    unawaited(_playersSub?.cancel());
    _controller.close();
  }
}
