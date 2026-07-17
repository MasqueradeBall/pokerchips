import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/room.dart';
import '../../../providers/game_controllers.dart';

/// チップ枚数を3桁区切りで表示する(例: 10000 → "10,000")。
String _formatChips(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// ロビーに表示する現在のゲーム設定サマリーバー。
/// ホストにはタップ(+編集アイコン)で設定シートを開く入口を兼ねる。
class LobbySettingsBar extends StatelessWidget {
  const LobbySettingsBar({
    super.key,
    required this.room,
    required this.isHost,
    this.onEdit,
  });

  final Room room;
  final bool isHost;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final blindsLabel = room.bigBlind > 0 || room.smallBlind > 0
        ? '${_formatChips(room.smallBlind)} / ${_formatChips(room.bigBlind)}'
        : 'なし';
    final anteLabel = room.ante > 0 ? _formatChips(room.ante) : 'なし';

    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHost
              ? AppColors.gold.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _stat('ブラインド', blindsLabel)),
          _divider(),
          Expanded(child: _stat('アンティ', anteLabel)),
          _divider(),
          Expanded(child: _stat('初期チップ', _formatChips(room.startingStack))),
          if (isHost) ...[
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
              ),
              child: const Icon(Icons.tune_rounded,
                  size: 17, color: AppColors.goldLight),
            ),
          ],
        ],
      ),
    );

    if (!isHost || onEdit == null) return bar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: bar,
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.goldLight,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

/// ホスト専用のゲーム設定ボトムシートを表示する。
/// 保存時に[GameController.updateSettings]を呼び、変更したフィールドだけを渡す。
Future<void> showLobbySettingsSheet(
  BuildContext context, {
  required Room room,
  required GameController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _LobbySettingsSheet(room: room, controller: controller),
  );
}

class _LobbySettingsSheet extends StatefulWidget {
  const _LobbySettingsSheet({required this.room, required this.controller});

  final Room room;
  final GameController controller;

  @override
  State<_LobbySettingsSheet> createState() => _LobbySettingsSheetState();
}

class _LobbySettingsSheetState extends State<_LobbySettingsSheet> {
  late final TextEditingController _sbCtrl;
  late final TextEditingController _bbCtrl;
  late final TextEditingController _anteCtrl;
  late final TextEditingController _stackCtrl;
  late bool _anteEnabled;

