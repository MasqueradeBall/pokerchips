import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/enums.dart';
import '../../../models/player.dart';
import '../../../widgets/animated_chip_counter.dart';
import '../../../widgets/avatar_circle.dart';

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({
    super.key,
    required this.player,
    required this.isSelf,
    required this.isCurrentTurn,
    this.lastActionText,
    this.showUndo = false,
    this.canKick = false,
    this.onUndo,
    this.onKick,
  });

  final Player player;
  final bool isSelf;
  final bool isCurrentTurn;
  final String? lastActionText;
  final bool showUndo;
  final bool canKick;
  final VoidCallback? onUndo;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final folded = player.status == PlayerStatus.folded;
    final allIn = player.status == PlayerStatus.allIn;

    return GestureDetector(
      // ホストは他プレイヤーのバッジをタップするとキックの確認を開ける。
      onTap: canKick ? onKick : null,
      child: AnimatedOpacity(
        // フォールドしたらバッジ全体を沈ませ、状況をひと目でわかるようにする。
        opacity: folded ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarCircle(
                name: player.name,
                isSelf: isSelf,
                isCurrentTurn: isCurrentTurn,
                dimmed: folded,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (player.isHost)
                    const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.star_rounded,
                        size: 11,
                        color: AppColors.goldLight,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelf
                        ? AppColors.gold.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedChipCounter(
                      value: player.netAsset,
                      prefix: '資産: \$',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: player.netAsset <= 0 ? AppColors.chipRed : Colors.white,
                      ),
                    ),
                    AnimatedChipCounter(
                      value: player.chips,
                      prefix: '手持ち: \$',
                      style: const TextStyle(fontSize: 9, color: AppColors.goldLight),
                    ),
                    if (player.borrowCount > 0)
                      Text(
                        '借入 x${player.borrowCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.chipRed,
                        ),
                      ),
                  ],
                ),
              ),
              // アクション吹き出し: 変化時にふわっと切り替える。
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: lastActionText == null
                    ? const SizedBox(height: 4, key: ValueKey('no-action'))
                    : Padding(
                        key: ValueKey('${allIn ? 'ALL IN' : lastActionText}-$showUndo'),
                        padding: const EdgeInsets.only(top: 4),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: allIn
                                    ? AppColors.chipRed.withValues(alpha: 0.9)
                                    : Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: allIn
                                      ? AppColors.goldLight
                                      : Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                allIn ? 'ALL IN' : lastActionText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: allIn ? 1 : 0,
                                ),
                              ),
                            ),
                            if (showUndo)
                              Positioned(
                                top: -8,
                                right: -8,
                                child: GestureDetector(
                                  onTap: onUndo,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: AppColors.chipRed,
                                      shape: BoxShape.circle,
                                      border: Border.fromBorderSide(
                                        BorderSide(color: Colors.white, width: 1),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '×',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
