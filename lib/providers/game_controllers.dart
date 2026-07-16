import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/room_repository.dart';
import '../models/enums.dart';
import 'repository_providers.dart';

/// UIからのアクション送信をまとめる薄いコントローラ。
/// ハプティクスフィードバックなどUI都合の処理をここに集約する。
class GameController {
  GameController(this._repository);

  final RoomRepository _repository;

  Future<String> createRoom({required String hostName, required int totalPlayers}) {
    return _repository.createRoom(hostName: hostName, totalPlayers: totalPlayers);
  }

  void fold(String playerId) {
    HapticFeedback.mediumImpact();
    _repository.performAction(playerId, ActionType.fold);
  }

  void check(String playerId) {
    HapticFeedback.lightImpact();
    _repository.performAction(playerId, ActionType.check);
  }

  void call(String playerId) {
    HapticFeedback.lightImpact();
    _repository.performAction(playerId, ActionType.call);
  }

  void raise(String playerId, int amount) {
    HapticFeedback.mediumImpact();
    _repository.performAction(playerId, ActionType.raise, amount: amount);
  }

  void allIn(String playerId) {
    HapticFeedback.heavyImpact();
    _repository.performAction(playerId, ActionType.allIn);
  }

  void undo() {
    HapticFeedback.selectionClick();
    _repository.undo();
  }

  void kick(String playerId) => _repository.kickPlayer(playerId);

  void borrow(String playerId) => _repository.borrowChips(playerId);

  void applySecretWord(String playerId, String word) =>
      _repository.applySecretWord(playerId, word);

  void startNextHand() => _repository.startNextHand();

  void awardPot(List<String> winnerIds) => _repository.awardPot(winnerIds);

  void resolveAdWatched(String playerId) => _repository.resolveAdWatched(playerId);
}

final gameControllerProvider = Provider<GameController>((ref) {
  return GameController(ref.watch(roomRepositoryProvider));
});
