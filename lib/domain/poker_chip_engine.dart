import '../core/constants.dart';
import '../models/action_log.dart';
import '../models/enums.dart';
import '../models/player.dart';
import 'game_state.dart';

/// 純粋関数のみで構成されるポーカーチップの進行ロジック。
/// GameStateを受け取り、新しいGameStateを返す(副作用なし)ためユニットテストしやすい。
/// Repository層がこれを呼び出し、Streamで配信する状態を更新する。
class PokerChipEngine {
  PokerChipEngine._();

  /// ハンドを開始する。ハート回復待ち(waitingAd)のプレイヤーがいる間は開始できない。
  ///
  /// 実際のポーカーと同じくディーラーボタンを1つずつローテーションし、
  /// ボタンの次(3人以上)またはボタン自身(2人=ヘッズアップ)からスモール
  /// ブラインド/ビッグブラインドを強制徴収する。アンティ([Room.ante] > 0)が
  /// 設定されている場合は全員がブラインドより先にそれも払う。
  /// プリフロップはBBの次のプレイヤーから、フロップ以降はボタンの次の
  /// プレイヤーから(=ボタンが最後に行動する)という実際の順序を再現する。
  static GameState startHand(GameState state) {
    if (state.players.any((p) => p.status == PlayerStatus.waitingAd)) {
      throw StateError('ハート回復待ちのプレイヤーがいるためハンドを開始できません');
    }
    final eligible = state.seatedPlayers;
    if (eligible.length < GameConstants.minPlayers) {
      throw StateError('プレイヤーが足りません');
    }

    // 2ハンド目以降はボタンを1つずつローテーションして公平にする。
    final isFirstHand = state.room.turnOrder.isEmpty;
    final eligibleIds = eligible.map((p) => p.id).toList();
    final prevOrder = state.room.turnOrder
        .where((id) => eligibleIds.contains(id))
        .toList();
    final rotated = isFirstHand || prevOrder.isEmpty
        ? eligibleIds
        : [...prevOrder.skip(1), prevOrder.first];

    var newPlayers = state.players.map((p) {
      if (p.status == PlayerStatus.kicked) return p;
      return p.copyWith(
        currentBet: 0,
        handContribution: 0,
        status: PlayerStatus.active,
      );
    }).toList();

    Player playerById(String id) => newPlayers.firstWhere((p) => p.id == id);
    void updatePlayer(Player updated) {
      newPlayers = [
        for (final p in newPlayers) p.id == updated.id ? updated : p,
      ];
    }

    // チップが足りない場合は残りチップ全額をオールインとして徴収する。
    int postForced(String id, int amount) {
      if (amount <= 0) return 0;
      final p = playerById(id);
      final posted = p.chips < amount ? p.chips : amount;
      if (posted <= 0) return 0;
      var updated = p.copyWith(
        chips: p.chips - posted,
        currentBet: p.currentBet + posted,
        handContribution: p.handContribution + posted,
      );
      if (updated.chips == 0) {
        updated = updated.copyWith(status: PlayerStatus.allIn);
      }
      updatePlayer(updated);
      return posted;
    }

    var pot = 0;

    // アンティ: ブラインドより先に全員から徴収する。
    // (currentBetには積まない = コール額の計算に影響させない)
    if (state.room.ante > 0) {
      for (final id in rotated) {
        final p = playerById(id);
        final posted = p.chips < state.room.ante ? p.chips : state.room.ante;
        if (posted <= 0) continue;
        var updated = p.copyWith(
          chips: p.chips - posted,
          handContribution: p.handContribution + posted,
        );
        if (updated.chips == 0) {
          updated = updated.copyWith(status: PlayerStatus.allIn);
        }
        updatePlayer(updated);
        pot += posted;
      }
    }

    // ブラインド: 2人(ヘッズアップ)ではボタン=SB、それ以外はボタンの次がSB。
    final blindSeats = rotated.length >= 3 ? 3 : rotated.length;
    final smallBlindId = rotated.length >= 3 ? rotated[1] : rotated[0];
    final bigBlindId = rotated.length >= 3 ? rotated[2] : rotated[1];
    final sbPosted = postForced(smallBlindId, state.room.smallBlind);
    final bbPosted = postForced(bigBlindId, state.room.bigBlind);
    pot += sbPosted + bbPosted;

    // プリフロップの行動順: BBの次から始まり、ボタン→SB→BBの順で最後に回る
    // (BBが最後に「オプション」を持つ)。
    final preflopOrder = [
      ...rotated.skip(blindSeats),
      ...rotated.take(blindSeats),
    ];
    final pending = preflopOrder
        .where((id) => playerById(id).status == PlayerStatus.active)
        .toList();

    final blindText = state.room.bigBlind > 0
        ? ' (SB \$$sbPosted / BB \$$bbPosted)'
        : '';
    final room = state.room.copyWith(
      phase: GamePhase.preflop,
      pot: pot,
      highestBet: bbPosted,
      turnOrder: rotated,
      pendingToActPlayerIds: pending,
      clearLastAction: true,
      systemMessage: '新しいハンドが開始されました$blindText',
      clearRevealMessage: true,
      clearAdWaiting: true,
      // 実際の徴収額(ショートスタックで満額払えなかった場合を含む)に関わらず
      // 「今回SB/BBの席についているのは誰か」をUI表示用に記録しておく。
      smallBlindPlayerId: smallBlindId,
      bigBlindPlayerId: bigBlindId,
    );

    return GameState(room: room, players: newPlayers);
  }

