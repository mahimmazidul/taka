import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/budget_progress.dart';
import '../utils/format_currency.dart';

/// A budget as a 4 px track plus two lines of text. Deliberately not a card:
/// the dashboard already has one hero, everything else stays open.
class BudgetLine extends StatelessWidget {
  const BudgetLine({
    super.key,
    required this.progress,
    required this.symbol,
    this.onTap,
  });

  final BudgetProgress progress;
  final String symbol;
  final VoidCallback? onTap;

  Color get _color => switch (progress.status) {
    BudgetStatus.ok => progress.category.color,
    BudgetStatus.warning => Palette.warning,
    BudgetStatus.exceeded => Palette.expense,
  };

  @override
  Widget build(BuildContext context) {
    final Color color = _color;
    final int percent = (progress.ratio * 100).round();
    final String detail = progress.status == BudgetStatus.exceeded
        ? '${formatMoney(progress.spentMinor, symbol: symbol)} of '
              '${formatMoney(progress.budgetMinor, symbol: symbol)} · '
              'over by ${formatMoney(progress.spentMinor - progress.budgetMinor, symbol: symbol)}'
        : '${formatMoney(progress.spentMinor, symbol: symbol)} of '
              '${formatMoney(progress.budgetMinor, symbol: symbol)}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(progress.category.iconData, size: 15, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    progress.category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink(context),
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clampedRatio),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: AppColors.line(context),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: progress.status == BudgetStatus.ok
                    ? AppColors.muted(context)
                    : color,
                fontWeight: progress.status == BudgetStatus.ok
                    ? FontWeight.w400
                    : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
