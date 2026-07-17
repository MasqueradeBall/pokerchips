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
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _joinCodeController.dispose();
    _secretWordController.dispose();
    super.dispose();
  }

  String get _playerName =>
      _nameController.text.trim().isEmpty ? 'あなた' : _nameController.text.trim();

  Future<void> _run(Future<String> Function(GameController controller) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(gameControllerProvider);
    try {
      final selfId = await action(controller);
      final secretWord = _secretWordController.text.trim();
      if (secretWord.isNotEmpty) {
        controller.applySecretWord(selfId, secretWord);
      }
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
    return _run(
      (controller) => controller.joinRoom(playerName: _playerName, roomCode: code),
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
                  title: 'プレイヤー情報',
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'プレイヤー名',
                        hintText: 'あなたの名前',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _secretWordController,
                      decoration: const InputDecoration(
                        labelText: 'あいことば(任意)',
                        hintText: '正しく入力すると広告が非表示になります',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'ルームを作成',
                  children: [
                    Text(
                      '新しいルームを作り、表示されるルームIDを他のプレイヤーに共有してください。',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : _createRoom,
                      child: _busyIndicatorOr('ルームを作成'),
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
                      onPressed: _busy ? null : _joinRoom,
                      child: _busyIndicatorOr('参加する'),
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

  Widget _busyIndicatorOr(String label) {
    if (!_busy) return Text(label);
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
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
