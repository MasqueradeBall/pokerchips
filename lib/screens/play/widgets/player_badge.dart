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
      onLongPress: canKick ? onKick : null,
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
            Text(
              player.isHost ? '${player.name} (Host)' : player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
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
                ],
              ),
            ),
            if (lastActionText != null) ...[
              const SizedBox(height: 4),
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Text(
                      allIn ? 'ALL IN' : lastActionText!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
            ],
          ],
        ),
      ),
    );
  }
}
