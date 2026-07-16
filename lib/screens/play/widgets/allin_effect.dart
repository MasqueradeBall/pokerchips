import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// [trigger] の値が変化するたびに全画面のオールイン演出を再生する。
class AllInEffect extends StatefulWidget {
  const AllInEffect({super.key, required this.trigger, required this.playerName});

  final Object? trigger;
  final String playerName;

  @override
  State<AllInEffect> createState() => _AllInEffectState();
}

class _AllInEffectState extends State<AllInEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void didUpdateWidget(covariant AllInEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && widget.trigger != null) {
      _play();
    }
  }

  void _play() {
    setState(() => _visible = true);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final opacity = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85).clamp(0.0, 1.0);
          final scale = 0.8 + t * 0.4;
          return Opacity(
            opacity: opacity,
            child: Container(
              color: AppColors.chipRed.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  'ALL IN!\n${widget.playerName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                    shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
