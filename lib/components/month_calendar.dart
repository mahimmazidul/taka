import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/clock.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/responsive.dart';

/// A month grid: seven columns, one cell per day, with the amount spent that day
/// under the number when there is one. Tapping a day opens it.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.spendByDay,
    required this.symbol,
    required this.selectedDay,
    required this.onSelect,
  });

  /// Any moment inside the month to draw.
  final DateTime month;

  /// Day-of-month (1…31) → paisa spent.
  final Map<int, int> spendByDay;
  final String symbol;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final Screen screen = Screen.of(context);
    final DateTime first = startOfMonth(month);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first, and the blank cells before the 1st keep the columns aligned.
    final int leading = (first.weekday - kWeekStartsOnWeekday) % 7;
    final int cells = leading + daysInMonth;
    final int rows = (cells / 7).ceil();
    // AppClock, never DateTime.now(): the ring on "today" is part of the
    // screenshot tests, and a real clock makes those goldens change overnight
    // for no reason at all.
    final DateTime today = startOfDay(AppClock.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _initial(kWeekStartsOnWeekday, i),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: screen.px(6)),
        for (int row = 0; row < rows; row++)
          Row(
            children: <Widget>[
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: _cell(
                    context: context,
                    day: row * 7 + col - leading + 1,
                    daysInMonth: daysInMonth,
                    today: today,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell({
    required BuildContext context,
    required int day,
    required int daysInMonth,
    required DateTime today,
  }) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 46);
    }
    final DateTime date = DateTime(month.year, month.month, day);
    final int spent = spendByDay[day] ?? 0;
    final bool isToday = isSameDay(date, today);
    final bool isSelected =
        selectedDay != null && isSameDay(selectedDay!, date);
    final bool isFuture = date.isAfter(today);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => onSelect(date),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isSelected
                ? Palette.taka.withValues(alpha: 0.14)
                : isToday
                ? AppColors.line(context).withValues(alpha: 0.55)
                : null,
            borderRadius: BorderRadius.circular(10),
            border: isToday && !isSelected
                ? Border.all(color: Palette.taka.withValues(alpha: 0.45))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isFuture
                      ? AppColors.muted(context).withValues(alpha: 0.45)
                      : isSelected
                      ? Palette.taka
                      : AppColors.ink(context),
                ),
              ),
              const SizedBox(height: 2),
              // A dot, not a number: the amount is in the day sheet. Two digits
              // of taka at 9 px would be unreadable and would lie by rounding.
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: spent > 0
                      ? (isSelected ? Palette.taka : AppColors.expense(context))
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(int startWeekday, int offset) {
    final DateTime base = DateTime(2026, 6, 1 + startWeekday - 1 + offset);
    return weekdayShort(base).substring(0, 1);
  }
}

/// A day row: weekday, date, and what it cost. Used by the week list and by the
/// "what did I spend that day" sheet header.
class DayRow extends StatelessWidget {
  const DayRow({
    super.key,
    required this.day,
    required this.expenseMinor,
    required this.symbol,
    this.incomeMinor = 0,
    this.isToday = false,
    this.isFuture = false,
    this.onTap,
  });

  final DateTime day;
  final int expenseMinor;
  final int incomeMinor;
  final String symbol;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool empty = expenseMinor == 0 && incomeMinor == 0;
    final Color ink = isFuture
        ? AppColors.muted(context).withValues(alpha: 0.5)
        : AppColors.ink(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 40,
              child: Text(
                weekdayShort(day),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? Palette.taka : AppColors.muted(context),
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                empty
                    ? (isFuture ? 'still to come' : 'nothing logged')
                    : incomeMinor > 0
                    ? '+ ${formatMoney(incomeMinor, symbol: symbol)} in'
                    : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
              ),
            ),
            Text(
              empty ? '—' : formatMoney(expenseMinor, symbol: symbol),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: empty
                    ? AppColors.muted(context)
                    : AppColors.expense(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted(context)
                  .withValues(alpha: empty ? 0.35 : 1),
            ),
          ],
        ),
      ),
    );
  }
}
