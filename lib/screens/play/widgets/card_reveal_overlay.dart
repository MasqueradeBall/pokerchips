import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// コミュニティカードをめくるタイミングで画面全体を暗くして大きく案内する。
/// [message]が新しい値に変わるたびに表示し、タップされるまでローカルに表示し続ける
/// (他プレイヤーの画面には影響しない、各自の確認操作)。
class CardRevealOverlay extends StatefulWidget {
  const CardRevealOverlay({super.key, required this.message});

  final String? message;

  @override
  State<CardRevealOverlay> createState() => _CardRevealOverlayState();
}

class _CardRevealOverlayState extends State<CardRevealOverlay> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(covariant CardRevealOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      setState(() => _dismissed = widget.message == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final show = message != null && !_dismissed;

    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _dismissed = true),
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: message == null
                ? null
                : AnimatedScale(
                    scale: show ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.style, color: AppColors.goldLight, size: 48),
                        const SizedBox(height: 12),
                        const Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '♠  ', style: TextStyle(color: Colors.white70)),
                            TextSpan(text: '♥  ', style: TextStyle(color: AppColors.chipRed)),
                            TextSpan(text: '♦  ', style: TextStyle(color: AppColors.chipRed)),
                            TextSpan(text: '♣', style: TextStyle(color: Colors.white70)),
                          ]),
                          style: TextStyle(fontSize: 14, height: 1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: AppColors.gold, blurRadius: 24)],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'タップして閉じる',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
