import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/game_controllers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/felt_background.dart';
import '../play/play_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  bool _busy = false;

  // 起動時に各セクションを順番にフェード+スライドインさせる。
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _nameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  String get _playerName =>
      _nameController.text.trim().isEmpty ? 'あなた' : _nameController.text.trim();

  Future<void> _run(Future<String> Function(GameController controller) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(gameControllerProvider);
    try {
      await action(controller);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlayScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRoom() {
    ref.read(demoModeProvider.notifier).state = false;
    return _run((controller) => controller.createRoom(hostName: _playerName));
  }

  Future<void> _joinRoom() {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームIDを入力してください')),
      );
      return Future.value();
    }
    ref.read(demoModeProvider.notifier).state = false;
    return _run(
      (controller) => controller.joinRoom(playerName: _playerName, roomCode: code),
    );
  }

  /// Botと1人で対戦できるオフラインデモを開始する。
  Future<void> _startDemo() {
    ref.read(demoModeProvider.notifier).state = true;
    return _run((controller) => controller.createRoom(hostName: _playerName));
  }

  /// [start]〜[start+0.45]の区間でフェード+スライドインさせるラッパー。
  Widget _reveal(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _reveal(0.0, _buildHero(textTheme)),
                const SizedBox(height: 24),
                _reveal(0.15, _SectionCard(
                  title: 'プレイヤー情報',
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'プレイヤー名',
                        hintText: 'あなたの名前',
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 14),
                _reveal(0.3, _SectionCard(
                  title: 'ルームを作成',
                  children: [
                    Text(
                      '新しいルームを作り、ルームIDを共有してください。',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _busy ? null : _createRoom,
                      child: _busyIndicatorOr('ルームを作成', dark: true),
                    ),
                  ],
                )),
                const SizedBox(height: 14),
                _reveal(0.42, Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'または',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                )),
                const SizedBox(height: 14),
                _reveal(0.5, _SectionCard(
                  title: 'ルームに参加',
                  children: [
                    TextField(
                      controller: _joinCodeController,
                      decoration: const InputDecoration(
                        labelText: 'ルームID',
                        hintText: '例: 12345',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : _joinRoom,
                      child: _busyIndicatorOr('参加する', dark: false),
                    ),
                  ],
                )),
                const SizedBox(height: 12),
                _reveal(0.62, Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _startDemo,
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: const Text('Botと1人で試す(デモ)'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(TextTheme textTheme) {
    return Column(
      children: [
        // ゴールドリングに収めたエンブレム。
        Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.22),
                AppColors.gold.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.25),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(Icons.casino, color: AppColors.goldLight, size: 34),
        ),
        const SizedBox(height: 12),
        // ゴールドグラデーションのワードマーク。
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.goldLight, AppColors.gold],
            stops: [0.0, 0.55, 1.0],
          ).createShader(bounds),
          child: Text(
            'POKER CHIPS',
            style: textTheme.displaySmall?.copyWith(
              color: Colors.white,
              letterSpacing: 3,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // スートの飾り罫。
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ornamentLine(reversed: false),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '♠ ', style: TextStyle(color: Colors.white70)),
                  TextSpan(text: '♥ ', style: TextStyle(color: AppColors.chipRed)),
                  TextSpan(text: '♦ ', style: TextStyle(color: AppColors.chipRed)),
                  TextSpan(text: '♣', style: TextStyle(color: Colors.white70)),
                ]),
                style: TextStyle(fontSize: 13, height: 1),
              ),
            ),
            _ornamentLine(reversed: true),
          ],
        ),
        const SizedBox(height: 8),
        Text('カードは実物、チップ計算はアプリで', style: textTheme.bodySmall),
      ],
    );
  }

  Widget _ornamentLine({required bool reversed}) {
    return Container(
      width: 48,
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

  Widget _busyIndicatorOr(String label, {required bool dark}) {
    if (!_busy) return Text(label);
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: dark ? Colors.black : Colors.white70,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceCard,
            AppColors.darken(AppColors.surfaceCard, 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