  /// ロビー中([GamePhase.lobby])にのみホストが呼べる設定変更。
  /// スモール/ビッグブラインド・アンティ・初期チップ枚数を変更できる。
  /// [startingStack]を変更した場合、まだハンドが始まっていない
  /// (=誰の資産も動いていない)ロビー中に限られるため、着席済みの
  /// 全プレイヤーのチップ枚数もその場で新しい値に揃え直す。
  static GameState updateSettings(
    GameState state, {
    int? smallBlind,
    int? bigBlind,
    int? ante,
    int? startingStack,
  }) {
    if (state.room.phase != GamePhase.lobby) {
      throw StateError('ゲーム開始前(ロビー)のみ設定を変更できます');
    }
    final nextSmallBlind = smallBlind ?? state.room.smallBlind;
    final nextBigBlind = bigBlind ?? state.room.bigBlind;
    final nextAnte = ante ?? state.room.ante;
    final nextStartingStack = startingStack ?? state.room.startingStack;

    if (nextSmallBlind < 0 || nextSmallBlind > GameConstants.maxBlindAmount) {
      throw ArgumentError('スモールブラインドが不正です');
    }
    if (nextBigBlind < 0 || nextBigBlind > GameConstants.maxBlindAmount) {
      throw ArgumentError('ビッグブラインドが不正です');
    }
    if (nextBigBlind < nextSmallBlind) {
      throw ArgumentError('ビッグブラインドはスモールブラインド以上にしてください');
    }
    if (nextAnte < 0 || nextAnte > GameConstants.maxAnteAmount) {
      throw ArgumentError('アンティが不正です');
    }
    if (nextStartingStack < GameConstants.minStartingStack ||
        nextStartingStack > GameConstants.maxStartingStack) {
      throw ArgumentError('初期チップ枚数が不正です');
    }

    final stackChanged =
        startingStack != null && startingStack != state.room.startingStack;
    final players = stackChanged
        ? state.players
            .map((p) => p.status == PlayerStatus.kicked
                ? p
                : p.copyWith(chips: nextStartingStack))
            .toList()
        : state.players;

    final room = state.room.copyWith(
      smallBlind: nextSmallBlind,
      bigBlind: nextBigBlind,
      ante: nextAnte,
      startingStack: nextStartingStack,
    );
    return GameState(room: room, players: players);
  }

