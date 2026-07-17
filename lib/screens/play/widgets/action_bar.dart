import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.canAct,
    required this.callLabel,
    required this.onFold,
    required this.onCheckOrCall,
    required this.onRaise,
    required this.onAllIn,
  });

  final bool canAct;
  final String callLabel;
  final VoidCallback? onFold;
  final VoidCallback? onCheckOrCall;
  final VoidCallback? onRaise;
  final VoidCallback? onAllIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.55),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: canAct
                ? AppColors.gold.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 自分の番のときだけ表示するインジケータ。手番の変化をひと目で伝える。
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: canAct
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'YOUR TURN',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Row(
            children: [
              Expanded(
                child: _ActBtn(
                  label: 'Fold',
                  color: const Color(0xFF555555),
                  onTap: canAct ? onFold : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActBtn(
                  label: callLabel,
                  color: AppColors.chipGreen,
                  onTap: canAct ? onCheckOrCall : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActBtn(
                  label: 'Raise',
                  color: const Color(0xFFD35400),
                  onTap: canAct ? onRaise : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActBtn(
                  label: 'ALL IN',
                  color: AppColors.chipRed,
                  onTap: canAct ? onAllIn : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  const _ActBtn({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: disabled
              ? [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.12),
                ]
              : [
                  AppColors.lighten(color, 0.12),
                  AppColors.darken(color, 0.18),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: disabled ? 0.05 : 0.2),
        ),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: disabled ? Colors.white24 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.4,
                  shadows: disabled
                      ? null
                      : const [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
