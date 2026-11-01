import 'package:flutter/material.dart';

import '../components/day_sheet.dart';
import '../components/entry_row.dart';
import '../components/month_calendar.dart';
import '../components/section_title.dart';
import '../components/segmented.dart';
import '../core/app_theme.dart';
import '../core/clock.dart';
import '../core/motion.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/period_stats.dart';
import '../utils/responsive.dart';

/// Where the money went, one period at a time.
///
/// Week answers "which day was the expensive one", month answers "how is this
/// month going against the ones before it" with a calendar to open any day, and
/// year is the long view. Every level drills down to the same thing: a list of
/// entries for a day.
class PeriodScreen extends StatefulWidget {
  const PeriodScreen({super.key, required this.mode, this.anchor});

  final PeriodMode mode;
  final DateTime? anchor;

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

/// Which slice is on screen.
enum PeriodMode { week, month, year }

class _PeriodScreenState extends State<PeriodScreen> {
  late PeriodMode _mode;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _anchor = widget.anchor ?? AppClock.now();
  }

  void _shift(int delta) {
    setState(() {
      _anchor = switch (_mode) {
        PeriodMode.week => _anchor.add(Duration(days: 7 * delta)),
        PeriodMode.month => DateTime(_anchor.year, _anchor.month + delta),
        PeriodMode.year => DateTime(_anchor.year + delta),
      };
    });
  }

  String get _title => switch (_mode) {
    PeriodMode.week => _weekLabel(_anchor),
    PeriodMode.month => formatMonthYear(_anchor),
    PeriodMode.year => '${_anchor.year}',
  };

  static String _weekLabel(DateTime anchor) {
    final DateTime start = startOfWeek(anchor);
    final DateTime end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${monthShort(start.month)}';
    }
    return '${start.day} ${monthShort(start.month)} – ${end.day} ${monthShort(end.month)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Where it went')),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (BuildContext context, Widget? _) {
          final AppState state = AppState.instance;
          final Screen screen = Screen.of(context);
          return SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screen.px(20),
                    screen.px(6),
                    screen.px(20),
                    0,
                  ),
                  child: Segmented<PeriodMode>(
                    value: _mode,
                    onChanged: (PeriodMode mode) =>
                        setState(() => _mode = mode),
                    options: const <SegmentOption<PeriodMode>>[
                      SegmentOption<PeriodMode>(
                        value: PeriodMode.week,
                        label: 'Week',
                      ),
                      SegmentOption<PeriodMode>(
                        value: PeriodMode.month,
                        label: 'Month',
                      ),
                      SegmentOption<PeriodMode>(
                        value: PeriodMode.year,
                        label: 'Year',
                      ),
                    ],
                  ),
                ),
                _PeriodHeader(
                  title: _title,
                  totalMinor: _totalMinor(state),
                  symbol: state.currencySymbol,
                  onPrevious: () => _shift(-1),
                  onNext: _isCurrent ? null : () => _shift(1),
                ),
                Expanded(
                  child: switch (_mode) {
                    PeriodMode.week => _WeekBody(
                      anchor: _anchor,
                      state: state,
                      onOpenDay: _openDay,
                    ),
                    PeriodMode.month => _MonthBody(
                      anchor: _anchor,
                      state: state,
                      onOpenDay: _openDay,
                      onOpenMonth: (DateTime month) => setState(() {
                        _anchor = month;
                      }),
                    ),
                    PeriodMode.year => _YearBody(
                      anchor: _anchor,
                      state: state,
                      onOpenMonth: (DateTime month) => setState(() {
                        _anchor = month;
                        _mode = PeriodMode.month;
                      }),
                    ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _isCurrent {
    final DateTime now = AppClock.now();
    return switch (_mode) {
      PeriodMode.week => startOfWeek(_anchor) == startOfWeek(now),
      PeriodMode.month => startOfMonth(_anchor) == startOfMonth(now),
      PeriodMode.year => _anchor.year == now.year,
    };
  }

  int _totalMinor(AppState state) {
    final DateTime now = AppClock.now();
    final (DateTime from, DateTime to) = switch (_mode) {
      PeriodMode.week => (
        startOfWeek(_anchor),
        startOfWeek(_anchor).add(const Duration(days: 7)),
      ),
      PeriodMode.month => (
        startOfMonth(_anchor),
        startOfNextMonth(_anchor).isAfter(now)
            ? startOfNextDay(now)
            : startOfNextMonth(_anchor),
      ),
      PeriodMode.year => (
        DateTime(_anchor.year),
        DateTime(_anchor.year + 1).isAfter(now)
            ? startOfNextDay(now)
            : DateTime(_anchor.year + 1),
      ),
    };
    int total = 0;
    for (final TransactionEntry entry in state.allEntries) {
      if (!entry.isExpense) continue;
      if (entry.occurredAt.isBefore(from) || !entry.occurredAt.isBefore(to)) {
        continue;
      }
      total += entry.amountMinor;
    }
    return total;
  }

  Future<void> _openDay(DateTime day) async {
    if (day.isAfter(startOfNextDay(AppClock.now()))) return;
    await showDaySheet(context, day);
  }
}

/// Back/forward arrows, the period name and its total.
class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.title,
    required this.totalMinor,
    required this.symbol,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final int totalMinor;
  final String symbol;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final Screen screen = Screen.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        screen.px(12),
        screen.px(14),
        screen.px(12),
        0,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.muted(context),
            tooltip: 'Earlier',
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted(context),
                  ),
                ),
                Text(
                  formatMoney(totalMinor, symbol: symbol),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.ink(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.muted(context),
            tooltip: 'Later',
          ),
        ],
      ),
    );
  }
}

