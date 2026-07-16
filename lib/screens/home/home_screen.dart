import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/game_controllers.dart';
import '../../widgets/felt_background.dart';
import '../play/play_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _secretWordController = TextEditingController();
  int _playerCount = 4;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _joinCodeController.dispose();
    _secretWordController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_creating) return;
    setState(() => _creating = true);
    final controller = ref.read(gameControllerProvider);
    final name = _nameController.text.trim().isEmpty ? 'あなた' : _nameController.text.trim();
    try {
      final hostId = await controller.createRoom(
        hostName: name,
        totalPlayers: _playerCount,
      );
      final secretWord = _secretWordController.text.trim();
      if (secretWord.isNotEmpty) {
        controller.applySecretWord(hostId, secretWord);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlayScreen()),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showOnlineComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('オンライン対戦はSupabase接続後に利用可能になります(現在はデモ/Bot対戦モードです)'),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.casino, color: AppColors.gold, size: 56),
                      const SizedBox(height: 8),
                      Text(
                        'POKER CHIPS',
                        style: textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'カードは実物、チップ計算はアプリで',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _SectionCard(
                  title: 'ルームを作成',
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'プレイヤー名',
                        hintText: 'あなたの名前',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('人数(自分+Bot): $_playerCount人', style: textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var n = 2; n <= 6; n++)
                          ChoiceChip(
                            label: Text('$n'),
                            selected: _playerCount == n,
                            onSelected: (_) => setState(() => _playerCount = n),
                            selectedColor: AppColors.gold,
                            labelStyle: TextStyle(
                              color: _playerCount == n ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: AppColors.surfaceDark,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _secretWordController,
                      decoration: const InputDecoration(
                        labelText: 'あいことば(任意)',
                        hintText: '正しく入力すると広告が非表示になります',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _creating ? null : _createRoom,
                      child: _creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('ルームを作成(Bot対戦デモ)'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('または', style: TextStyle(color: Colors.white54)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionCard(
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
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _showOnlineComingSoon,
                      child: const Text('参加する'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
