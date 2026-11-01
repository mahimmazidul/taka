import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../components/day_sheet.dart';
import '../components/empty_state.dart';
import '../components/entry_row.dart';
import '../components/hero_balance.dart';
import '../components/section_title.dart';
import '../components/stat_strip.dart';
import '../components/week_bars.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/meal_slot.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../store/settings_actions.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/insights.dart';
import 'add_entry_screen.dart';
import 'insights_screen.dart';
import 'period_screen.dart';

/// Dashboard. One hero, then open sections separated by hairlines — no stacks
/// of rounded boxes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenUdhar,
    required this.onOpenHistory,
  });

  final VoidCallback onOpenUdhar;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (BuildContext context, Widget? _) {
        final AppState state = AppState.instance;
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.4),
          );
        }

        final String symbol = state.currencySymbol;
        final DateTime now = state.now;

        // Two groups of sections. Portrait stacks them into one list; landscape
        // puts money on the left and the rest on the right, the way a page
        // reflows — the screen is short, so a single column hides everything.
        final List<Widget> money = <Widget>[
          _Header(
            monthLabel: formatMonthYear(now),
            isDark: state.settings.darkMode,
          ),
          const SizedBox(height: 14),
          Reveal(
            child: HeroBalance(
              // The money you have, not the month's net: leftover from the
              // previous month is spendable today, so it belongs in this number.
              balanceMinor: state.moneyOnHand,
              incomeMinor: state.month.incomeMinor,
              expenseMinor: state.month.expenseMinor,
              monthLabel: 'Money on hand · ${monthName(now.month)}',
              symbol: symbol,
              carriedMinor: state.carryIntoMonth(now),
              carriedLabel: previousMonthLabel(now),
              udharNote: _udharNote(state),
            ),
          ),
          Reveal(
            index: 1,
            child: StatStrip(
              todayMinor: state.today.expenseMinor,
              weekMinor: state.week.expenseMinor,
              monthMinor: state.month.expenseMinor,
              symbol: symbol,
              onTapToday: () => _openPeriod(context, PeriodMode.week),
              onTapWeek: () => _openPeriod(context, PeriodMode.week),
              onTapMonth: () => _openPeriod(context, PeriodMode.month),
            ),
          ),
          Reveal(index: 1, child: _Nudge(state: state)),
        ];

        final List<Widget> detail = <Widget>[
          if (state.today.expenseMinor > 0) ...<Widget>[
            const SectionTitle(title: 'Today\'s meals'),
            _MealsStrip(spend: state.mealSpendToday, symbol: symbol),
          ],
          SectionTitle(
            title: 'Last 7 days',
            actionLabel: 'History',
            onAction: onOpenHistory,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Reveal(
              index: 2,
              child: WeekBars(
                days: state.lastSevenDays,
                onTapDay: (DateTime day) => showDaySheet(context, day),
              ),
            ),
          ),
          SectionTitle(
            title: 'Patterns',
            actionLabel: 'Open',
            onAction: () =>
                Navigator.of(context)
                    .push(slideFadeRoute<void>(const InsightsScreen())),
          ),
          _PatternsTeaser(state: state),
          if (state.settings.udharEnabled) ...<Widget>[
            SectionTitle(
              title: 'Udhar',
              actionLabel: 'Open',
              onAction: onOpenUdhar,
            ),
            _UdharRow(
              lentMinor: state.udharTotals.lentMinor,
              borrowedMinor: state.udharTotals.borrowedMinor,
              symbol: symbol,
              onTap: onOpenUdhar,
            ),
          ],
          SectionTitle(
            title: 'Recent',
            actionLabel: state.recentEntries.isEmpty ? null : 'See all',
            onAction: onOpenHistory,
          ),
          _RecentBlock(
            entries: state.recentEntries,
            symbol: symbol,
            onOpenHistory: onOpenHistory,
          ),
        ];

        final Screen screen = Screen.of(context);
        final double gutter = screen.gutter;

        Widget column(List<Widget> sections, {double? side}) => ListView(
          padding: EdgeInsets.fromLTRB(side ?? gutter, 0, side ?? gutter, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: sections,
        );

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: state.refresh,
            color: Palette.taka,
            child: screen.useTwoPanes
                ? Center(
                    child: ConstrainedBox(
                      // Two columns, each with a sane measure — the 620 px
                      // single-column cap would squeeze them into slivers.
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: column(money, side: screen.px(18))),
                          Expanded(
                            child: column(<Widget>[
                              SizedBox(height: screen.px(10)),
                              ...detail,
                            ], side: screen.px(18)),
                          ),
                        ],
                      ),
                    ),
                  )
                : column(<Widget>[...money, ...detail]),
          ),
        );
      },
    );
  }
}

