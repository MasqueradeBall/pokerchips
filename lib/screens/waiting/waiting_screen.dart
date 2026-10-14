import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/ads/ad_service.dart';
import '../../domain/game_state.dart';
import '../../models/player.dart';
import '../../providers/game_controllers.dart';
import '../../widgets/avatar_circle.dart';
import '../play/widgets/kick_dialog.dart';

/// ハンド終了後の待機画面(画面3): ハート回復広告待ち + 借金 + 次のハンド開始。
class WaitingPanel extends StatefulWidget {
  const WaitingPanel({
    super.key,
    required this.state,
    required this.selfPlayerId,
    required this.controller,
  });

  final GameState state;
  final String selfPlayerId;
  final GameController controller;

  @override
  State<WaitingPanel> createState() => _WaitingPanelState();
}

class _WaitingPanelState extends State<WaitingPanel> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _watchingAd = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.preload();
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final deadline = widget.state.room.adWaitingDeadline;
    if (deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  Future<void> _watchAd(String playerId) async {
    setState(() => _watchingAd = true);
    final rewarded = await AdService.instance.showRewardedAd();
    if (!mounted) return;
    setState(() => _watchingAd = false);
    if (rewarded) {
      widget.controller.resolveAdWatched(playerId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('広告を読み込み中です。少し待ってからもう一度お試しください')),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.state.room;
    final players = widget.state.seatedPlayers;
    final self = widget.state.playerById(widget.selfPlayerId);
    final isHost = room.hostPlayerId == widget.selfPlayerId;
    final waitingPlayer = room.adWaitingPlayerId == null
        ? null
        : players.where((p) => p.id == room.adWaitingPlayerId).firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // オールイン演出と同じゴールドの飾り罫でタイトルを飾る。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ornamentLine(reversed: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('ハンド終了', style: Theme.of(context).textTheme.titleLarge),
              ),
              _ornamentLine(reversed: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '次のハンドまで待機中です',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (waitingPlayer != null) _AdWaitingCard(
                  player: waitingPlayer,
                  isSelf: waitingPlayer.id == widget.selfPlayerId,
                  remaining: _remaining,
                  watching: _watchingAd,
                  onWatchAd: () => _watchAd(waitingPlayer.id),
                ),
                if (waitingPlayer != null) const SizedBox(height: 12),
                for (final p in players)
                  _PlayerSummaryTile(
                    player: p,
                    isSelf: p.id == self.id,
                    onKick: isHost && p.id != self.id
                        ? () => showKickConfirmDialog(
                              context,
                              controller: widget.controller,
                              player: p,
                            )
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: self.chips == 0 ? () => widget.controller.borrow(self.id) : null,
                  icon: const Icon(Icons.attach_money),
                  label: Text(self.chips == 0 ? '+10k 借入する' : '手持ちが0の時のみ借入可'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isHost && room.adWaitingPlayerId == null
                      ? widget.controller.startNextHand
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(isHost ? '次のハンドを開始' : 'ホストの開始を待っています'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ornamentLine({required bool reversed}) {
    return Container(
      width: 52,
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reversed ? Alignment.centerRight : Alignment.centerLeft,
          end: reversed ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            AppColors.gold.withValues(alpha: 0),
            AppColors.gold.withValues(alpha: 0.8),
          ],
        ),
      ),
    );
  }
}

class _AdWaitingCard extends StatelessWidget {
  const _AdWaitingCard({
    required this.player,
    required this.isSelf,
    required this.remaining,
    required this.watching,
    required this.onWatchAd,
  });

  final Player player;
  final bool isSelf;
  final Duration remaining;
  final bool watching;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    // 残り10秒を切ったら赤に切り替えて緊急度を伝える。
    final urgent = remaining.inSeconds <= 10;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgent ? AppColors.chipRed : AppColors.goldLight),
        boxShadow: [
          BoxShadow(
            color: (urgent ? AppColors.chipRed : AppColors.gold).withValues(alpha: 0.2),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite_border,
            color: urgent ? AppColors.chipRed : AppColors.goldLight,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            isSelf
                ? 'ハートが0になりました。動画広告を視聴して回復してください'
                : '${player.name} がハートを回復しています…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: urgent ? AppColors.chipRed : AppColors.goldLight,
              fontSize: urgent ? 12 : 11,
              fontWeight: urgent ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text('※ ${remaining.inSeconds}秒経過で自動キック'),
          ),
          if (isSelf) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: watching ? null : onWatchAd,
              icon: const Icon(Icons.play_circle_fill),
              label: Text(watching ? '広告を再生中…' : '広告を視聴してハート回復'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerSummaryTile extends StatelessWidget {
  const _PlayerSummaryTile({required this.player, required this.isSelf, this.onKick});

  final Player player;
  final bool isSelf;

  /// ホストが他プレイヤーを見ている場合のみ非null。キックボタンを表示する。
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelf
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surfaceCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelf
              ? AppColors.gold.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          AvatarCircle(name: player.name, size: 32, isSelf: isSelf),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                if (player.isHost)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.star_rounded, size: 13, color: AppColors.goldLight),
                  ),
                Flexible(
                  child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                if (player.borrowCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.chipRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.chipRed.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '借入 x${player.borrowCount}',
                      style: const TextStyle(
                        color: AppColors.chipRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < player.hearts ? Icons.favorite : Icons.favorite_border,
                color: AppColors.chipRed,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '\$${player.netAsset}',
            style: TextStyle(
              color: player.netAsset <= 0 ? AppColors.chipRed : AppColors.goldLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onKick != null) ...[
            const SizedBox(width: 4),
            KickIconButton(onPressed: onKick!),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