class _WeekBody extends StatelessWidget {
  const _WeekBody({
    required this.anchor,
    required this.state,
    required this.onOpenDay,
  });

  final DateTime anchor;
  final AppState state;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final DateTime start = startOfWeek(anchor);
    final List<DayTotal> days = dailyTotals(
      state.allEntries,
      from: start,
      toExclusive: start.add(const Duration(days: 7)),
    );
    final DateTime today = startOfDay(AppClock.now());

    return ListView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 24,
        left: Screen.of(context).gutter,
        right: Screen.of(context).gutter,
      ),
      children: <Widget>[
        for (int i = 0; i < days.length; i++) ...<Widget>[
          DayRow(
            day: days[i].day,
            expenseMinor: days[i].expenseMinor,
            incomeMinor: days[i].incomeMinor,
            symbol: state.currencySymbol,
            isToday: isSameDay(days[i].day, today),
            isFuture: days[i].day.isAfter(today),
            onTap: () => onOpenDay(days[i].day),
          ),
          if (i != days.length - 1) const Hairline(indent: 20),
        ],
      ],
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.anchor,
    required this.state,
    required this.onOpenDay,
    required this.onOpenMonth,
  });

  final DateTime anchor;
  final AppState state;
  final ValueChanged<DateTime> onOpenDay;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final DateTime month = startOfMonth(anchor);
    final List<DayTotal> days = dailyTotals(
      state.allEntries,
      from: month,
      toExclusive: startOfNextMonth(month),
    );
    final Map<int, int> spendByDay = <int, int>{
      for (final DayTotal day in days) day.day.day: day.expenseMinor,
    };
    final List<MonthTotal> months = monthlyTotals(
      state.allEntries,
      from: firstMonthOf(state.allEntries, month),
      to: month,
    ).reversed.toList(growable: false);

    final double gutter = Screen.of(context).gutter;
    return ListView(
      padding: EdgeInsets.only(top: 6, bottom: 24, left: gutter, right: gutter),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MonthCalendar(
            month: month,
            spendByDay: spendByDay,
            symbol: state.currencySymbol,
            selectedDay: null,
            onSelect: onOpenDay,
          ),
        ),
        if (state.carryIntoMonth(month) != 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.savings_outlined,
                  size: 15,
                  color: AppColors.muted(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatMoney(state.carryIntoMonth(month), symbol: state.currencySymbol)} '
                    '${previousMonthLabel(month).replaceFirst('carried from', 'carried in from')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        const SectionTitle(title: 'Months'),
        for (final MonthTotal entry in months) ...<Widget>[
          _MonthRow(
            entry: entry,
            symbol: state.currencySymbol,
            selected: entry.month == month,
            onTap: () => onOpenMonth(entry.month),
          ),
          const Hairline(indent: 20),
        ],
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.entry,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  final MonthTotal entry;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${monthName(entry.month.month)} ${entry.month.year}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Palette.taka : AppColors.ink(context),
                    ),
                  ),
                  Text(
                    entry.days == 1
                        ? '1 day logged'
                        : '${entry.days} days logged',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(entry.expenseMinor, symbol: symbol),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: selected ? Palette.taka : AppColors.ink(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearBody extends StatelessWidget {
  const _YearBody({
    required this.anchor,
    required this.state,
    required this.onOpenMonth,
  });

  final DateTime anchor;
  final AppState state;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final int year = anchor.year;
    final List<MonthTotal> months = monthlyTotals(
      state.allEntries,
      from: DateTime(year),
      to: DateTime(year, 12),
    );
    final List<int> years = yearsCovered(state.allEntries, AppClock.now());
    final int spent = months.fold<int>(
      0,
      (int sum, MonthTotal m) => sum + m.expenseMinor,
    );
    final int earned = months.fold<int>(
      0,
      (int sum, MonthTotal m) => sum + m.incomeMinor,
    );

    return ListView(
      padding: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: Screen.of(context).gutter,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: <Widget>[
              _Figure(
                label: 'Spent',
                value: formatMoney(spent, symbol: state.currencySymbol),
                color: AppColors.expense(context),
              ),
              const SizedBox(width: 24),
              _Figure(
                label: 'Came in',
                value: formatMoney(earned, symbol: state.currencySymbol),
                color: AppColors.income(context),
              ),
            ],
          ),
        ),
        const Hairline(indent: 20),
        for (final MonthTotal entry in months) ...<Widget>[
          _MonthRow(
            entry: entry,
            symbol: state.currencySymbol,
            selected:
                entry.month.month == AppClock.now().month &&
                year == AppClock.now().year,
            onTap: () => onOpenMonth(entry.month),
          ),
          const Hairline(indent: 20),
        ],
        if (years.length > 1) ...<Widget>[
          const SectionTitle(title: 'Years'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              years.map((int y) => '$y').join('  ·  '),
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.muted(context)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