void _openPeriod(BuildContext context, PeriodMode mode) {
  Navigator.of(context).push(slideFadeRoute<void>(PeriodScreen(mode: mode)));
}

class _Header extends StatelessWidget {
  const _Header({required this.monthLabel, required this.isDark});

  final String monthLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'টাকা',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.ink(context),
                  ),
                ),
                Text(
                  monthLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
          Pressable(
            onTap: () => AppState.instance.toggleDarkMode(),
            scale: 0.9,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line(context)),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 19,
                color: AppColors.muted(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Breakfast / lunch / dinner for today: a check and the amount, or a dash if
/// nothing was logged. Tapping it opens a new entry for that meal's group.
class _MealsStrip extends StatelessWidget {
  const _MealsStrip({required this.spend, required this.symbol});

  final Map<MealSlot, int> spend;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: <Widget>[
          for (final MealSlot slot in MealSlot.values) ...<Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    slot.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Icon(
                        (spend[slot] ?? 0) > 0
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline,
                        size: 13,
                        color: (spend[slot] ?? 0) > 0
                            ? Palette.taka
                            : AppColors.muted(context),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          (spend[slot] ?? 0) > 0
                              ? formatMoney(spend[slot]!, symbol: symbol)
                              : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (slot != MealSlot.values.last)
              Container(
                width: 1,
                height: 26,
                margin: const EdgeInsets.only(right: 14),
                color: AppColors.line(context),
              ),
          ],
        ],
      ),
    );
  }
}

