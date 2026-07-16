import 'package:flutter_test/flutter_test.dart';
import 'package:pokerchips/domain/game_state.dart';
import 'package:pokerchips/domain/poker_chip_engine.dart';
import 'package:pokerchips/models/enums.dart';
import 'package:pokerchips/models/player.dart';
import 'package:pokerchips/models/room.dart';

int totalNetAsset(GameState state) =>
    state.players.fold(0, (sum, p) => sum + p.netAsset);

GameState makeState(List<String> ids) {
  final players = ids
      .map((id) => Player(id: id, name: id, chips: 10000))
      .toList();
  final room = Room(code: '12345', hostPlayerId: ids.first);
  return GameState(room: room, players: players);
}

void main() {
  group('startHand', () {
    test('資産合計は常に 人数×10,000 を維持する', () {
      var state = makeState(['a', 'b']);
      expect(totalNetAsset(state), 20000);
      state = PokerChipEngine.startHand(state);
      expect(totalNetAsset(state), 20000);
      expect(state.room.phase, GamePhase.preflop);
      expect(state.room.pendingToActPlayerIds, unorderedEquals(['a', 'b']));
    });

    test('ハート回復待ちのプレイヤーがいると開始できない', () {
      var state = makeState(['a', 'b']);
      state = state.copyWith(
        players: [
          state.players[0].copyWith(status: PlayerStatus.waitingAd, hearts: 0),
          state.players[1],
        ],
      );
      expect(() => PokerChipEngine.startHand(state), throwsStateError);
    });
  });

  group('betting round', () {
    test('call-call で1ストリート完了しポットが積み上がる', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);

      state = PokerChipEngine.applyAction(
        state,
        playerId: 'a',
        action: ActionType.raise,
        amount: 500,
      );
      expect(state.room.highestBet, 500);
      expect(state.room.pendingToActPlayerIds, ['b']);

      state = PokerChipEngine.applyAction(state, playerId: 'b', action: ActionType.call);
      expect(state.room.pot, 1000);
      expect(state.room.phase, GamePhase.flop);
      expect(state.room.highestBet, 0);
      expect(totalNetAsset(state), 20000);
    });

    test('レイズはハイベストを上回らないと拒否される', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.applyAction(
        state,
        playerId: 'a',
        action: ActionType.raise,
        amount: 500,
      );
      expect(
        () => PokerChipEngine.applyAction(
          state,
          playerId: 'b',
          action: ActionType.raise,
          amount: 200,
        ),
        throwsStateError,
      );
    });

    test('Foldで1人だけ残ると自動的にポットを獲得する', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.applyAction(
        state,
        playerId: 'a',
        action: ActionType.raise,
        amount: 1000,
      );
      state = PokerChipEngine.applyAction(state, playerId: 'b', action: ActionType.fold);

      expect(state.room.phase, GamePhase.interHand);
      expect(state.room.pot, 0);
      expect(state.playerById('a').chips, 10000);
      expect(state.playerById('b').chips, 10000);
      expect(totalNetAsset(state), 20000);
    });

    test('riverまで進むとshowdownになりawardPotで勝者に分配される', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      for (var i = 0; i < 4; i++) {
        state = PokerChipEngine.applyAction(state, playerId: 'a', action: ActionType.check);
        state = PokerChipEngine.applyAction(state, playerId: 'b', action: ActionType.check);
      }
      expect(state.room.phase, GamePhase.showdown);

      state = PokerChipEngine.awardPot(state, ['a']);
      expect(state.playerById('a').chips, 10000);
      expect(state.room.phase, GamePhase.interHand);
      expect(totalNetAsset(state), 20000);
    });
  });

  group('undo(スナップショット復元)', () {
    test('直前の1手だけ元に戻せる', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      final beforeRaise = state;
      state = PokerChipEngine.applyAction(
        state,
        playerId: 'a',
        action: ActionType.raise,
        amount: 500,
      );
      expect(state.room.pot, 500);

      // Undo = 直前スナップショットに戻すだけ(engineはスナップショット管理をしない)
      final restored = beforeRaise;
      expect(restored.room.pot, 0);
      expect(restored.playerById('a').chips, 10000);
    });
  });

  group('借金と純資産', () {
    test('借金するとチップは増えるが純資産は変わらない', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.awardPot(state, ['a']); // interHandへ

      final before = state.playerById('a').netAsset;
      state = PokerChipEngine.borrow(state, 'a');
      final after = state.playerById('a');
      expect(after.chips, 20000);
      expect(after.borrowCount, 1);
      expect(after.netAsset, before);
      expect(totalNetAsset(state), 20000);
    });

    test('ハンド中は借金できない', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      expect(() => PokerChipEngine.borrow(state, 'a'), throwsStateError);
    });
  });

  group('キックとデッドマネー', () {
    test('キックされたプレイヤーの賭け金はポットに残る', () {
      var state = makeState(['a', 'b', 'c']);
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.applyAction(
        state,
        playerId: 'a',
        action: ActionType.raise,
        amount: 1000,
      );
      state = PokerChipEngine.applyAction(state, playerId: 'b', action: ActionType.call);
      final potBeforeKick = state.room.pot;

      state = PokerChipEngine.kickPlayer(state, 'c');
      expect(state.playerById('c').status, PlayerStatus.kicked);
      expect(state.room.pot, potBeforeKick);
    });
  });

  group('ハートとあいことば', () {
    test('あいことば適用でハートが減らない', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.applySecretWord(state, 'a', 'pokervip');
      expect(state.playerById('a').isAdFree, isTrue);

      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.awardPot(state, ['a']);
      expect(state.playerById('a').hearts, 5);
      expect(state.playerById('b').hearts, 4);
    });

    test('ハートが0になると広告待ちロックがかかりawardPot後に開始不可', () {
      var state = makeState(['a', 'b']);
      state = state.copyWith(
        players: [
          state.players[0].copyWith(hearts: 1),
          state.players[1],
        ],
      );
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.awardPot(state, ['b']);

      expect(state.playerById('a').hearts, 0);
      expect(state.playerById('a').status, PlayerStatus.waitingAd);
      expect(state.room.adWaitingPlayerId, 'a');
      expect(() => PokerChipEngine.startHand(state), throwsStateError);

      state = PokerChipEngine.resolveAdWatched(state, 'a');
      expect(state.playerById('a').hearts, 5);
      expect(state.playerById('a').status, PlayerStatus.active);
      expect(state.room.adWaitingPlayerId, isNull);
      expect(() => PokerChipEngine.startHand(state), returnsNormally);
    });

    test('30秒タイムアウトで強制キックされロックが解除される', () {
      var state = makeState(['a', 'b']);
      state = state.copyWith(
        players: [
          state.players[0].copyWith(hearts: 1),
          state.players[1],
        ],
      );
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.awardPot(state, ['b']);
      expect(state.room.adWaitingPlayerId, 'a');

      state = PokerChipEngine.resolveAdTimeout(state);
      expect(state.playerById('a').status, PlayerStatus.kicked);
      expect(state.room.adWaitingPlayerId, isNull);
    });
  });
}
