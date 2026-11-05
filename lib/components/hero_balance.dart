import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';
import '../utils/format_currency.dart';

/// The one big surface in the app: the money you actually have, with this
/// month's in and out beside it.
///
/// The big number is **not** "income minus spending this month" — that would
/// read as a loss on the 1st of every month even though the leftover from last
/// month is still in the pocket. It is last month's remainder, plus what came
/// in, minus what went out, and the caption says how much of it is carried.
class HeroBalance extends StatelessWidget {
  const HeroBalance({
    super.key,
    required this.balanceMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.monthLabel,
    required this.symbol,
    this.carriedMinor = 0,
    this.carriedLabel,
    this.pocketNote,
  });

  final int balanceMinor;
  final int incomeMinor;
  final int expenseMinor;
  final String monthLabel;
  final String symbol;

  /// What rolled in from the months before this one. Zero when there is none,
  /// and then the caption is not drawn at all.
  final int carriedMinor;

  /// "carried from October", when it applies.
  final String? carriedLabel;

  /// "−৳ 1,500 lent out · +৳ 500 borrowed · ৳ 200 set aside". The big number
  /// already includes both; this says so rather than leaving it a mystery.
  final String? pocketNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF14A98B), Palette.takaDeep],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Palette.taka.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              monthLabel.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedMoney(
                balanceMinor,
                symbol: symbol,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            if (carriedMinor != 0 && carriedLabel != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '${carriedMinor > 0 ? '+' : ''}'
                '${formatMoney(carriedMinor, symbol: symbol)} '
                '${carriedLabel!}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
            ],
            if (pocketNote != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                pocketNote!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _MiniStat(
                  icon: Icons.south_west_rounded,
                  label: 'In',
                  value: incomeMinor,
                  symbol: symbol,
                ),
                Container(
                  width: 1,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                _MiniStat(
                  icon: Icons.north_east_rounded,
                  label: 'Out',
                  value: expenseMinor,
                  symbol: symbol,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.symbol,
  });

  final IconData icon;
  final String label;
  final int value;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.78)),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(value, symbol: symbol),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
