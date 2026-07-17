import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// [message] が更新されるたびに一定時間表示してから自動的にフェードアウトする。
class SystemMessageOverlay extends StatefulWidget {
  const SystemMessageOverlay({super.key, required this.message});

  final String? message;

  @override
  State<SystemMessageOverlay> createState() => _SystemMessageOverlayState();
}

class _SystemMessageOverlayState extends State<SystemMessageOverlay> {
  Timer? _hideTimer;
  String? _visibleMessage;

  @override
  void initState() {
    super.initState();
    _showIfNeeded(widget.message);
  }

  @override
  void didUpdateWidget(covariant SystemMessageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _showIfNeeded(widget.message);
    }
  }

  void _showIfNeeded(String? message) {
    _hideTimer?.cancel();
    setState(() => _visibleMessage = message);
    if (message == null) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visibleMessage = null);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _visibleMessage;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        // 上からふわっと降りてくる + わずかに拡大しながら現れる。
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              child: child,
            ),
          ),
        ),
        child: message == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : Align(
                key: ValueKey(message),
                alignment: const Alignment(0, -0.42),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.goldLight),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16),
                    ],
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
