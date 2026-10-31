import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';

/// Three open figures under the hero: today, this week, this month.
/// No cards — just numbers, labels and hairline separators.
class StatStrip extends StatelessWidget {
  const StatStrip({
    super.key,
    required this.todayMinor,
    required this.weekMinor,
    required this.monthMinor,
    required this.symbol,
  });

  final int todayMinor;
  final int weekMinor;
  final int monthMinor;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Today leads and is tinted: the daily number is the one that resets
          // at midnight and the one a student actually checks.
          _Stat(
            label: 'Spent today',
            value: todayMinor,
            symbol: symbol,
            accent: true,
          ),
          _Divider(),
          _Stat(label: 'This week', value: weekMinor, symbol: symbol),
          _Divider(),
          _Stat(label: 'This month', value: monthMinor, symbol: symbol),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.line(context),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.symbol,
    this.accent = false,
  });

  final String label;
  final int value;
  final String symbol;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.muted(context)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedMoney(
              value,
              symbol: symbol,
              style: TextStyle(
                fontSize: accent ? 17 : 15,
                fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.3,
                color: accent ? Palette.taka : AppColors.ink(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
