import 'package:flutter/material.dart';

import '../core/theme.dart';

/// ゴールドの縁取り + ふわっとしたスケールインで表示する共通ダイアログ。
/// AlertDialogの代わりに使い、アプリ全体のダイアログの見た目を統一する。
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, anim1, anim2) => builder(dialogContext),
    transitionBuilder: (dialogContext, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// アイコン + タイトル + 本文 + アクション行で構成する共通ダイアログパネル。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.content,
    required this.actions,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.goldLight;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceCard, AppColors.surfaceDark],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (content != null) ...[
              const SizedBox(height: 10),
              DefaultTextStyle(
                style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.6),
                textAlign: TextAlign.center,
                child: content!,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 破壊的アクション(退出/キック)用の赤い塗りボタン。
class AppDialogDangerButton extends StatelessWidget {
  const AppDialogDangerButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.chipRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// キャンセル用の控えめなアウトラインボタン。
class AppDialogCancelButton extends StatelessWidget {
  const AppDialogCancelButton({super.key, this.label = 'キャンセル', required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
