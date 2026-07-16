import '../models/enums.dart';
import '../models/player.dart';
import '../models/room.dart';

/// Room + Players をまとめた不変(immutable)なスナップショット。
/// PokerChipEngine はこれを受け取り新しいGameStateを返す純粋関数として実装する。
/// Undo は直前のGameStateをそのまま復元するだけで良い。
class GameState {
  const GameState({required this.room, required this.players});

  final Room room;
  final List<Player> players;

  Player playerById(String id) => players.firstWhere((p) => p.id == id);

  List<Player> get seatedPlayers =>
      players.where((p) => p.status != PlayerStatus.kicked).toList();

  GameState copyWith({Room? room, List<Player>? players}) {
    return GameState(room: room ?? this.room, players: players ?? this.players);
  }
}
