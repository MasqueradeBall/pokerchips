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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      color: Colors.black.withValues(alpha: 0.35),
      child: Row(
        children: [
          Expanded(
            child: _ActBtn(label: 'Fold', color: const Color(0xFF555555), onTap: canAct ? onFold : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActBtn(label: callLabel, color: AppColors.chipGreen, onTap: canAct ? onCheckOrCall : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActBtn(label: 'Raise', color: const Color(0xFFD35400), onTap: canAct ? onRaise : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActBtn(label: 'ALL IN', color: AppColors.chipRed, onTap: canAct ? onAllIn : null),
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
    return Material(
      color: disabled ? color.withValues(alpha: 0.3) : color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: disabled ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