  /// fold / check / call / raise / allIn のいずれかを適用する。
  static GameState applyAction(
    GameState state, {
    required String playerId,
    required ActionType action,
    int amount = 0,
  }) {
    final players = [...state.players];
    final idx = players.indexWhere((p) => p.id == playerId);
    if (idx == -1) throw ArgumentError('player not found');
    if (!state.room.pendingToActPlayerIds.contains(playerId)) {
      throw StateError('$playerId は現在アクション対象ではありません(手番不一致)');
    }
    var player = players[idx];
    if (player.status != PlayerStatus.active) {
      throw StateError('${player.name} は現在アクションできない状態です');
    }
    var room = state.room;

    final previousHighestBet = room.highestBet;
    int wagered = 0;
    String actionText;

    switch (action) {
      case ActionType.fold:
        player = player.copyWith(status: PlayerStatus.folded);
        actionText = 'Fold';
        break;
      case ActionType.check:
        if (player.currentBet != room.highestBet) {
          throw StateError('コール額が揃っていないためCheckできません');
        }
        actionText = 'Check';
        break;
      case ActionType.call:
        final toCall = (room.highestBet - player.currentBet).clamp(0, player.chips);
        wagered = toCall;
        actionText = toCall == 0 ? 'Check' : 'Call \$$toCall';
        break;
      case ActionType.allIn:
        wagered = player.chips;
        player = player.copyWith(status: PlayerStatus.allIn);
        actionText = 'ALL IN \$$wagered';
        break;
      case ActionType.raise:
        if (amount <= 0 || amount > player.chips) {
          throw ArgumentError('レイズ額が不正です');
        }
        if (player.currentBet + amount <= room.highestBet) {
          throw StateError('レイズ額は現在の最高ベットを上回る必要があります');
        }
        wagered = amount;
        actionText = 'Raise \$${player.currentBet + wagered}';
        break;
    }

    if (wagered > 0) {
      player = player.copyWith(
        chips: player.chips - wagered,
        currentBet: player.currentBet + wagered,
        handContribution: player.handContribution + wagered,
      );
      room = room.copyWith(pot: room.pot + wagered);
      if (player.chips == 0 && player.status == PlayerStatus.active) {
        player = player.copyWith(status: PlayerStatus.allIn);
      }
    }
    players[idx] = player;

    var pending = [...room.pendingToActPlayerIds]..remove(playerId);
    if (player.currentBet > previousHighestBet) {
      // レイズ(または前のベットを上回るオールイン): 他の全アクティブプレイヤーが再度アクション対象になる
      room = room.copyWith(highestBet: player.currentBet);
      pending = players
          .where((p) => p.id != playerId && p.status == PlayerStatus.active)
          .map((p) => p.id)
          .toList();
    }

    final log = ActionLog(
      playerId: playerId,
      playerName: player.name,
      actionType: action,
      displayText: actionText,
    );
    // このストリートで既に誰かがアクションした = カードは既にめくられている前提なので、
    // めくり案内は消してよい。
    room = room.copyWith(
      pendingToActPlayerIds: pending,
      lastAction: log,
      clearRevealMessage: true,
    );

    return _afterAction(GameState(room: room, players: players));
  }

  static GameState kickPlayer(GameState state, String playerId) {
    final players = state.players
        .map((p) => p.id == playerId ? p.copyWith(status: PlayerStatus.kicked) : p)
        .toList();
    var room = state.room.copyWith(
      pendingToActPlayerIds:
          state.room.pendingToActPlayerIds.where((id) => id != playerId).toList(),
      turnOrder: state.room.turnOrder.where((id) => id != playerId).toList(),
    );
    if (room.adWaitingPlayerId == playerId) {
      room = room.copyWith(clearAdWaiting: true);
    }
    return _afterAction(GameState(room: room, players: players));
  }

  static GameState borrow(GameState state, String playerId) {
    if (state.room.phase != GamePhase.interHand) {
      throw StateError('借金はハンド間の待機中のみ可能です');
    }
    if (state.playerById(playerId).chips != 0) {
      throw StateError('手持ちチップが0の場合のみ借入できます');
    }
    final players = state.players.map((p) {
      if (p.id != playerId) return p;
      return p.copyWith(
        chips: p.chips + GameConstants.borrowUnit,
        borrowCount: p.borrowCount + 1,
      );
    }).toList();
    return state.copyWith(players: players);
  }

