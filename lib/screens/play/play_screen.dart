import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/room_snapshot.dart';
import '../../domain/game_state.dart';
import '../../models/enums.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../providers/game_controllers.dart';
import '../../providers/room_providers.dart';
import '../../widgets/felt_background.dart';
import '../waiting/waiting_screen.dart';
import 'widgets/action_bar.dart';
import 'widgets/allin_effect.dart';
import 'widgets/player_badge.dart';
import 'widgets/pot_display.dart';
import 'widgets/raise_bottom_sheet.dart';
import 'widgets/system_message_overlay.dart';

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
    final snapshotAsync = ref.watch(roomSnapshotProvider);
    final controller = ref.read(gameControllerProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: FeltBackground(
          child: SafeArea(
            child: snapshotAsync.when(
              data: (snapshot) => _PlayContent(snapshot: snapshot, controller: controller),
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              error: (error, stack) => Center(
                child: Text('エラー: $error', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayContent extends StatelessWidget {
  const _PlayContent({required this.snapshot, required this.controller});

  final RoomSnapshot snapshot;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final state = snapshot.state;
    final room = state.room;
    final players = state.seatedPlayers;
    final self = state.playerById(snapshot.selfPlayerId);
    final isHostViewer = room.hostPlayerId == snapshot.selfPlayerId;

    return Column(
      children: [
        _HeaderBar(self: self, roomCode: room.code),
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
                  ],
                ),
        ),
        if (room.phase == GamePhase.showdown)
          _ShowdownPanel(
            players: players.where((p) => p.isInHand).toList(),
            pot: room.pot,
            isHostViewer: isHostViewer,
            onAward: controller.awardPot,
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
  const _HeaderBar({required this.self, required this.roomCode});

  final Player self;
  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < self.hearts ? Icons.favorite : Icons.favorite_border,
                color: AppColors.chipRed,
                size: 16,
              ),
            ),
          ),
          Text(
            'Room: $roomCode',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
          const SizedBox(height: 12),
          const Text(
            'ルームID',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12),
          ),
          Text(
            room.code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'このIDを他のプレイヤーに共有してください',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 32),
          Text(
            '参加者 (${players.length}人)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: players.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = players[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (p.isHost)
                        const Text('HOST', style: TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.bold)),
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
            const Text(
              'ホストの開始を待っています…',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
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

  List<double> _otherAngles(int count) {
    if (count == 0) return [];
    if (count == 1) return [270];
    const spread = 150.0;
    final start = 270 - spread / 2;
    final step = spread / (count - 1);
    return [for (var i = 0; i < count; i++) start + step * i];
  }

  void _confirmKick(BuildContext context, Player player) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('プレイヤーをキック', style: TextStyle(color: Colors.white)),
        content: Text(
          '${player.name} をキックしますか？\n(賭けていたチップはデッドマネーとしてポットに残ります)',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              controller.kick(player.id);
              Navigator.pop(context);
            },
            child: const Text('キックする', style: TextStyle(color: AppColors.chipRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = state.room;
    final others = players.where((p) => p.id != self.id).toList();
    final angles = _otherAngles(others.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final center = Offset(width / 2, height / 2 - 10);
        final radiusX = max(width / 2 - 60, 60.0);
        final radiusY = max(height / 2 - 70, 70.0);

        Offset positionFor(double angleDeg) {
          final theta = angleDeg * pi / 180;
          return center + Offset(radiusX * cos(theta), radiusY * sin(theta));
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
            Positioned(
              left: center.dx - radiusX * 0.78,
              top: center.dy - radiusY * 0.7,
              child: Container(
                width: radiusX * 1.56,
                height: radiusY * 1.4,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.elliptical(radiusX * 0.78, radiusY * 0.7)),
                  gradient: RadialGradient(
                    colors: [
                      AppColors.feltGreenLight.withValues(alpha: 0.55),
                      AppColors.feltGreen.withValues(alpha: 0.15),
                    ],
                  ),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 3),
                ),
              ),
            ),
            Positioned(
              left: center.dx - 60,
              top: center.dy - 30,
              child: SizedBox(width: 120, child: PotDisplay(pot: room.pot)),
            ),
            for (var i = 0; i < others.length; i++)
              Builder(builder: (context) {
                final pos = positionFor(angles[i]);
                return Positioned(
                  left: pos.dx - 46,
                  top: pos.dy - 60,
                  child: badgeFor(others[i], isSelf: false),
                );
              }),
            Positioned(
              left: (positionFor(90)).dx - 46,
              top: (positionFor(90)).dy - 60,
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
  });

  final List<Player> players;
  final int pot;
  final bool isHostViewer;
  final void Function(List<String> winnerIds) onAward;

  @override
  State<_ShowdownPanel> createState() => _ShowdownPanelState();
}

class _ShowdownPanelState extends State<_ShowdownPanel> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    if (!widget.isHostViewer) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'ショーダウン: ホストが勝者を選択しています…',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ショーダウン: 勝者を選択してください (POT \$${widget.pot})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final p in widget.players)
                FilterChip(
                  label: Text(p.name),
                  selected: _selected.contains(p.id),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selected.add(p.id);
                    } else {
                      _selected.remove(p.id);
                    }
                  }),
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.surfaceDark,
                  labelStyle: TextStyle(
                    color: _selected.contains(p.id) ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _selected.isEmpty
                ? null
                : () => widget.onAward(_selected.toList()),
            child: const Text('勝者を確定してポットを分配'),
          ),
        ],
      ),
    );
  }
}
