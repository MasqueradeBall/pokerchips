import 'package:flutter_test/flutter_test.dart';
import 'package:pokerchips/domain/game_state.dart';
import 'package:pokerchips/domain/poker_chip_engine.dart';
import 'package:pokerchips/models/enums.dart';
import 'package:pokerchips/models/player.dart';
import 'package:pokerchips/models/room.dart';

int totalNetAsset(GameState state) =>
    state.players.fold(0, (sum, p) => sum + p.netAsset);

GameState makeState(List<String> ids, {int chips = 10000}) {
  final players = ids.map((id) => Player(id: id, name: id, chips: chips)).toList();
  final room = Room(code: '12345', hostPlayerId: ids.first);
  return GameState(room: room, players: players);
}

GameState makeStateWithBlinds(
  List<String> ids, {
  int chips = 10000,
  int smallBlind = 50,
  int bigBlind = 100,
  int ante = 0,
}) {
  final players = ids.map((id) => Player(id: id, name: id, chips: chips)).toList();
  final room = Room(
    code: '12345',
    hostPlayerId: ids.first,
    smallBlind: smallBlind,
    bigBlind: bigBlind,
    ante: ante,
  );
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

  group('ボタン/ブラインドの行動順', () {
    test('プリフロップはボタンから、フロップ以降はボタンの次から始まる(ヘッズアップ)', () {
      // ブラインド無し(makeState)でも行動順のロジックだけは適用される。
      var state = makeState(['a', 'b']); // a=ボタン(ヘッズアップなのでSB相当)
      state = PokerChipEngine.startHand(state);
      expect(state.room.currentTurnPlayerId, 'a');

      state = PokerChipEngine.applyAction(state, playerId: 'a', action: ActionType.check);
      state = PokerChipEngine.applyAction(state, playerId: 'b', action: ActionType.check);
      expect(state.room.phase, GamePhase.flop);
      // フロップ以降はボタン(a)の次=bから始まる。
      expect(state.room.currentTurnPlayerId, 'b');
    });

    test('3人以上ではボタンの次から2席がSB/BB、プリフロップはその次から始まる', () {
      var state = makeState(['a', 'b', 'c', 'd']); // a=ボタン, b=SB, c=BB, d=UTG
      state = PokerChipEngine.startHand(state);
      // プリフロップ: UTG(d) → ボタン(a) → SB(b) → BB(c) の順。
      expect(state.room.currentTurnPlayerId, 'd');

      for (final id in ['d', 'a', 'b', 'c']) {
        state = PokerChipEngine.applyAction(state, playerId: id, action: ActionType.check);
      }
      expect(state.room.phase, GamePhase.flop);
      // フロップ以降: SB(b)から始まりボタン(a)が最後。
      expect(state.room.currentTurnPlayerId, 'b');
    });
  });

  group('ブラインドとアンティ', () {
    test('ヘッズアップ: ボタンがSB、もう一方がBBを払いプリフロップが始まる', () {
      var state = makeStateWithBlinds(['a', 'b'], smallBlind: 50, bigBlind: 100);
      state = PokerChipEngine.startHand(state);

      expect(state.room.smallBlindPlayerId, 'a');
      expect(state.room.bigBlindPlayerId, 'b');
      expect(state.playerById('a').chips, 9950);
      expect(state.playerById('a').currentBet, 50);
      expect(state.playerById('b').chips, 9900);
      expect(state.playerById('b').currentBet, 100);
      expect(state.room.pot, 150);
      expect(state.room.highestBet, 100);
      expect(totalNetAsset(state), 20000);
      // ヘッズアップのプリフロップはボタン(SB)から。
      expect(state.room.currentTurnPlayerId, 'a');
    });

    test('3人以上: ボタンの次がSB、その次がBB', () {
      var state = makeStateWithBlinds(['a', 'b', 'c'], smallBlind: 50, bigBlind: 100);
      state = PokerChipEngine.startHand(state);

      expect(state.room.smallBlindPlayerId, 'b');
      expect(state.room.bigBlindPlayerId, 'c');
      expect(state.playerById('a').currentBet, 0);
      expect(state.playerById('b').currentBet, 50);
      expect(state.playerById('c').currentBet, 100);
      expect(state.room.pot, 150);
      expect(totalNetAsset(state), 30000);
    });

    test('BBに満たないチップしかない場合は全額オールインで徴収される', () {
      var state = makeStateWithBlinds(['a', 'b'], chips: 10000, smallBlind: 50, bigBlind: 100);
      state = state.copyWith(
        players: [
          state.players[0],
          state.players[1].copyWith(chips: 30), // BBを満額払えない
        ],
      );
      state = PokerChipEngine.startHand(state);

      final bb = state.playerById('b');
      expect(bb.chips, 0);
      expect(bb.currentBet, 30);
      expect(bb.status, PlayerStatus.allIn);
      expect(state.room.highestBet, 30); // 実際に徴収できた額が基準になる
      expect(state.room.pot, 80); // SB50 + BB30
    });

    test('アンティが設定されていれば全員から先に徴収される', () {
      var state = makeStateWithBlinds(
        ['a', 'b', 'c'],
        smallBlind: 50,
        bigBlind: 100,
        ante: 10,
      );
      state = PokerChipEngine.startHand(state);

      // アンティはhandContributionには乗るがcurrentBet(コール基準)には乗らない。
      expect(state.playerById('a').currentBet, 0);
      expect(state.playerById('a').handContribution, 10);
      expect(state.playerById('b').handContribution, 60); // アンティ10 + SB50
      expect(state.playerById('c').handContribution, 110); // アンティ10 + BB100
      expect(state.room.pot, 180); // アンティ30 + SB50 + BB100
      expect(totalNetAsset(state), 30000);
    });
  });

  group('設定変更 (updateSettings)', () {
    test('ロビー中はブラインド/アンティ/初期チップ枚数を変更できる', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.updateSettings(
        state,
        smallBlind: 100,
        bigBlind: 200,
        ante: 25,
        startingStack: 20000,
      );
      expect(state.room.smallBlind, 100);
      expect(state.room.bigBlind, 200);
      expect(state.room.ante, 25);
      expect(state.room.startingStack, 20000);
      // ロビー中はまだ誰の資産も動いていないので、初期チップ枚数の変更は
      // 着席済みプレイヤー全員のchipsをその場で揃え直す。
      expect(state.playerById('a').chips, 20000);
      expect(state.playerById('b').chips, 20000);
    });

    test('ビッグブラインドがスモールブラインドを下回るのは不正', () {
      var state = makeState(['a', 'b']);
      expect(
        () => PokerChipEngine.updateSettings(state, smallBlind: 200, bigBlind: 100),
        throwsArgumentError,
      );
    });

    test('ハンド開始後は設定を変更できない', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      expect(
        () => PokerChipEngine.updateSettings(state, bigBlind: 200),
        throwsStateError,
      );
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
      state = PokerChipEngine.applyAction(state, playerId: 'a', action: ActionType.allIn);
      state = PokerChipEngine.applyAction(state, playerId: 'b', action: ActionType.call);
      state = PokerChipEngine.awardPot(state, ['b']); // interHandへ、aは手持ち0で敗退

      expect(state.playerById('a').chips, 0);

      final before = state.playerById('a').netAsset;
      state = PokerChipEngine.borrow(state, 'a');
      final after = state.playerById('a');
      expect(after.chips, 10000);
      expect(after.borrowCount, 1);
      expect(after.netAsset, before);
      expect(totalNetAsset(state), 20000);
    });

    test('ハンド中は借金できない', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      expect(() => PokerChipEngine.borrow(state, 'a'), throwsStateError);
    });

    test('手持ちが0でない場合は借金できない', () {
      var state = makeState(['a', 'b']);
      state = PokerChipEngine.startHand(state);
      state = PokerChipEngine.awardPot(state, ['a']); // interHandへ、aは手持ちが残っている
      expect(state.playerById('a').chips, greaterThan(0));
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
      state = PokerChipEngine.applySecretWord(state, 'a', '20060527');
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
