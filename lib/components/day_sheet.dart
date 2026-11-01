import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/period_stats.dart';
import '../screens/add_entry_screen.dart';
import 'entry_row.dart';

/// Opens one day's entries.
///
/// Used by the last-7-days chart on Home, by the week breakdown and by the
/// month calendar — one day should look the same however you arrived at it.
Future<void> showDaySheet(BuildContext context, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => DaySheet(day: day),
  );
}

/// The sheet itself: what a day cost, and every entry behind that number.
class DaySheet extends StatelessWidget {
  const DaySheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppState.instance;
    final List<TransactionEntry> entries = entriesOnDay(state.allEntries, day);
    final int spent = entries.fold<int>(
      0,
      (int sum, TransactionEntry e) => sum + (e.isExpense ? e.amountMinor : 0),
    );
    final int earned = entries.fold<int>(
      0,
      (int sum, TransactionEntry e) => sum + (e.isExpense ? 0 : e.amountMinor),
    );

    // A day can hold thirty entries (a mess bill, a trip). The sheet is capped
    // at most of the screen and the list scrolls inside it, instead of growing
    // past the bottom edge.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        formatDayHeading(day),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink(context),
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(spent, symbol: state.currencySymbol),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.expense(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (earned > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${formatMoney(earned, symbol: state.currencySymbol)} came in',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.income(context),
                      ),
                    ),
                  ),
                ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Text(
                    'Nothing logged on this day.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted(context),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TransactionEntry entry = entries[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          EntryRow(
                            entry: entry,
                            category: state.categoryById(entry.categoryId),
                            symbol: state.currencySymbol,
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                slideFadeRoute<void>(
                                  AddEntryScreen(entry: entry),
                                ),
                              );
                            },
                          ),
                          if (index != entries.length - 1)
                            const Hairline(indent: 76),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