  static GameState applySecretWord(GameState state, String playerId, String word) {
    if (word.trim().toUpperCase() != GameConstants.secretWord) return state;
    final players = state.players
        .map((p) => p.id == playerId ? p.copyWith(isAdFree: true) : p)
        .toList();
    return state.copyWith(players: players);
  }

  /// 勝者を選択してポットを分配する(ショーダウン)。同点の場合は均等分配。
  static GameState awardPot(GameState state, List<String> winnerIds) {
    if (winnerIds.isEmpty) throw ArgumentError('勝者を1人以上指定してください');
    final pot = state.room.pot;
    final share = pot ~/ winnerIds.length;
    final remainder = pot - share * winnerIds.length;

    var players = state.players.map((p) {
      final winIdx = winnerIds.indexOf(p.id);
      if (winIdx == -1) return p.copyWith(handContribution: 0);
      final bonus = winIdx == 0 ? remainder : 0;
      return p.copyWith(chips: p.chips + share + bonus, handContribution: 0);
    }).toList();

    final room = state.room.copyWith(pot: 0, clearLastAction: true);
    return _concludeHand(GameState(room: room, players: players));
  }

  static GameState resolveAdWatched(GameState state, String playerId) {
    final players = state.players.map((p) {
      if (p.id != playerId) return p;
      return p.copyWith(hearts: GameConstants.maxHearts, status: PlayerStatus.active);
    }).toList();
    var room = state.room;
    if (room.adWaitingPlayerId == playerId) {
      room = room.copyWith(clearAdWaiting: true);
    }
    return GameState(room: room, players: players);
  }

  /// 広告視聴30秒タイムアウト: 強制キック扱いでロック解除する。
  static GameState resolveAdTimeout(GameState state) {
    final waitingId = state.room.adWaitingPlayerId;
    if (waitingId == null) return state;
    return kickPlayer(state, waitingId);
  }

  // ---- 内部ヘルパー ----

  static const _bettingPhases = {
    GamePhase.preflop,
    GamePhase.flop,
    GamePhase.turn,
    GamePhase.river,
  };

  static GameState _afterAction(GameState state) {
    if (!_bettingPhases.contains(state.room.phase)) {
      // ハンド進行中でない(interHand/showdown/lobby)場合はラウンド完了判定を行わない
      return state;
    }
    final inHand = state.players.where((p) => p.isInHand).toList();

    if (inHand.length <= 1) {
      if (inHand.isEmpty) {
        return _concludeHand(
          state.copyWith(room: state.room.copyWith(pot: 0, clearLastAction: true)),
        );
      }
      final winner = inHand.first;
      final players = state.players.map((p) {
        if (p.id != winner.id) return p.copyWith(handContribution: 0);
        return p.copyWith(chips: p.chips + state.room.pot, handContribution: 0);
      }).toList();
      final room = state.room.copyWith(
        pot: 0,
        systemMessage: '${winner.name} の勝利です(他プレイヤーがFold)',
      );
      return _concludeHand(GameState(room: room, players: players));
    }

    if (state.room.pendingToActPlayerIds.isNotEmpty) {
      return state; // まだアクション待ちのプレイヤーがいる
    }

    return _advanceStreet(state, inHand);
  }

  /// [from]の次から[through]までの各ストリートの「めくる案内」ラベルを順番に返す。
  /// 全員all-in等で複数ストリートを一気に自動進行する場合でも、
  /// 案内メッセージが上書きされて消えないよう、呼び出し側でこれをまとめて使う。
  static List<String> _revealLabelsBetween(GamePhase from, GamePhase through) {
    const order = [GamePhase.preflop, GamePhase.flop, GamePhase.turn, GamePhase.river];
    final fromIndex = order.indexOf(from);
    final throughIndex = order.indexOf(through);
    return [
      for (var i = fromIndex + 1; i <= throughIndex; i++) _revealLabel(order[i]),
    ];
  }

