import 'package:flutter/material.dart';

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
import 'add_entry_screen.dart';

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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _DaySheet(day: day),
    );
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

/// One day, opened. The same rows as History, because a day is a day.
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day});

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
    // past the bottom edge and overflowing.
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
