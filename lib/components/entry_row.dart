import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/app_category.dart';
import '../models/transaction_entry.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import 'category_tile.dart';

/// One ledger row. Borderless by design — rows are separated by hairline
/// dividers drawn by the parent list.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    required this.category,
    required this.symbol,
    this.onTap,
    this.onLongPress,
    this.showTime = true,
  });

  final TransactionEntry entry;
  final AppCategory? category;
  final String symbol;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final Color amountColor = entry.isExpense
        ? AppColors.expense(context)
        : AppColors.income(context);

    final String subtitle = <String>[
      if (entry.note.isNotEmpty) entry.note,
      if (showTime) formatTime(entry.occurredAt),
    ].join(' · ');

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: <Widget>[
            if (category != null)
              CategoryTile(category: category!)
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.line(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: AppColors.muted(context),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category?.label ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink(context),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatMoney(
                entry.isExpense ? -entry.amountMinor : entry.amountMinor,
                symbol: symbol,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hairline used between rows and sections.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 20, this.endIndent = 20});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(height: 1, color: AppColors.line(context)),
    );
  }
}