  static const _blindPresets = [(25, 50), (50, 100), (100, 200), (500, 1000)];

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _sbCtrl = TextEditingController(text: room.smallBlind.toString());
    _bbCtrl = TextEditingController(text: room.bigBlind.toString());
    _anteCtrl = TextEditingController(
      text: (room.ante > 0 ? room.ante : GameConstants.defaultBigBlind ~/ 2)
          .toString(),
    );
    _stackCtrl = TextEditingController(text: room.startingStack.toString());
    _anteEnabled = room.ante > 0;
  }

  @override
  void dispose() {
    _sbCtrl.dispose();
    _bbCtrl.dispose();
    _anteCtrl.dispose();
    _stackCtrl.dispose();
    super.dispose();
  }

  int? get _sb => int.tryParse(_sbCtrl.text);
  int? get _bb => int.tryParse(_bbCtrl.text);
  int? get _anteInput => int.tryParse(_anteCtrl.text);
  int? get _stack => int.tryParse(_stackCtrl.text);

  /// 保存時に実際に適用されるアンティ(スイッチOFFなら0=無効)。
  int? get _ante => _anteEnabled ? _anteInput : 0;

  bool get _sbValid {
    final v = _sb;
    return v != null && v >= 0 && v <= GameConstants.maxBlindAmount;
  }

  bool get _bbValid {
    final v = _bb;
    final sb = _sb;
    return v != null &&
        v >= 0 &&
        v <= GameConstants.maxBlindAmount &&
        (sb == null || v >= sb);
  }

  bool get _anteValid {
    if (!_anteEnabled) return true;
    final v = _anteInput;
    return v != null && v >= 0 && v <= GameConstants.maxAnteAmount;
  }

  bool get _stackValid {
    final v = _stack;
    return v != null &&
        v >= GameConstants.minStartingStack &&
        v <= GameConstants.maxStartingStack;
  }

  bool get _allValid => _sbValid && _bbValid && _anteValid && _stackValid;

  bool get _stackChanged => _stack != null && _stack != widget.room.startingStack;

  bool get _hasChanges {
    final room = widget.room;
    return _sb != room.smallBlind ||
        _bb != room.bigBlind ||
        _ante != room.ante ||
        _stack != room.startingStack;
  }

  String? get _sbError {
    if (_sbCtrl.text.isEmpty || _sbValid) return null;
    return '0〜${_formatChips(GameConstants.maxBlindAmount)}で入力';
  }

  String? get _bbError {
    if (_bbCtrl.text.isEmpty) return null;
    final v = _bb;
    if (v == null || v < 0 || v > GameConstants.maxBlindAmount) {
      return '0〜${_formatChips(GameConstants.maxBlindAmount)}で入力';
    }
    final sb = _sb;
    if (sb != null && v < sb) return 'SB以上にしてください';
    return null;
  }

  String? get _anteError {
    if (!_anteEnabled || _anteCtrl.text.isEmpty || _anteValid) return null;
    return '0〜${_formatChips(GameConstants.maxAnteAmount)}で入力';
  }

  String? get _stackError {
    if (_stackCtrl.text.isEmpty || _stackValid) return null;
    return '${_formatChips(GameConstants.minStartingStack)}〜'
        '${_formatChips(GameConstants.maxStartingStack)}で入力';
  }

  void _applyBlindPreset(int sb, int bb) {
    setState(() {
      _sbCtrl.text = sb.toString();
      _bbCtrl.text = bb.toString();
    });
  }

  void _save() {
    if (!_allValid) return;
    final room = widget.room;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      widget.controller.updateSettings(
        smallBlind: _sb != room.smallBlind ? _sb : null,
        bigBlind: _bb != room.bigBlind ? _bb : null,
        ante: _ante != room.ante ? _ante : null,
        startingStack: _stack != room.startingStack ? _stack : null,
      );
    } on StateError {
      // ロビー以外では変更不可(通常このシートはロビーでしか開けない)。
      messenger.showSnackBar(
        const SnackBar(content: Text('ゲーム開始後は設定を変更できません')),
      );
      return;
    } on ArgumentError {
      messenger.showSnackBar(
        const SnackBar(content: Text('設定を保存できませんでした。入力値を確認してください')),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('ゲーム設定を保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // グラブハンドル: シートであることを直感的に伝える。
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.12),
                    border:
                        Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.goldLight),
                ),
                const SizedBox(width: 10),
                Text('ゲーム設定', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'ホストのみ',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionLabel('ブラインド'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    controller: _sbCtrl,
                    label: 'スモールブラインド',
                    errorText: _sbError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    controller: _bbCtrl,
                    label: 'ビッグブラインド',
                    errorText: _bbError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (sb, bb) in _blindPresets)
                  _presetChip(
                    '$sb / $bb',
                    selected: _sb == sb && _bb == bb,
                    onPressed: () => _applyBlindPreset(sb, bb),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // アンティ: ほとんどのホームゲームでは使わないためスイッチで折りたたむ。
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('アンティ'),
                      const SizedBox(height: 2),
                      const Text(
                        '全員が毎ハンド開始時に支払う追加の強制ベット',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _anteEnabled,
                  activeThumbColor: AppColors.goldLight,
                  activeTrackColor: AppColors.gold.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _anteEnabled = v),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _anteEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _numberField(
                        controller: _anteCtrl,
                        label: 'アンティ',
                        errorText: _anteError,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 18),
            _sectionLabel('初期チップ枚数'),
            const SizedBox(height: 8),
            _numberField(
              controller: _stackCtrl,
              label: '初期チップ枚数',
              errorText: _stackError,
              maxDigits: 7,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _stackChanged && _stackValid
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 15, color: AppColors.goldLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '保存すると、参加中の全員のチップが'
                              '\$${_formatChips(_stack!)}にリセットされます',
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _allValid && _hasChanges ? _save : null,
              child: Text(
                !_allValid
                    ? '入力内容を確認してください'
                    : _hasChanges
                        ? '設定を保存'
                        : '変更はありません',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? errorText,
    int maxDigits = 6,
  }) {
    return TextField(
      controller: controller,
      // 注意: autofocus:trueはシート表示アニメーションとキーボード出現が重なり
      // クラッシュすることがあるため使わない(raise_bottom_sheet.dart参照)。
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ],
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.goldLight,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixText: '\$',
        errorText: errorText,
        errorStyle: const TextStyle(color: AppColors.chipRed, fontSize: 11),
        errorMaxLines: 2,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  /// ゴールドのアウトラインで統一したプリセットボタン(選択中は塗りつぶし)。
  Widget _presetChip(
    String label, {
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.black : AppColors.goldLight,
        backgroundColor: selected ? AppColors.goldLight : Colors.transparent,
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: selected ? 0.9 : 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
