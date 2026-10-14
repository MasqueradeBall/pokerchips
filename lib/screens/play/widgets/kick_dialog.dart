import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/player.dart';
import '../../../providers/game_controllers.dart';
import '../../../widgets/app_dialog.dart';

/// ホストが他プレイヤーをキックする前の確認ダイアログ。
void showKickConfirmDialog(
  BuildContext context, {
  required GameController controller,
  required Player player,
}) {
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

/// ロビー/待機画面のプレイヤー一覧に置く、ホスト用のキックボタン。
class KickIconButton extends StatelessWidget {
  const KickIconButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'キック',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.person_remove_rounded, size: 20, color: AppColors.chipRed),
    );
  }
}
