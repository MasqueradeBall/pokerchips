import 'package:flutter/material.dart';

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
  late double _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.minAmount.toDouble();
  }

  void _setPreset(int value) {
    setState(() {
      _amount = value.clamp(widget.minAmount, widget.maxAmount).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final half = (widget.pot / 2).round();
    final full = widget.pot;
    final sliderEnabled = widget.maxAmount > widget.minAmount;

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
          Text('レイズ額', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(
            '\$${_amount.round()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.goldLight,
            ),
          ),
          Slider(
            value: _amount.clamp(widget.minAmount.toDouble(), widget.maxAmount.toDouble()),
            min: widget.minAmount.toDouble(),
            max: widget.maxAmount.toDouble(),
            activeColor: AppColors.gold,
            onChanged: sliderEnabled ? (v) => setState(() => _amount = v) : null,
          ),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (half > widget.minAmount && half < widget.maxAmount)
                OutlinedButton(onPressed: () => _setPreset(half), child: const Text('1/2 Pot')),
              if (full > widget.minAmount && full < widget.maxAmount)
                OutlinedButton(onPressed: () => _setPreset(full), child: const Text('Pot')),
              OutlinedButton(
                onPressed: () => _setPreset(widget.maxAmount),
                child: const Text('ALL IN相当'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_amount.round()),
            child: const Text('レイズを確定'),
          ),
        ],
      ),
    );
  }
}