  static String _revealLabel(GamePhase phase) {
    switch (phase) {
      case GamePhase.flop:
        return 'フロップ(3枚)';
      case GamePhase.turn:
        return 'ターン(1枚)';
      case GamePhase.river:
        return 'リバー(1枚)';
      case GamePhase.preflop:
      case GamePhase.showdown:
      case GamePhase.lobby:
      case GamePhase.interHand:
        return '';
    }
  }

  static GameState _advanceStreet(GameState state, List<Player> inHand, {GamePhase? fromPhase}) {
    // 再帰で複数ストリートを飛ばして進む場合も、最初の呼び出し時点のフェーズを
    // 覚えておくことで、飛ばした分すべてのめくり案内をまとめて提示できる。
    final startPhase = fromPhase ?? state.room.phase;
    var room = state.room;
    var players = state.players;
    final activeDeciders = inHand.where((p) => p.status == PlayerStatus.active).toList();

    if (room.phase == GamePhase.river || activeDeciders.length <= 1) {
      final revealed = _revealLabelsBetween(startPhase, GamePhase.river);
      room = room.copyWith(
        phase: GamePhase.showdown,
        systemMessage: 'ショーダウン: 勝者を選択してください',
        pendingToActPlayerIds: const [],
        revealMessage: revealed.isEmpty ? null : '${revealed.join('→')}をめくってください',
        clearRevealMessage: revealed.isEmpty,
      );
      return GameState(room: room, players: players);
    }

    final nextPhase = _nextPhase(room.phase);
    players = players.map((p) {
      if (!p.isInHand) return p;
      return p.copyWith(currentBet: 0);
    }).toList();
    // フロップ以降はボタンの次のプレイヤーから行動が始まり、ボタンが最後になる
    // (プリフロップだけはBBの次から始まるので[startHand]で別途決めている)。
    final postflopOrder = room.turnOrder.length > 1
        ? [...room.turnOrder.skip(1), room.turnOrder.first]
        : room.turnOrder;
    final pending = postflopOrder
        .where((id) => players.firstWhere((p) => p.id == id).status == PlayerStatus.active)
        .toList();

    final revealed = _revealLabelsBetween(startPhase, nextPhase);
    room = room.copyWith(
      phase: nextPhase,
      highestBet: 0,
      pendingToActPlayerIds: pending,
      clearLastAction: true,
      revealMessage: '${revealed.join('→')}をめくってください',
    );

    final nextState = GameState(room: room, players: players);
    if (pending.isEmpty) {
      // 全員allIn等でこれ以上ベットできない場合は次のストリートへ自動進行
      return _advanceStreet(nextState, inHand, fromPhase: startPhase);
    }
    return nextState;
  }

  static GameState _concludeHand(GameState state) {
    var players = state.players.map((p) {
      if (p.status == PlayerStatus.kicked || p.isAdFree) return p;
      final hearts = (p.hearts - 1).clamp(0, GameConstants.maxHearts);
      return p.copyWith(hearts: hearts);
    }).toList();

    String? adWaitingPlayerId;
    DateTime? adWaitingDeadline;
    players = players.map((p) {
      if (p.status == PlayerStatus.kicked) return p;
      if (p.hearts == 0 && p.status != PlayerStatus.waitingAd) {
        adWaitingPlayerId ??= p.id;
        adWaitingDeadline ??= DateTime.now().add(GameConstants.adWaitTimeout);
        return p.copyWith(status: PlayerStatus.waitingAd);
      }
      return p;
    }).toList();

    final room = state.room.copyWith(
      phase: GamePhase.interHand,
      pendingToActPlayerIds: const [],
      adWaitingPlayerId: adWaitingPlayerId,
      adWaitingDeadline: adWaitingDeadline,
      clearRevealMessage: true,
      clearBlindPlayers: true,
    );
    return GameState(room: room, players: players);
  }

  static GamePhase _nextPhase(GamePhase phase) {
    switch (phase) {
      case GamePhase.preflop:
        return GamePhase.flop;
      case GamePhase.flop:
        return GamePhase.turn;
      case GamePhase.turn:
        return GamePhase.river;
      case GamePhase.river:
      case GamePhase.showdown:
      case GamePhase.lobby:
      case GamePhase.interHand:
        return GamePhase.river;
    }
  }
}
