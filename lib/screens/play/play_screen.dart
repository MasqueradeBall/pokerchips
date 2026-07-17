import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/room_snapshot.dart';
import '../../domain/game_state.dart';
import '../../models/enums.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../providers/game_controllers.dart';
import '../../providers/room_providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/felt_background.dart';
import '../waiting/waiting_screen.dart';
import 'widgets/action_bar.dart';
import 'widgets/allin_effect.dart';
import 'widgets/bet_chip_stack.dart';
import 'widgets/card_reveal_overlay.dart';
import 'widgets/casino_table_surface.dart';
import 'widgets/lobby_settings_sheet.dart';
import 'widgets/player_badge.dart';
import 'widgets/pot_display.dart';
import 'widgets/raise_bottom_sheet.dart';
import 'widgets/system_message_overlay.dart';
import 'widgets/table_geometry.dart';
import 'widgets/winner_collection_effect.dart';

const _bettingPhases = {
  GamePhase.preflop,
  GamePhase.flop,
  GamePhase.turn,
  GamePhase.river,
};

class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ここでは ref.watch しない: PlayScreen/PopScope自体がroomSnapshotの更新
    // (対戦相手のアクションやBotの自動着手)のたびに毎回作り直されると、
    // ダイアログ表示/破棄のタイミングとPopScopeのRoute依存が競合し、
    // 「_dependents.isEmpty」assertionでクラッシュすることがある。
    // 実際にstreamを購読する箇所は下のConsumerに閉じ込め、
    // PopScope/ScaffoldのElementはデータ更新の影響を受けないようにする。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final controller = ref.read(gameControllerProvider);
        final selfId = ref.read(roomSnapshotProvider).valueOrNull?.selfPlayerId;
        if (selfId == null) {
          Navigator.of(context).pop();
          return;
        }
        // iOSのスワイプ戻るジェスチャーが中断されるアニメーションの途中で
        // 同期的にダイアログを開くとフレームワーク内部のツリー処理と衝突して
        // 「_dependents.isEmpty」assertionでクラッシュするため、1フレーム後に遅延させる。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _confirmLeaveRoom(context, controller: controller, selfPlayerId: selfId);
        });
      },
      child: Scaffold(
        // あいことば入力ダイアログ等でキーボードが開いた際、背景のテーブル
        // (LayoutBuilderで画面高さから盤面サイズを計算している)が
        // キーボード分縮んで崩れて見えないようにする。
        resizeToAvoidBottomInset: false,
        body: FeltBackground(
          child: SafeArea(
            child: Consumer(
              builder: (context, ref, _) {
                final snapshotAsync = ref.watch(roomSnapshotProvider);
                final controller = ref.read(gameControllerProvider);
                return snapshotAsync.when(
                  data: (snapshot) => _PlayContent(
                    snapshot: snapshot,
                    controller: controller,
                    onLeave: () => _confirmLeaveRoom(
                      context,
                      controller: controller,
                      selfPlayerId: snapshot.selfPlayerId,
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('エラー: $error', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('ホームに戻る'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// ルーム退出の確認ダイアログを表示し、確定したら自分をルームから外して
/// 前の画面(ホーム)に戻る。
Future<void> _confirmLeaveRoom(
  BuildContext context, {
  required GameController controller,
  required String selfPlayerId,
}) async {
  final confirmed = await showAppDialog<bool>(
    context,
    builder: (dialogContext) => AppDialog(
      icon: Icons.logout_rounded,
      iconColor: AppColors.chipRed,
      title: 'ルームを退出',
      content: const Text(
        'ルームを退出してホーム画面に戻りますか？\n(賭けていたチップはデッドマネーとしてポットに残ります)',
      ),
      actions: [
        AppDialogCancelButton(onPressed: () => Navigator.pop(dialogContext, false)),
        AppDialogDangerButton(
          label: '退出する',
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (context.mounted) Navigator.of(context).pop();
  // ダイアログの終了アニメーションと同じフレームでルーム状態を書き換えると
  // 「_dependents.isEmpty」クラッシュを誘発することがあるため、1フレーム遅らせる。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.kick(selfPlayerId);
  });
}

class _PlayContent extends StatefulWidget {
  const _PlayContent({required this.snapshot, required this.controller, required this.onLeave});

  final RoomSnapshot snapshot;
  final GameController controller;
  final VoidCallback onLeave;

  @override
  State<_PlayContent> createState() => _PlayContentState();
}

class _PlayContentState extends State<_PlayContent> {
  /// 勝者確定後、チップ回収演出が終わるまでの間だけ保持する勝者IDリスト。
  /// null 以外の間はショーダウンパネルの操作を無効化する。
  List<String>? _pendingWinnerIds;

  /// WinnerCollectionEffect の再生トリガー (値が変わるたびに再生される)。
  int _awardTicket = 0;

  /// ホストが勝者を確定したときの入り口。すぐに awardPot するのではなく、
  /// まずチップ回収演出を再生し、演出が終わったタイミングで実際に
  /// ポットを分配する (フェーズ遷移で盤面が消える前に演出を見せるため)。
  ///
  /// awardPot の呼び出しは Timer で確定させる: 演出側の状態に依存しないので
  /// 何があっても必ず一度だけ呼ばれ、ホストが操作不能のまま
  /// 取り残されることがない。
  void _beginAward(List<String> winnerIds) {
    if (_pendingWinnerIds != null) return; // 二度押し防止
    final ids = List<String>.from(winnerIds);
    setState(() {
      _pendingWinnerIds = ids;
      _awardTicket++;
    });
    Timer(WinnerCollectionEffect.duration, () {
      widget.controller.awardPot(ids);
      if (mounted) setState(() => _pendingWinnerIds = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final controller = widget.controller;
    final state = snapshot.state;
    final room = state.room;
    final players = state.seatedPlayers;
    final self = state.playerById(snapshot.selfPlayerId);
    final isHostViewer = room.hostPlayerId == snapshot.selfPlayerId;

    return Column(
      children: [
        _HeaderBar(
          self: self,
          roomCode: room.code,
          controller: controller,
          onLeave: widget.onLeave,
        ),
        Expanded(
          child: room.phase == GamePhase.lobby
              ? _LobbyPanel(
                  room: room,
                  players: players,
                  isHostViewer: isHostViewer,
                  controller: controller,
                )
              : room.phase == GamePhase.interHand
              ? WaitingPanel(
                  state: state,
                  selfPlayerId: snapshot.selfPlayerId,
                  controller: controller,
                )
              : Stack(
                  children: [
                    _TableArea(
                      state: state,
                      players: players,
                      self: self,
                      isHostViewer: isHostViewer,
                      canUndo: snapshot.canUndo,
                      controller: controller,
                    ),
                    SystemMessageOverlay(message: room.systemMessage),
                    AllInEffect(
                      trigger: room.lastAction?.actionType == ActionType.allIn
                          ? room.lastAction
                          : null,
                      playerName: room.lastAction?.playerName ?? '',
                    ),
                    // 勝者確定時のチップ回収演出。演出中はまだ showdown
                    // フェーズのままなので、この Stack (盤面) の上に重なる。
                    Positioned.fill(
                      child: WinnerCollectionEffect(
                        trigger: _awardTicket == 0 ? null : _awardTicket,
                        winnerIds: _pendingWinnerIds ?? const [],
                        players: players,
                        selfId: snapshot.selfPlayerId,
                      ),
                    ),
                    Positioned.fill(
                      child: CardRevealOverlay(message: room.revealMessage),
                    ),
                  ],
                ),
        ),
        if (room.phase == GamePhase.showdown)
          _ShowdownPanel(
            players: players.where((p) => p.isInHand).toList(),
            pot: room.pot,
            isHostViewer: isHostViewer,
            // 演出を挟んでから awardPot するため、直接は呼ばない。
            onAward: _beginAward,
            awarding: _pendingWinnerIds != null,
          )
        else if (_bettingPhases.contains(room.phase))
          _buildActionBar(room, self, controller),
      ],
    );
  }

  Widget _buildActionBar(Room room, Player self, GameController controller) {
    final isMyTurn = room.currentTurnPlayerId == self.id && self.status == PlayerStatus.active;
    final toCall = room.highestBet - self.currentBet;
    final callLabel = toCall <= 0 ? 'Check' : 'Call \$$toCall';

    return Builder(
      builder: (context) => ActionBar(
        canAct: isMyTurn,
        callLabel: callLabel,
        onFold: () => controller.fold(self.id),
        onCheckOrCall: () {
          if (toCall <= 0) {
            controller.check(self.id);
          } else {
            controller.call(self.id);
          }
        },
        onRaise: () async {
          final amount = await showRaiseSheet(
            context,
            pot: room.pot,
            highestBet: room.highestBet,
            myCurrentBet: self.currentBet,
            myChips: self.chips,
          );
          if (amount != null) controller.raise(self.id, amount);
        },
        onAllIn: () => controller.allIn(self.id),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.self,
    required this.roomCode,
    required this.controller,
    required this.onLeave,
  });

  final Player self;
  final String roomCode;
  final GameController controller;
  final VoidCallback onLeave;

  Future<void> _showSecretWordDialog(BuildContext context) async {
    final word = await showAppDialog<String>(
      context,
      builder: (dialogContext) => const _SecretWordDialog(),
    );
    if (word == null || word.trim().isEmpty) return;
    final correct = word.trim().toUpperCase() == GameConstants.secretWord;
    if (correct) {
      // ダイアログの終了アニメーションと同じフレームでルーム状態を書き換えると
      // 「_dependents.isEmpty」クラッシュを誘発することがあるため、1フレーム遅らせる。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.applySecretWord(self.id, word);
      });
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          correct ? 'あいことばが正解です!広告が非表示になりました' : 'あいことばが違います',
        ),
        backgroundColor: correct ? AppColors.chipGreen : AppColors.chipRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        children: [
          // 退出ボタン: 縁取り付きの丸ボタンでタップ対象を明確に。
          _HeaderCircleButton(
            icon: Icons.logout_rounded,
            tooltip: 'ルームを退出',
            onPressed: onLeave,
          ),
          const Spacer(),
          // ハート + あいことばキーをひとつのピルにまとめる。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(5, (i) {
                  final filled = i < self.hearts;
                  // ハートの増減をスケールで切り替えるマイクロアニメーション。
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      filled ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(filled),
                      color: filled
                          ? AppColors.chipRed
                          : AppColors.chipRed.withValues(alpha: 0.45),
                      size: 15,
                    ),
                  );
                }),
                const SizedBox(width: 6),
                Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.15)),
                SizedBox(
                  width: 32,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      self.isAdFree ? Icons.vpn_key : Icons.vpn_key_outlined,
                      color: self.isAdFree ? AppColors.goldLight : Colors.white70,
                      size: 16,
                    ),
                    tooltip: self.isAdFree ? 'あいことば適用済み' : 'あいことばを入力',
                    onPressed:
                        self.isAdFree ? null : () => _showSecretWordDialog(context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ルームコードのプレート。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ROOM',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  roomCode,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ヘッダー用の縁取り付き丸アイコンボタン。
class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white70, size: 17),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// あいことば入力ダイアログの中身。
///
/// TextEditingControllerはこのStatefulWidget自身のinitState/disposeで
/// 管理する(showDialogの呼び出し元でawait後にdispose()するのはNG:
/// ダイアログの閉じるアニメーションがまだ再生中でTextFieldがmountされたまま
/// disposeされたControllerを参照し続けてしまい、
/// 「A TextEditingController was used after being disposed.」で
/// クラッシュする。Flutterのウィジェットライフサイクルに委ねることで、
/// 実際にunmountされるタイミング(アニメーション完了後)まで安全に生かす)。
class _SecretWordDialog extends StatefulWidget {
  const _SecretWordDialog();

  @override
  State<_SecretWordDialog> createState() => _SecretWordDialogState();
}

class _SecretWordDialogState extends State<_SecretWordDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.vpn_key,
      title: 'あいことば',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('正しく入力すると広告が非表示になります'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            decoration: const InputDecoration(hintText: 'あいことばを入力'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        AppDialogCancelButton(onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('決定'),
        ),
      ],
    );
  }
}

/// ハンド開始前のロビー画面。ルームIDを共有し、参加者が揃うのを待つ。
class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.room,
    required this.players,
    required this.isHostViewer,
    required this.controller,
  });

  final Room room;
  final List<Player> players;
  final bool isHostViewer;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final canStart = players.length >= 2;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // ルームIDのチケット風プレート。
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceCard,
                  AppColors.darken(AppColors.surfaceCard, 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'ルームID',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, letterSpacing: 3, fontSize: 11),
                ),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, AppColors.goldLight],
                  ).createShader(bounds),
                  child: Text(
                    room.code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'このIDを他のプレイヤーに共有してください',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 現在のゲーム設定サマリー + ホストは設定変更可能
          LobbySettingsBar(
            room: room,
            isHost: isHostViewer,
            onEdit: isHostViewer
                ? () => showLobbySettingsSheet(context, room: room, controller: controller)
                : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('参加者', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${players.length}人',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: players.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = players[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      AvatarCircle(name: p.name, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (p.isHost)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 11, color: AppColors.goldLight),
                              SizedBox(width: 3),
                              Text(
                                'HOST',
                                style: TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (isHostViewer)
            ElevatedButton(
              onPressed: canStart ? controller.startNextHand : null,
              child: Text(canStart ? 'ゲームを開始' : '2人以上集まると開始できます'),
            )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'ホストの開始を待っています…',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea({
    required this.state,
    required this.players,
    required this.self,
    required this.isHostViewer,
    required this.canUndo,
    required this.controller,
  });

  final GameState state;
  final List<Player> players;
  final Player self;
  final bool isHostViewer;
  final bool canUndo;
  final GameController controller;

  void _confirmKick(BuildContext context, Player player) {
    showAppDialog<void>(
      context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.person_remove_rounded,
        iconColor: AppColors.chipRed,
        title: 'プレイヤーをキック',
        content: Text(
          '${player.name} をキックしますか？\n(賭けていたチップはデッドマネーとしてポットに残ります)',
        ),
        actions: [
          AppDialogCancelButton(onPressed: () => Navigator.pop(dialogContext)),
          AppDialogDangerButton(
            label: 'キックする',
            onPressed: () {
              Navigator.pop(dialogContext);
              // ダイアログの終了アニメーションと同じフレームでルーム状態を書き換えると
              // 「_dependents.isEmpty」クラッシュを誘発することがあるため、1フレーム遅らせる。
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.kick(player.id);
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = state.room;
    final others = players.where((p) => p.id != self.id).toList();
    final angles = TableGeometry.otherAngles(others.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        // バッジ・ベットチップ・各演出で共有する楕円ジオメトリ。
        final geo = TableGeometry(constraints.maxWidth, constraints.maxHeight);
        final center = geo.center;

        /// プレイヤーの席の角度。自分は常に真下(90度)。
        double angleOf(Player player) {
          if (player.id == self.id) return TableGeometry.selfAngle;
          final i = others.indexWhere((p) => p.id == player.id);
          return i < 0 ? TableGeometry.selfAngle : angles[i];
        }

        Widget badgeFor(Player player, {required bool isSelf}) {
          final isCurrentTurn = room.currentTurnPlayerId == player.id;
          final showUndo = isHostViewer && canUndo && room.lastAction?.playerId == player.id;
          return PlayerBadge(
            player: player,
            isSelf: isSelf,
            isCurrentTurn: isCurrentTurn,
            lastActionText: room.lastAction?.playerId == player.id
                ? room.lastAction?.displayText
                : null,
            showUndo: showUndo,
            canKick: isHostViewer && !isSelf,
            onUndo: controller.undo,
            onKick: () => _confirmKick(context, player),
          );
        }

        return Stack(
          children: [
            // カジノテーブルのイラスト風背景 (レール/インレイ/フェルト)。
            Positioned(
              left: center.dx - geo.radiusX * 0.78,
              top: center.dy - geo.radiusY * 0.7,
              child: CasinoTableSurface(
                width: geo.radiusX * 1.56,
                height: geo.radiusY * 1.4,
              ),
            ),
            // 各プレイヤーの前に置かれるベットチップ (currentBet > 0 の間だけ
            // 見える。常にマウントしておき、0に戻ったら縮んで消える)。
            for (final player in players)
              Builder(builder: (context) {
                final pos = geo.betPositionFor(angleOf(player));
                return Positioned(
                  left: pos.dx - 30,
                  top: pos.dy - 26,
                  child: SizedBox(
                    width: 60,
                    child: Center(
                      child: BetChipStack(amount: player.currentBet),
                    ),
                  ),
                );
              }),
            Positioned(
              left: center.dx - 75,
              top: center.dy - 34,
              child: SizedBox(
                width: 150,
                child: Center(child: PotDisplay(pot: room.pot)),
              ),
            ),
            for (var i = 0; i < others.length; i++)
              Builder(builder: (context) {
                final pos = geo.positionFor(angles[i]);
                return Positioned(
                  left: pos.dx - 46,
                  top: pos.dy - 60,
                  child: badgeFor(others[i], isSelf: false),
                );
              }),
            Positioned(
              left: geo.positionFor(TableGeometry.selfAngle).dx - 46,
              top: geo.positionFor(TableGeometry.selfAngle).dy - 60,
              child: badgeFor(self, isSelf: true),
            ),
          ],
        );
      },
    );
  }
}

class _ShowdownPanel extends StatefulWidget {
  const _ShowdownPanel({
    required this.players,
    required this.pot,
    required this.isHostViewer,
    required this.onAward,
    required this.awarding,
  });

  final List<Player> players;
  final int pot;
  final bool isHostViewer;
  final void Function(List<String> winnerIds) onAward;

  /// チップ回収演出の再生中。trueの間は選択と確定ボタンを無効化し、
  /// 二度押しで awardPot が重複しないようにする。
  final bool awarding;

  @override
  State<_ShowdownPanel> createState() => _ShowdownPanelState();
}

class _ShowdownPanelState extends State<_ShowdownPanel> {
  final Set<String> _selected = {};

  BoxDecoration get _panelDecoration => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark.withValues(alpha: 0.96),
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (widget.awarding) {
      // チップ回収演出の主役はテーブル上のアニメーションなので、
      // ここでは選択UIごと重い暗色パネルを畳み、透過度の高い
      // 勝者発表バーだけを残して盤面を暗くしすぎないようにする。
      final winnerNames = widget.players
          .where((p) => _selected.contains(p.id))
          .map((p) => p.name)
          .join(' / ');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceDark.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.goldLight, size: 26),
            const SizedBox(height: 6),
            if (winnerNames.isNotEmpty)
              Text(
                '$winnerNames の勝利!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            const SizedBox(height: 2),
            Text(
              'ポットを分配しています…',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!widget.isHostViewer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: _panelDecoration,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'ショーダウン: ホストが勝者を選択しています…',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: _panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SHOWDOWN',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '勝者を選択してください (POT \$${widget.pot})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final p in widget.players)
                FilterChip(
                  label: Text(p.name),
                  selected: _selected.contains(p.id),
                  onSelected: widget.awarding
                      ? null
                      : (v) => setState(() {
                            if (v) {
                              _selected.add(p.id);
                            } else {
                              _selected.remove(p.id);
                            }
                          }),
                  showCheckmark: true,
                  checkmarkColor: Colors.black,
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.surfaceDark,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: _selected.contains(p.id)
                          ? AppColors.goldLight
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: _selected.contains(p.id) ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty || widget.awarding
                  ? null
                  : () => widget.onAward(_selected.toList()),
              child: Text(
                widget.awarding ? 'ポットを分配しています…' : '勝者を確定してポットを分配',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
