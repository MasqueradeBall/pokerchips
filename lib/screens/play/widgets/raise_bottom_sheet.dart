import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

/// レイズ額を選ぶボトムシートを表示し、確定額(nullならキャンセル)を返す。
Future<int?> showRaiseSheet(
  BuildContext context, {
  required int pot,
  required int highestBet,
  required int myCurrentBet,
  required int myChips,
}) {
  final minAmount = (highestBet - myCurrentBet + 1).clamp(1, myChips);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _RaiseSheet(pot: pot, minAmount: minAmount, maxAmount: myChips),
  );
}

class _RaiseSheet extends StatefulWidget {
  const _RaiseSheet({required this.pot, required this.minAmount, required this.maxAmount});

  final int pot;
  final int minAmount;
  final int maxAmount;

  @override
  State<_RaiseSheet> createState() => _RaiseSheetState();
}

class _RaiseSheetState extends State<_RaiseSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.minAmount.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_controller.text);

  bool get _isValid {
    final amount = _amount;
    return amount != null && amount >= widget.minAmount && amount <= widget.maxAmount;
  }

  void _setPreset(int value) {
    final clamped = value.clamp(widget.minAmount, widget.maxAmount);
    setState(() {
      _controller.text = clamped.toString();
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final half = (widget.pot / 2).round();
    final full = widget.pot;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
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
              Text('レイズ額', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'POT \$${widget.pot}',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            // 注意: ここでautofocus:trueにすると、ボトムシートの表示アニメーションと
            // キーボード出現(MediaQuery変更)が同時に走り、
            // 「_dependents.isEmpty」assertionでクラッシュすることがあるため使わない。
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.goldLight,
            ),
            decoration: InputDecoration(
              prefixText: '\$',
              helperText: '最小 \$${widget.minAmount} 〜 最大 \$${widget.maxAmount}',
              errorText: _controller.text.isEmpty || _isValid ? null : '範囲外の金額です',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (half > widget.minAmount && half < widget.maxAmount)
                _presetChip('1/2 Pot', () => _setPreset(half)),
              if (full > widget.minAmount && full < widget.maxAmount)
                _presetChip('Pot', () => _setPreset(full)),
              _presetChip('ALL IN相当', () => _setPreset(widget.maxAmount)),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _isValid ? () => Navigator.of(context).pop(_amount) : null,
            child: Text(_isValid ? '\$$_amount にレイズ' : 'レイズを確定'),
          ),
        ],
      ),
    );
  }

  /// ゴールドのアウトラインで統一したプリセット金額ボタン。
  Widget _presetChip(String label, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.goldLight,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