/// "−৳ 1,500 lent out · +৳ 500 borrowed", or null when nothing is open.
String? _udharNote(AppState state) {
  final List<String> parts = <String>[
    if (state.udharTotals.lentMinor > 0)
      '−${formatMoney(state.udharTotals.lentMinor, symbol: state.currencySymbol)} lent out',
    if (state.udharTotals.borrowedMinor > 0)
      '+${formatMoney(state.udharTotals.borrowedMinor, symbol: state.currencySymbol)} borrowed',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Two figures from Patterns, so the section is worth having on Home without
/// being a dashboard. Tapping anywhere in it opens the full screen.
class _PatternsTeaser extends StatelessWidget {
  const _PatternsTeaser({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final DateTime now = state.now;
    final List<CategorySpend> top = topSpending(
      state.allEntries,
      state.categories,
      from: startOfMonth(now),
      toExclusive: startOfNextMonth(now),
    );
    final List<MealGap> gaps = missedMeals(
      state.allEntries,
      state.categories,
      from: startOfMonth(now),
      toExclusive: startOfNextMonth(now),
      now: now,
    );

    final bool anyMealTagged = gaps.any((MealGap gap) => gap.loggedDays > 0);
    final MealGap? worst = anyMealTagged
        ? (gaps.toList()..sort(
                (MealGap a, MealGap b) => b.missedDays.compareTo(a.missedDays),
              ))
              .first
        : null;
    final MonthRhythm rhythm = monthRhythm(
      state.allEntries,
      from: startOfMonth(now),
      toExclusive: startOfNextMonth(now),
      now: now,
    );

    final String mostTitle = top.isEmpty
        ? 'Nothing spent yet'
        : 'Most on ${top.first.category.label}';
    final String mostAmount = top.isEmpty
        ? 'this month'
        : formatMoney(top.first.amountMinor, symbol: state.currencySymbol);

    // The right-hand figure is only about meals when meals are actually being
    // tagged; otherwise it would accuse the user of missing breakfast 30 times
    // in a month when they never tagged a meal at all.
    final String second = worst == null
        ? '${rhythm.noSpendDays} '
              '${rhythm.noSpendDays == 1 ? 'no-spend day' : 'no-spend days'}'
        : '${worst.slot.label} unlogged ${worst.missedDays} '
              '${worst.missedDays == 1 ? 'day' : 'days'}';

    return Pressable(
      onTap: () =>
          Navigator.of(context)
              .push(slideFadeRoute<void>(const InsightsScreen())),
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    mostTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink(context),
                    ),
                  ),
                  Text(
                    mostAmount,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Flexible, not bare: a long meal name at a big text scale has to
            // wrap inside its half instead of pushing the row off the screen.
            Flexible(
              child: Text(
                second,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line, no charts: what this week has cost, and what is left to spend per
/// remaining day — counting last month's leftovers, because a month does not
/// reset the money in your pocket, only the calendar.
class _Nudge extends StatelessWidget {
  const _Nudge({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final DateTime now = state.now;
    final String symbol = state.currencySymbol;
    final String spentWeek = formatMoney(
      state.week.expenseMinor,
      symbol: symbol,
    );

    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int daysLeft = (daysInMonth - now.day + 1).clamp(1, 31);
    final int carried = state.carryIntoMonth(now);
    // What is left to spend is money on hand, udhar included: money lent out is
    // not available to a canteen, and money borrowed is.
    final int available = state.moneyOnHand;

    // Nothing has come in this month and nothing rolled over: there is no
    // "left" to divide. Saying "nothing left of this month's income" on the 1st
    // before the allowance is logged is simply wrong, so the line stays about
    // the week alone.
    final bool noMoneyKnown = state.month.incomeMinor == 0 && carried <= 0;

    final String line;
    if (noMoneyKnown) {
      line = '$spentWeek this week';
    } else if (available <= 0) {
      line = '$spentWeek this week · nothing left for this month';
    } else {
      final String perDay = formatMoney(available ~/ daysLeft, symbol: symbol);
      final String tail = daysLeft == 1
          ? '$perDay left for today'
          : '$perDay a day left';
      final String carriedNote = carried > 0
          ? ' · ${formatMoney(carried, symbol: symbol)} carried over'
          : '';
      line = '$spentWeek this week · $tail$carriedNote';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: <Widget>[
          Icon(
            available > 0 || noMoneyKnown
                ? Icons.trending_flat_rounded
                : Icons.info_outline_rounded,
            size: 15,
            color: AppColors.muted(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.muted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UdharRow extends StatelessWidget {
  const _UdharRow({
    required this.lentMinor,
    required this.borrowedMinor,
    required this.symbol,
    required this.onTap,
  });

  final int lentMinor;
  final int borrowedMinor;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'To receive ${formatMoney(lentMinor, symbol: symbol)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.income(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To pay ${formatMoney(borrowedMinor, symbol: symbol)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentBlock extends StatelessWidget {
  const _RecentBlock({
    required this.entries,
    required this.symbol,
    required this.onOpenHistory,
  });

  final List<TransactionEntry> entries;
  final String symbol;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppState.instance;

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nothing recorded yet',
        message: 'Your first entry takes about five seconds.',
        actionLabel: 'Add an entry',
        onAction: () =>
            Navigator.of(context)
                .push(slideFadeRoute<void>(const AddEntryScreen())),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          EntryRow(
            entry: entries[i],
            category: state.categoryById(entries[i].categoryId),
            symbol: symbol,
            onTap: onOpenHistory,
          ),
          if (i != entries.length - 1) const Hairline(indent: 76),
        ],
      ],
    );
  }
}
