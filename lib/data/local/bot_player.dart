import 'dart:math';

import '../../domain/game_state.dart';
import '../../models/enums.dart';
import '../../models/player.dart';
import '../../models/room.dart';

/// デモ/オフラインモード用の簡易オートアクション。
/// 本物のポーカーAIではなく、UI・進行ロジックを一通り確認するための
/// 単純な確率ベースの意思決定にとどめている。
class BotDecision {
  const BotDecision(this.action, {this.amount = 0});

  final ActionType action;
  final int amount;
}

class BotPlayer {
  BotPlayer._();

  static final Random _random = Random();

  static BotDecision decide(GameState state, Player bot) {
    final room = state.room;
    final toCall = room.highestBet - bot.currentBet;

    if (toCall <= 0) {
      if (_random.nextDouble() < 0.2 && bot.chips > 200) {
        final amount = _raiseAmount(room, bot, room.pot > 0 ? room.pot ~/ 2 : 200);
        if (amount != null) return BotDecision(ActionType.raise, amount: amount);
      }
      return const BotDecision(ActionType.check);
    }

    if (toCall >= bot.chips) {
      return _random.nextDouble() < 0.45
          ? const BotDecision(ActionType.allIn)
          : const BotDecision(ActionType.fold);
    }

    final callRatio = toCall / bot.chips;
    final foldChance = (callRatio * 0.6).clamp(0.05, 0.7);
    final roll = _random.nextDouble();

    if (roll < foldChance) {
      return const BotDecision(ActionType.fold);
    }
    if (roll < foldChance + 0.15) {
      final amount = _raiseAmount(room, bot, toCall + 200);
      if (amount != null) return BotDecision(ActionType.raise, amount: amount);
    }
    return const BotDecision(ActionType.call);
  }

  /// ハイベストを上回る有効なレイズ額を計算する。不可能な場合はnull。
  static int? _raiseAmount(Room room, Player bot, int desiredExtra) {
    final minRequired = room.highestBet - bot.currentBet + 1;
    if (minRequired > bot.chips) return null;
    final amount = desiredExtra.clamp(minRequired, bot.chips);
    return amount;
  }
}
